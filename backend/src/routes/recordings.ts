import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";
import { embedAndStore, deleteEmbedding } from "../services/qdrant";
import { uploadToS3, deleteFromS3, getS3KeyFromUrl, getPresignedUrl, getPresignedUploadUrl, getS3UrlFromKey } from "../services/s3";
import { transcribeAudio } from "../services/transcription";
import { addTranscriptionJob } from "../worker";

const app = new Hono();

const createRecordingSchema = z.object({
  userId: z.uuid(),
  type: z.enum(["voice_memo", "meeting"]),
  title: z.string().optional(),
  transcript: z.string().optional(),
  audioUrl: z.string().optional(),
  durationSeconds: z.number().optional(),
});

const updateRecordingSchema = createRecordingSchema.partial().omit({
  userId: true,
});

// ============================================
// STATIC ROUTES (must come before /:id routes)
// ============================================

// GET /recordings - List recordings for org
app.get("/", async (c) => {
  const orgId = c.req.query("orgId");

  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const recordings = await db
    .select()
    .from(schema.recordings)
    .where(eq(schema.recordings.orgId, orgId))
    .orderBy(schema.recordings.createdAt);

  return c.json(recordings);
});

// POST /recordings - Create recording
app.post("/", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = createRecordingSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [recording] = await db
    .insert(schema.recordings)
    .values({ ...parsed.data, orgId })
    .returning();

  // Embed transcript for RAG if present (non-blocking)
  if (recording.transcript) {
    embedAndStore(orgId, {
      id: recording.id,
      type: "recording",
      content: recording.transcript,
      metadata: {
        userId: recording.userId,
        title: recording.title,
        recordingType: recording.type,
      },
    }).catch((err) => console.error("Failed to embed recording:", err.message));
  }

  return c.json(recording, 201);
});

// GET /recordings/upload-url - Get presigned URL for direct S3 upload
app.get("/upload-url", async (c) => {
  const orgId = c.req.query("orgId");
  const ext = c.req.query("ext") || "m4a";

  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  // Generate unique filename with org prefix
  const filename = `${crypto.randomUUID()}.${ext}`;
  const s3Key = `recordings/${orgId}/${filename}`;

  // Determine content type
  const contentType =
    ext === "m4a"
      ? "audio/mp4"
      : ext === "mp3"
      ? "audio/mpeg"
      : ext === "wav"
      ? "audio/wav"
      : "audio/mp4";

  // Generate presigned upload URL valid for 1 hour
  const uploadUrl = await getPresignedUploadUrl(s3Key, contentType, 3600);
  const audioUrl = getS3UrlFromKey(s3Key);

  return c.json({ uploadUrl, audioUrl, filename, s3Key });
});

// POST /recordings/upload - Upload audio file to S3 and transcribe (legacy sync flow)
app.post("/upload", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const formData = await c.req.formData();
  const file = formData.get("audio") as File | null;

  if (!file) {
    return c.json({ error: "No audio file provided" }, 400);
  }

  // Generate unique filename with org prefix for organization
  const ext = file.name.split(".").pop() || "m4a";
  const filename = `${crypto.randomUUID()}.${ext}`;
  const s3Key = `recordings/${orgId}/${filename}`;

  // Determine content type
  const contentType =
    ext === "m4a"
      ? "audio/mp4"
      : ext === "mp3"
      ? "audio/mpeg"
      : ext === "wav"
      ? "audio/wav"
      : "audio/mp4";

  // Get buffer for both S3 upload and transcription
  const arrayBuffer = await file.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  // Upload to S3
  const audioUrl = await uploadToS3(s3Key, buffer, contentType);

  // Transcribe using ElevenLabs
  let transcript: string | undefined;
  let languageCode: string | undefined;

  try {
    const transcriptionResult = await transcribeAudio(buffer, filename);
    transcript = transcriptionResult.text;
    languageCode = transcriptionResult.languageCode;
  } catch (err) {
    console.error("Transcription failed:", err);
  }

  return c.json({ audioUrl, filename, transcript, languageCode }, 201);
});

// POST /recordings/create-with-transcription - Create recording and queue transcription job
app.post("/create-with-transcription", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = createRecordingSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  if (!parsed.data.audioUrl) {
    return c.json({ error: "audioUrl is required" }, 400);
  }

  // Create recording with pending transcription status
  const [recording] = await db
    .insert(schema.recordings)
    .values({
      ...parsed.data,
      orgId,
      transcriptionStatus: "pending",
    })
    .returning();

  // Queue transcription job via graphile-worker
  try {
    await addTranscriptionJob(recording.id, parsed.data.audioUrl, orgId);
    console.log(`[Recordings] Queued transcription job for recording ${recording.id}`);
  } catch (err) {
    console.error("Failed to queue transcription job:", err);
    // Update status to failed since we couldn't queue
    await db
      .update(schema.recordings)
      .set({ transcriptionStatus: "failed", transcriptionError: "Failed to queue job" })
      .where(eq(schema.recordings.id, recording.id));
  }

  return c.json(recording, 201);
});

// ============================================
// PARAMETERIZED ROUTES (/:id patterns)
// ============================================

// GET /recordings/:id - Get recording
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [recording] = await db
    .select()
    .from(schema.recordings)
    .where(eq(schema.recordings.id, id))
    .limit(1);

  if (!recording) {
    return c.json({ error: "Recording not found" }, 404);
  }

  return c.json(recording);
});

// PUT /recordings/:id - Update recording
app.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json();
  const parsed = updateRecordingSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [existing] = await db
    .select()
    .from(schema.recordings)
    .where(eq(schema.recordings.id, id))
    .limit(1);

  if (!existing) {
    return c.json({ error: "Recording not found" }, 404);
  }

  const [recording] = await db
    .update(schema.recordings)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(eq(schema.recordings.id, id))
    .returning();

  // Re-embed if transcript updated (non-blocking)
  if (recording.transcript) {
    embedAndStore(recording.orgId, {
      id: recording.id,
      type: "recording",
      content: recording.transcript,
      metadata: {
        userId: recording.userId,
        title: recording.title,
        recordingType: recording.type,
      },
    }).catch((err) => console.error("Failed to re-embed recording:", err.message));
  }

  return c.json(recording);
});

// DELETE /recordings/:id - Delete recording
app.delete("/:id", async (c) => {
  const id = c.req.param("id");

  const [recording] = await db
    .select()
    .from(schema.recordings)
    .where(eq(schema.recordings.id, id))
    .limit(1);

  if (!recording) {
    return c.json({ error: "Recording not found" }, 404);
  }

  // Delete audio file from S3 if exists
  if (recording.audioUrl) {
    const s3Key = getS3KeyFromUrl(recording.audioUrl);
    if (s3Key) {
      deleteFromS3(s3Key).catch((err) =>
        console.error("Failed to delete audio from S3:", err.message)
      );
    }
  }

  await db.delete(schema.recordings).where(eq(schema.recordings.id, id));

  // Delete embedding (non-blocking)
  deleteEmbedding(recording.orgId, id).catch((err) =>
    console.error("Failed to delete recording embedding:", err.message)
  );

  return c.json({ message: "Recording deleted" });
});

// GET /recordings/:id/audio-url - Get presigned URL for audio playback
app.get("/:id/audio-url", async (c) => {
  const id = c.req.param("id");

  const [recording] = await db
    .select()
    .from(schema.recordings)
    .where(eq(schema.recordings.id, id))
    .limit(1);

  if (!recording) {
    return c.json({ error: "Recording not found" }, 404);
  }

  if (!recording.audioUrl) {
    return c.json({ error: "No audio file for this recording" }, 404);
  }

  const s3Key = getS3KeyFromUrl(recording.audioUrl);
  if (!s3Key) {
    return c.json({ error: "Invalid audio URL" }, 500);
  }

  // Generate presigned URL valid for 1 hour
  const presignedUrl = await getPresignedUrl(s3Key, 3600);

  return c.json({ url: presignedUrl });
});

// GET /recordings/:id/transcription-status - Get transcription status
app.get("/:id/transcription-status", async (c) => {
  const id = c.req.param("id");

  const [recording] = await db
    .select({
      id: schema.recordings.id,
      transcriptionStatus: schema.recordings.transcriptionStatus,
      transcriptionError: schema.recordings.transcriptionError,
      transcript: schema.recordings.transcript,
    })
    .from(schema.recordings)
    .where(eq(schema.recordings.id, id))
    .limit(1);

  if (!recording) {
    return c.json({ error: "Recording not found" }, 404);
  }

  return c.json(recording);
});

export { app as recordingsRoute };
