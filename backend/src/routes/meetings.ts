import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";
import { embedAndStore, deleteEmbedding } from "../services/qdrant";

const app = new Hono();

const createMeetingSchema = z.object({
  userId: z.uuid(),
  title: z.string().min(1),
  notes: z.string().optional(),
  meetingDate: z.string().optional(),
  participants: z.array(z.string()).optional(),
});

const updateMeetingSchema = createMeetingSchema.partial().omit({
  userId: true,
});

// GET /meetings - List meetings for org
app.get("/", async (c) => {
  const orgId = c.req.query("orgId");

  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const meetings = await db
    .select()
    .from(schema.meetings)
    .where(eq(schema.meetings.orgId, orgId))
    .orderBy(schema.meetings.meetingDate);

  return c.json(meetings);
});

// POST /meetings - Create meeting
app.post("/", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = createMeetingSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const data = {
    ...parsed.data,
    orgId,
    meetingDate: parsed.data.meetingDate
      ? new Date(parsed.data.meetingDate)
      : null,
  };

  const [meeting] = await db
    .insert(schema.meetings)
    .values(data)
    .returning();

  // Embed meeting for RAG (non-blocking)
  const textToEmbed = `${meeting.title} ${meeting.notes || ""}`.trim();
  embedAndStore(orgId, {
    id: meeting.id,
    type: "meeting",
    content: textToEmbed,
    metadata: {
      userId: meeting.userId,
      title: meeting.title,
      meetingDate: meeting.meetingDate?.toISOString(),
      participants: meeting.participants,
    },
  }).catch((err) => console.error("Failed to embed meeting:", err.message));

  return c.json(meeting, 201);
});

// GET /meetings/:id - Get meeting
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [meeting] = await db
    .select()
    .from(schema.meetings)
    .where(eq(schema.meetings.id, id))
    .limit(1);

  if (!meeting) {
    return c.json({ error: "Meeting not found" }, 404);
  }

  return c.json(meeting);
});

// PUT /meetings/:id - Update meeting
app.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json();
  const parsed = updateMeetingSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [existing] = await db
    .select()
    .from(schema.meetings)
    .where(eq(schema.meetings.id, id))
    .limit(1);

  if (!existing) {
    return c.json({ error: "Meeting not found" }, 404);
  }

  const data = {
    ...parsed.data,
    meetingDate: parsed.data.meetingDate
      ? new Date(parsed.data.meetingDate)
      : undefined,
    updatedAt: new Date(),
  };

  const [meeting] = await db
    .update(schema.meetings)
    .set(data)
    .where(eq(schema.meetings.id, id))
    .returning();

  // Re-embed meeting (non-blocking)
  const textToEmbed = `${meeting.title} ${meeting.notes || ""}`.trim();
  embedAndStore(meeting.orgId, {
    id: meeting.id,
    type: "meeting",
    content: textToEmbed,
    metadata: {
      userId: meeting.userId,
      title: meeting.title,
      meetingDate: meeting.meetingDate?.toISOString(),
      participants: meeting.participants,
    },
  }).catch((err) => console.error("Failed to re-embed meeting:", err.message));

  return c.json(meeting);
});

// DELETE /meetings/:id - Delete meeting
app.delete("/:id", async (c) => {
  const id = c.req.param("id");

  const [meeting] = await db
    .select()
    .from(schema.meetings)
    .where(eq(schema.meetings.id, id))
    .limit(1);

  if (!meeting) {
    return c.json({ error: "Meeting not found" }, 404);
  }

  await db.delete(schema.meetings).where(eq(schema.meetings.id, id));

  // Delete embedding (non-blocking)
  deleteEmbedding(meeting.orgId, id).catch((err) =>
    console.error("Failed to delete meeting embedding:", err.message)
  );

  return c.json({ message: "Meeting deleted" });
});

export { app as meetingsRoute };
