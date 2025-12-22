import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";
import { embedAndStore, deleteEmbedding } from "../services/qdrant";
import { uploadToS3, deleteFromS3, getS3KeyFromUrl, getPresignedUrl } from "../services/s3";

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

// POST /recordings/upload - Upload audio file to S3
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

  // Upload to S3
  const buffer = await file.arrayBuffer();
  const audioUrl = await uploadToS3(s3Key, Buffer.from(buffer), contentType);

  return c.json({ audioUrl, filename }, 201);
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

export { app as recordingsRoute };
