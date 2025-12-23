import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";

const elevenlabs = new ElevenLabsClient({
  apiKey: process.env.ELEVENLABS_KEY,
});

// ElevenLabs Scribe model for speech-to-text
const SCRIBE_MODEL_ID = "scribe_v1";

export interface TranscriptionResult {
  text: string;
  languageCode?: string;
  words?: Array<{
    text: string;
    start: number;
    end: number;
    speaker?: string;
  }>;
}

/**
 * Transcribe audio using ElevenLabs Speech-to-Text (Scribe)
 * Supports multiple languages and auto-detection
 * 
 * @param audioBuffer - Audio file as Buffer
 * @param filename - Original filename (for extension detection)
 * @param numSpeakers - Optional number of speakers for diarization
 * @returns Transcription result with text and optional word timestamps
 */
export async function transcribeAudio(
  audioBuffer: Buffer,
  filename: string,
  numSpeakers?: number
): Promise<TranscriptionResult> {
  try {
    // Create a Blob from the buffer for the API
    const uint8Array = new Uint8Array(audioBuffer);
    const blob = new Blob([uint8Array], { type: getMimeType(filename) });

    const transcription = await elevenlabs.speechToText.convert({
      file: blob,
      modelId: SCRIBE_MODEL_ID,
      tagAudioEvents: true,
      timestampsGranularity: "word",
      numSpeakers: numSpeakers,
    });

    // Handle both single and multi-channel responses
    if ("text" in transcription) {
      return {
        text: transcription.text,
        languageCode: transcription.languageCode,
        words: transcription.words?.map((w) => ({
          text: w.text,
          start: w.start ?? 0,
          end: w.end ?? 0,
          speaker: w.speakerId,
        })),
      };
    } else if ("transcripts" in transcription && transcription.transcripts) {
      // Multi-channel - combine all transcripts
      const allText = transcription.transcripts.map((t) => t.text).join("\n");
      return {
        text: allText,
        languageCode: transcription.transcripts[0]?.languageCode,
      };
    }

    return { text: "" };
  } catch (error) {
    console.error("ElevenLabs transcription error:", error);
    throw error;
  }
}

/**
 * Transcribe audio from a URL (e.g., S3 presigned URL)
 * Downloads the file first, then transcribes
 */
export async function transcribeFromUrl(
  audioUrl: string,
  numSpeakers?: number
): Promise<TranscriptionResult> {
  try {
    // Download the audio file
    const response = await fetch(audioUrl);
    if (!response.ok) {
      throw new Error(`Failed to download audio: ${response.statusText}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    // Extract filename from URL
    const urlPath = new URL(audioUrl).pathname;
    const filename = urlPath.split("/").pop() || "audio.m4a";

    return await transcribeAudio(buffer, filename, numSpeakers);
  } catch (error) {
    console.error("Transcription from URL error:", error);
    throw error;
  }
}

function getMimeType(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase();
  switch (ext) {
    case "mp3":
      return "audio/mpeg";
    case "m4a":
      return "audio/mp4";
    case "wav":
      return "audio/wav";
    case "webm":
      return "audio/webm";
    case "ogg":
      return "audio/ogg";
    default:
      return "audio/mpeg";
  }
}
