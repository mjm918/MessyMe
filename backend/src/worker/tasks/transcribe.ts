import type { Task } from "graphile-worker";
import { eq } from "drizzle-orm";
import { db, schema } from "../../db";
import { transcribeFromUrl } from "../../services/transcription";
import { embedAndStore } from "../../services/qdrant";
import { getS3KeyFromUrl, getPresignedUrl } from "../../services/s3";

interface TranscribePayload {
  recordingId: string;
  audioUrl: string;
  orgId: string;
}

/**
 * Background task to transcribe a recording
 * This runs asynchronously via graphile-worker
 */
export const transcribeRecording: Task = async (payload, helpers) => {
  const { recordingId, audioUrl, orgId } = payload as TranscribePayload;
  const { logger } = helpers;

  logger.info(`Starting transcription for recording ${recordingId}`);

  // Update status to processing
  await db
    .update(schema.recordings)
    .set({
      transcriptionStatus: "processing",
      updatedAt: new Date(),
    })
    .where(eq(schema.recordings.id, recordingId));

  try {
    // Generate presigned URL for private S3 access
    const s3Key = getS3KeyFromUrl(audioUrl);
    if (!s3Key) {
      throw new Error(`Invalid S3 URL: ${audioUrl}`);
    }
    const presignedUrl = await getPresignedUrl(s3Key, 3600);

    // Transcribe the audio using presigned URL
    const result = await transcribeFromUrl(presignedUrl);

    logger.info(`Transcription completed for recording ${recordingId}, length: ${result.text.length}`);

    // Get the recording to get userId for embedding
    const [recording] = await db
      .select()
      .from(schema.recordings)
      .where(eq(schema.recordings.id, recordingId))
      .limit(1);

    if (!recording) {
      throw new Error(`Recording ${recordingId} not found`);
    }

    // Update recording with transcript
    await db
      .update(schema.recordings)
      .set({
        transcript: result.text,
        transcriptionStatus: "completed",
        transcriptionError: null,
        updatedAt: new Date(),
      })
      .where(eq(schema.recordings.id, recordingId));

    // Embed for RAG search
    if (result.text) {
      try {
        await embedAndStore(orgId, {
          id: recordingId,
          type: "recording",
          content: result.text,
          metadata: {
            userId: recording.userId,
            title: recording.title,
            recordingType: recording.type,
          },
        });
        logger.info(`Embedded recording ${recordingId} for RAG`);
      } catch (embedError) {
        logger.error(`Failed to embed recording ${recordingId}:`, { error: embedError instanceof Error ? embedError.message : "Unknown" });
        // Don't fail the job for embedding errors
      }
    }

    logger.info(`Successfully completed transcription for recording ${recordingId}`);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    logger.error(`Transcription failed for recording ${recordingId}: ${errorMessage}`);

    // Update status to failed
    await db
      .update(schema.recordings)
      .set({
        transcriptionStatus: "failed",
        transcriptionError: errorMessage,
        updatedAt: new Date(),
      })
      .where(eq(schema.recordings.id, recordingId));

    // Re-throw to trigger retry
    throw error;
  }
};
