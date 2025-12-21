import { Hono } from "hono";
import { z } from "zod/v4";
import { eq, and, isNull, lte, gte, sql } from "drizzle-orm";
import { db, schema } from "../db";
import { embedAndStore, deleteEmbedding } from "../services/qdrant";

const app = new Hono();

const createTaskSchema = z.object({
  userId: z.uuid(),
  orgId: z.uuid(),
  title: z.string().min(1),
  notes: z.string().optional(),
  priority: z.enum(["none", "low", "medium", "high", "urgent"]).optional(),
  dueDate: z.string().optional(),
  dueTime: z.string().optional(),
  tags: z.array(z.string()).optional(),
  locationContext: z.enum(["none", "home", "work"]).optional(),
});

const updateTaskSchema = createTaskSchema.partial().omit({
  userId: true,
  orgId: true,
});

// GET /tasks - List user's tasks
app.get("/", async (c) => {
  const userId = c.req.query("userId");
  const orgId = c.req.query("orgId");
  const filter = c.req.query("filter"); // today, upcoming, overdue, all
  const completed = c.req.query("completed");

  if (!userId || !orgId) {
    return c.json({ error: "userId and orgId required" }, 400);
  }

  let query = db
    .select()
    .from(schema.tasks)
    .where(
      and(
        eq(schema.tasks.userId, userId),
        eq(schema.tasks.orgId, orgId)
      )
    );

  const tasks = await query;

  // Filter in-memory for flexibility
  let filtered = tasks;

  if (completed === "true") {
    filtered = filtered.filter((t) => t.isCompleted);
  } else if (completed === "false") {
    filtered = filtered.filter((t) => !t.isCompleted);
  }

  const today = new Date().toISOString().split("T")[0];

  if (filter === "today") {
    filtered = filtered.filter((t) => t.dueDate === today);
  } else if (filter === "upcoming") {
    filtered = filtered.filter((t) => t.dueDate && t.dueDate > today);
  } else if (filter === "overdue") {
    filtered = filtered.filter(
      (t) => t.dueDate && t.dueDate < today && !t.isCompleted
    );
  }

  return c.json(filtered);
});

// POST /tasks - Create task
app.post("/", async (c) => {
  const body = await c.req.json();
  const parsed = createTaskSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [task] = await db
    .insert(schema.tasks)
    .values(parsed.data)
    .returning();

  // Embed task for RAG (non-blocking)
  const textToEmbed = `${task.title} ${task.notes || ""}`.trim();
  embedAndStore(task.orgId, {
    id: task.id,
    type: "task",
    content: textToEmbed,
    metadata: {
      userId: task.userId,
      title: task.title,
      priority: task.priority,
      dueDate: task.dueDate,
      tags: task.tags,
    },
  }).catch((err) => console.error("Failed to embed task:", err.message));

  return c.json(task, 201);
});

// GET /tasks/:id - Get task
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [task] = await db
    .select()
    .from(schema.tasks)
    .where(eq(schema.tasks.id, id))
    .limit(1);

  if (!task) {
    return c.json({ error: "Task not found" }, 404);
  }

  return c.json(task);
});

// PUT /tasks/:id - Update task
app.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json();
  const parsed = updateTaskSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [existing] = await db
    .select()
    .from(schema.tasks)
    .where(eq(schema.tasks.id, id))
    .limit(1);

  if (!existing) {
    return c.json({ error: "Task not found" }, 404);
  }

  const [task] = await db
    .update(schema.tasks)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(eq(schema.tasks.id, id))
    .returning();

  // Re-embed task (non-blocking)
  const textToEmbed = `${task.title} ${task.notes || ""}`.trim();
  embedAndStore(task.orgId, {
    id: task.id,
    type: "task",
    content: textToEmbed,
    metadata: {
      userId: task.userId,
      title: task.title,
      priority: task.priority,
      dueDate: task.dueDate,
      tags: task.tags,
    },
  }).catch((err) => console.error("Failed to re-embed task:", err.message));

  return c.json(task);
});

// DELETE /tasks/:id - Delete task
app.delete("/:id", async (c) => {
  const id = c.req.param("id");

  const [task] = await db
    .select()
    .from(schema.tasks)
    .where(eq(schema.tasks.id, id))
    .limit(1);

  if (!task) {
    return c.json({ error: "Task not found" }, 404);
  }

  await db.delete(schema.tasks).where(eq(schema.tasks.id, id));

  // Delete embedding (non-blocking)
  deleteEmbedding(task.orgId, id).catch((err) =>
    console.error("Failed to delete task embedding:", err.message)
  );

  return c.json({ message: "Task deleted" });
});

// POST /tasks/:id/complete - Mark task complete
app.post("/:id/complete", async (c) => {
  const id = c.req.param("id");

  const [task] = await db
    .update(schema.tasks)
    .set({
      isCompleted: true,
      completedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(eq(schema.tasks.id, id))
    .returning();

  if (!task) {
    return c.json({ error: "Task not found" }, 404);
  }

  return c.json(task);
});

// POST /tasks/:id/uncomplete - Mark task incomplete
app.post("/:id/uncomplete", async (c) => {
  const id = c.req.param("id");

  const [task] = await db
    .update(schema.tasks)
    .set({
      isCompleted: false,
      completedAt: null,
      updatedAt: new Date(),
    })
    .where(eq(schema.tasks.id, id))
    .returning();

  if (!task) {
    return c.json({ error: "Task not found" }, 404);
  }

  return c.json(task);
});

export { app as tasksRoute };
