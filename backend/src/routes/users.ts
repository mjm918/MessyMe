import { Hono } from "hono";
import { z } from "zod/v4";
import { eq } from "drizzle-orm";
import { db, schema } from "../db";

const app = new Hono();

const createUserSchema = z.object({
  email: z.email(),
  name: z.string().optional(),
});

// POST /users - Create or get user (JIT)
app.post("/", async (c) => {
  const body = await c.req.json();
  const parsed = createUserSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const { email, name } = parsed.data;

  // Check if user exists
  const existing = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, email))
    .limit(1);

  if (existing.length > 0) {
    return c.json(existing[0]);
  }

  // Create new user
  const [user] = await db
    .insert(schema.users)
    .values({ email, name })
    .returning();

  return c.json(user, 201);
});

// GET /users/:id - Get user by ID
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [user] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.id, id))
    .limit(1);

  if (!user) {
    return c.json({ error: "User not found" }, 404);
  }

  return c.json(user);
});

// GET /users/:id/orgs - Get user's organizations
app.get("/:id/orgs", async (c) => {
  const userId = c.req.param("id");

  const memberships = await db
    .select({
      org: schema.organizations,
      joinedAt: schema.orgMembers.joinedAt,
    })
    .from(schema.orgMembers)
    .innerJoin(
      schema.organizations,
      eq(schema.orgMembers.orgId, schema.organizations.id)
    )
    .where(eq(schema.orgMembers.userId, userId));

  return c.json(memberships);
});

export { app as usersRoute };
