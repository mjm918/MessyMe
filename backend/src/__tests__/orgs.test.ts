import { describe, test, expect } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

describe("Organizations API", () => {
  test("POST /orgs creates organization with unique invite code", async () => {
    const res = await request(app, "POST", "/orgs", {
      name: "Test Org",
      adminEmail: "admin@testorg.com",
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.name).toBe("Test Org");
    expect(body.inviteCode).toBeDefined();
    expect(body.inviteCode.length).toBe(6);
    expect(body.adminUserId).toBeDefined();
  });

  test("POST /orgs rejects missing name", async () => {
    const res = await request(app, "POST", "/orgs", {
      adminEmail: "admin@test.com",
    });

    expect(res.status).toBe(400);
  });

  test("GET /orgs/:id returns organization with members", async () => {
    // Create org first
    const createRes = await request(app, "POST", "/orgs", {
      name: "Get Test Org",
      adminEmail: "getorg@test.com",
    });
    const created = await createRes.json();

    // Get org
    const res = await request(app, "GET", `/orgs/${created.id}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.id).toBe(created.id);
    expect(body.name).toBe("Get Test Org");
    expect(body.members).toBeDefined();
    expect(body.members.length).toBeGreaterThanOrEqual(1); // At least admin
  });

  test("POST /orgs/join allows user to join with valid invite code", async () => {
    // Create org
    const createRes = await request(app, "POST", "/orgs", {
      name: "Join Test Org",
      adminEmail: "joinadmin@test.com",
    });
    const org = await createRes.json();

    // Join org
    const res = await request(app, "POST", "/orgs/join", {
      inviteCode: org.inviteCode,
      email: "joiner@test.com",
    });

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.message).toBe("Joined organization");
    expect(body.org.id).toBe(org.id);
  });

  test("POST /orgs/join rejects invalid invite code", async () => {
    const res = await request(app, "POST", "/orgs/join", {
      inviteCode: "XXXXXX",
      email: "nobody@test.com",
    });

    expect(res.status).toBe(404);
  });

  test("POST /orgs/join rejects if already a member", async () => {
    // Create org
    const createRes = await request(app, "POST", "/orgs", {
      name: "Double Join Org",
      adminEmail: "doublejoin@test.com",
    });
    const org = await createRes.json();

    // Try to join as admin (already a member)
    const res = await request(app, "POST", "/orgs/join", {
      inviteCode: org.inviteCode,
      email: "doublejoin@test.com",
    });

    expect(res.status).toBe(400);
  });

  test("DELETE /orgs/:id/members/:userId kicks member (admin only)", async () => {
    // Create org
    const createRes = await request(app, "POST", "/orgs", {
      name: "Kick Test Org",
      adminEmail: "kickadmin@test.com",
    });
    const org = await createRes.json();

    // Add a member
    await request(app, "POST", "/orgs/join", {
      inviteCode: org.inviteCode,
      email: "tokick@test.com",
    });

    // Get member's user id
    const orgRes = await request(app, "GET", `/orgs/${org.id}`);
    const orgData = await orgRes.json();
    const memberToKick = orgData.members.find(
      (m: any) => m.user.email === "tokick@test.com"
    );

    // Kick member
    const res = await request(
      app,
      "DELETE",
      `/orgs/${org.id}/members/${memberToKick.user.id}`,
      undefined,
      { "X-User-Email": "kickadmin@test.com" }
    );

    expect(res.status).toBe(200);
  });

  test("DELETE /orgs/:id/members/:userId rejects non-admin", async () => {
    // Create org
    const createRes = await request(app, "POST", "/orgs", {
      name: "Non Admin Kick Org",
      adminEmail: "realadmin@test.com",
    });
    const org = await createRes.json();

    // Add a member
    await request(app, "POST", "/orgs/join", {
      inviteCode: org.inviteCode,
      email: "notadmin@test.com",
    });

    // Get admin's user id
    const orgRes = await request(app, "GET", `/orgs/${org.id}`);
    const orgData = await orgRes.json();

    // Non-admin tries to kick
    const res = await request(
      app,
      "DELETE",
      `/orgs/${org.id}/members/${orgData.adminUserId}`,
      undefined,
      { "X-User-Email": "notadmin@test.com" }
    );

    expect(res.status).toBe(403);
  });

  test("DELETE /orgs/:id deletes organization (admin only)", async () => {
    // Create org
    const createRes = await request(app, "POST", "/orgs", {
      name: "Delete Test Org",
      adminEmail: "deleteadmin@test.com",
    });
    const org = await createRes.json();

    // Delete org
    const res = await request(app, "DELETE", `/orgs/${org.id}`, undefined, {
      "X-User-Email": "deleteadmin@test.com",
    });

    expect(res.status).toBe(200);

    // Verify deleted
    const getRes = await request(app, "GET", `/orgs/${org.id}`);
    expect(getRes.status).toBe(404);
  });
});
