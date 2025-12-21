import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";

const app = new Hono();

const createBreakSchema = z.object({
  type: z.enum(["prayer", "meal", "rest"]),
  name: z.string().min(1),
  scheduledTime: z.string().optional(),
  isRecurring: z.boolean().optional(),
  recurrencePattern: z.enum(["daily", "weekdays", "weekends", "custom"]).optional(),
});

const updateBreakSchema = createBreakSchema.partial();

const logBreakSchema = z.object({
  breakId: z.uuid().optional(),
  startedAt: z.string(),
  endedAt: z.string().optional(),
  durationMinutes: z.number().optional(),
});

// GET /breaks - List user's break schedules
app.get("/", async (c) => {
  const userId = c.req.query("userId");

  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const breaks = await db
    .select()
    .from(schema.breaks)
    .where(eq(schema.breaks.userId, userId));

  return c.json(breaks);
});

// POST /breaks - Create break schedule
app.post("/", async (c) => {
  const userId = c.req.query("userId");
  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = createBreakSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [breakSchedule] = await db
    .insert(schema.breaks)
    .values({ ...parsed.data, userId })
    .returning();

  return c.json(breakSchedule, 201);
});

// GET /breaks/:id - Get break schedule
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [breakSchedule] = await db
    .select()
    .from(schema.breaks)
    .where(eq(schema.breaks.id, id))
    .limit(1);

  if (!breakSchedule) {
    return c.json({ error: "Break not found" }, 404);
  }

  return c.json(breakSchedule);
});

// PUT /breaks/:id - Update break schedule
app.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json();
  const parsed = updateBreakSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [breakSchedule] = await db
    .update(schema.breaks)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(eq(schema.breaks.id, id))
    .returning();

  if (!breakSchedule) {
    return c.json({ error: "Break not found" }, 404);
  }

  return c.json(breakSchedule);
});

// DELETE /breaks/:id - Delete break schedule
app.delete("/:id", async (c) => {
  const id = c.req.param("id");

  const [breakSchedule] = await db
    .select()
    .from(schema.breaks)
    .where(eq(schema.breaks.id, id))
    .limit(1);

  if (!breakSchedule) {
    return c.json({ error: "Break not found" }, 404);
  }

  await db.delete(schema.breaks).where(eq(schema.breaks.id, id));

  return c.json({ message: "Break deleted" });
});

// POST /breaks/log - Log a break taken
app.post("/log", async (c) => {
  const userId = c.req.query("userId");
  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = logBreakSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const data = {
    ...parsed.data,
    userId,
    startedAt: new Date(parsed.data.startedAt),
    endedAt: parsed.data.endedAt ? new Date(parsed.data.endedAt) : null,
  };

  const [history] = await db
    .insert(schema.breakHistory)
    .values(data)
    .returning();

  return c.json(history, 201);
});

// GET /breaks/history - Get break history
app.get("/history/list", async (c) => {
  const userId = c.req.query("userId");
  const limit = parseInt(c.req.query("limit") || "100");

  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const history = await db
    .select({
      history: schema.breakHistory,
      break: schema.breaks,
    })
    .from(schema.breakHistory)
    .leftJoin(schema.breaks, eq(schema.breakHistory.breakId, schema.breaks.id))
    .where(eq(schema.breakHistory.userId, userId))
    .orderBy(schema.breakHistory.startedAt)
    .limit(limit);

  return c.json(history);
});

export { app as breaksRoute };
