import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";

const app = new Hono();

const createLocationSchema = z.object({
  name: z.string().min(1),
  type: z.enum(["home", "work", "custom"]).optional(),
  address: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

const updateLocationSchema = createLocationSchema.partial();

const locationHistorySchema = z.object({
  locationId: z.uuid().optional(),
  latitude: z.number(),
  longitude: z.number(),
});

// GET /locations - List user's locations
app.get("/", async (c) => {
  const userId = c.req.query("userId");

  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const locations = await db
    .select()
    .from(schema.locations)
    .where(eq(schema.locations.userId, userId));

  return c.json(locations);
});

// POST /locations - Create location
app.post("/", async (c) => {
  const userId = c.req.query("userId");
  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = createLocationSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [location] = await db
    .insert(schema.locations)
    .values({ ...parsed.data, userId })
    .returning();

  return c.json(location, 201);
});

// GET /locations/:id - Get location
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [location] = await db
    .select()
    .from(schema.locations)
    .where(eq(schema.locations.id, id))
    .limit(1);

  if (!location) {
    return c.json({ error: "Location not found" }, 404);
  }

  return c.json(location);
});

// PUT /locations/:id - Update location
app.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json();
  const parsed = updateLocationSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [location] = await db
    .update(schema.locations)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(eq(schema.locations.id, id))
    .returning();

  if (!location) {
    return c.json({ error: "Location not found" }, 404);
  }

  return c.json(location);
});

// DELETE /locations/:id - Delete location
app.delete("/:id", async (c) => {
  const id = c.req.param("id");

  const [location] = await db
    .select()
    .from(schema.locations)
    .where(eq(schema.locations.id, id))
    .limit(1);

  if (!location) {
    return c.json({ error: "Location not found" }, 404);
  }

  await db.delete(schema.locations).where(eq(schema.locations.id, id));

  return c.json({ message: "Location deleted" });
});

// POST /locations/history - Log location history
app.post("/history", async (c) => {
  const userId = c.req.query("userId");
  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const body = await c.req.json();
  const parsed = locationHistorySchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const [history] = await db
    .insert(schema.locationHistory)
    .values({ ...parsed.data, userId })
    .returning();

  return c.json(history, 201);
});

// GET /locations/history - Get location history
app.get("/history/list", async (c) => {
  const userId = c.req.query("userId");
  const limit = parseInt(c.req.query("limit") || "100");

  if (!userId) {
    return c.json({ error: "userId required" }, 400);
  }

  const history = await db
    .select()
    .from(schema.locationHistory)
    .where(eq(schema.locationHistory.userId, userId))
    .orderBy(schema.locationHistory.recordedAt)
    .limit(limit);

  return c.json(history);
});

export { app as locationsRoute };
