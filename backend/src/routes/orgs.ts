import { Hono } from "hono";
import { z } from "zod/v4";
import { eq, and } from "drizzle-orm";
import { db, schema } from "../db";
import { generateInviteCode } from "../utils/invite-code";
import { createOrgCollection, deleteOrgCollection } from "../services/qdrant";

const app = new Hono();

const createOrgSchema = z.object({
  name: z.string().min(1),
  adminEmail: z.email(),
});

const joinOrgSchema = z.object({
  inviteCode: z.string().length(6),
  email: z.email(),
});

// POST /orgs - Create organization
app.post("/", async (c) => {
  const body = await c.req.json();
  const parsed = createOrgSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const { name, adminEmail } = parsed.data;

  // Get or create admin user
  let [admin] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, adminEmail))
    .limit(1);

  if (!admin) {
    [admin] = await db
      .insert(schema.users)
      .values({ email: adminEmail })
      .returning();
  }

  // Generate unique invite code
  let inviteCode = generateInviteCode();
  let attempts = 0;
  while (attempts < 10) {
    const existing = await db
      .select()
      .from(schema.organizations)
      .where(eq(schema.organizations.inviteCode, inviteCode))
      .limit(1);

    if (existing.length === 0) break;
    inviteCode = generateInviteCode();
    attempts++;
  }

  // Create organization
  const [org] = await db
    .insert(schema.organizations)
    .values({
      name,
      inviteCode,
      adminUserId: admin.id,
    })
    .returning();

  // Add admin as member
  await db.insert(schema.orgMembers).values({
    orgId: org.id,
    userId: admin.id,
  });

  // Create Qdrant collection for org (non-blocking, will retry later if needed)
  createOrgCollection(org.id).catch((err) => {
    console.error("Failed to create Qdrant collection:", err.message);
  });

  return c.json(org, 201);
});

// GET /orgs/:id - Get organization
app.get("/:id", async (c) => {
  const id = c.req.param("id");

  const [org] = await db
    .select()
    .from(schema.organizations)
    .where(eq(schema.organizations.id, id))
    .limit(1);

  if (!org) {
    return c.json({ error: "Organization not found" }, 404);
  }

  // Get members
  const members = await db
    .select({
      user: schema.users,
      joinedAt: schema.orgMembers.joinedAt,
    })
    .from(schema.orgMembers)
    .innerJoin(schema.users, eq(schema.orgMembers.userId, schema.users.id))
    .where(eq(schema.orgMembers.orgId, id));

  return c.json({ ...org, members });
});

// POST /orgs/join - Join organization
app.post("/join", async (c) => {
  const body = await c.req.json();
  const parsed = joinOrgSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: parsed.error.flatten() }, 400);
  }

  const { inviteCode, email } = parsed.data;

  // Find organization by invite code
  const [org] = await db
    .select()
    .from(schema.organizations)
    .where(eq(schema.organizations.inviteCode, inviteCode.toUpperCase()))
    .limit(1);

  if (!org) {
    return c.json({ error: "Invalid invite code" }, 404);
  }

  // Get or create user
  let [user] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, email))
    .limit(1);

  if (!user) {
    [user] = await db
      .insert(schema.users)
      .values({ email })
      .returning();
  }

  // Check if already a member
  const existing = await db
    .select()
    .from(schema.orgMembers)
    .where(
      and(
        eq(schema.orgMembers.orgId, org.id),
        eq(schema.orgMembers.userId, user.id)
      )
    )
    .limit(1);

  if (existing.length > 0) {
    return c.json({ error: "Already a member" }, 400);
  }

  // Add as member
  await db.insert(schema.orgMembers).values({
    orgId: org.id,
    userId: user.id,
  });

  return c.json({ message: "Joined organization", org });
});

// DELETE /orgs/:id - Delete organization (admin only)
app.delete("/:id", async (c) => {
  const id = c.req.param("id");
  const adminEmail = c.req.header("X-User-Email");

  if (!adminEmail) {
    return c.json({ error: "X-User-Email header required" }, 401);
  }

  const [org] = await db
    .select()
    .from(schema.organizations)
    .where(eq(schema.organizations.id, id))
    .limit(1);

  if (!org) {
    return c.json({ error: "Organization not found" }, 404);
  }

  // Verify admin
  const [admin] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, adminEmail))
    .limit(1);

  if (!admin || org.adminUserId !== admin.id) {
    return c.json({ error: "Only admin can delete organization" }, 403);
  }

  // Delete Qdrant collection (non-blocking)
  deleteOrgCollection(org.id).catch((err) => {
    console.error("Failed to delete Qdrant collection:", err.message);
  });

  // Delete organization (cascades to members)
  await db
    .delete(schema.organizations)
    .where(eq(schema.organizations.id, id));

  return c.json({ message: "Organization deleted" });
});

// DELETE /orgs/:id/members/:userId - Kick member (admin only)
app.delete("/:id/members/:userId", async (c) => {
  const orgId = c.req.param("id");
  const userId = c.req.param("userId");
  const adminEmail = c.req.header("X-User-Email");

  if (!adminEmail) {
    return c.json({ error: "X-User-Email header required" }, 401);
  }

  const [org] = await db
    .select()
    .from(schema.organizations)
    .where(eq(schema.organizations.id, orgId))
    .limit(1);

  if (!org) {
    return c.json({ error: "Organization not found" }, 404);
  }

  // Verify admin
  const [admin] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.email, adminEmail))
    .limit(1);

  if (!admin || org.adminUserId !== admin.id) {
    return c.json({ error: "Only admin can kick members" }, 403);
  }

  // Cannot kick admin
  if (userId === org.adminUserId) {
    return c.json({ error: "Cannot kick admin" }, 400);
  }

  await db
    .delete(schema.orgMembers)
    .where(
      and(
        eq(schema.orgMembers.orgId, orgId),
        eq(schema.orgMembers.userId, userId)
      )
    );

  return c.json({ message: "Member removed" });
});

export { app as orgsRoute };
