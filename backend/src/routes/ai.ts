import { Hono } from "hono";
import { z } from "zod/v4";
import { searchSimilar } from "../services/qdrant";
import { askWithRAG, prioritizeTasks } from "../services/ai";

const app = new Hono();

const searchSchema = z.object({
  query: z.string().min(1),
  limit: z.number().optional(),
  type: z.enum(["task", "recording", "meeting"]).optional(),
});

const askSchema = z.object({
  query: z.string().min(1),
});

const prioritizeSchema = z.object({
  currentLocation: z
    .object({
      latitude: z.number(),
      longitude: z.number(),
    })
    .optional(),
});

// POST /ai/search - Search knowledge base
app.post("/search", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = searchSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const { query, limit, type } = parsed.data;

  const filter = type ? { type } : undefined;
  const results = await searchSimilar(orgId, query, limit || 10, filter);

  return c.json({ results });
});

// POST /ai/ask - Ask AI with RAG context
app.post("/ask", async (c) => {
  const orgId = c.req.query("orgId");
  if (!orgId) {
    return c.json({ error: "orgId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = askSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const { query } = parsed.data;

  const response = await askWithRAG(orgId, query);

  return c.json(response);
});

// POST /ai/prioritize - Get AI task prioritization
app.post("/prioritize", async (c) => {
  const userId = c.req.query("userId");
  const orgId = c.req.query("orgId");

  if (!userId || !orgId) {
    return c.json({ error: "userId and orgId required" }, 400);
  }

  const body = await c.req.json().catch(() => ({}));
  const parsed = prioritizeSchema.safeParse(body);

  const currentLocation = parsed.success
    ? parsed.data.currentLocation
    : undefined;

  const prioritizedTasks = await prioritizeTasks(
    userId,
    orgId,
    currentLocation
  );

  return c.json({ tasks: prioritizedTasks });
});

export { app as aiRoute };
