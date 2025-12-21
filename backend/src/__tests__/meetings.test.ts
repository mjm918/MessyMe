import { describe, test, expect, beforeAll } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

let testUserId: string;
let testOrgId: string;

beforeAll(async () => {
  const userRes = await request(app, "POST", "/users", {
    email: "meetingtest@example.com",
  });
  const user = await userRes.json();
  testUserId = user.id;

  const orgRes = await request(app, "POST", "/orgs", {
    name: "Meeting Test Org",
    adminEmail: "meetingtest@example.com",
  });
  const org = await orgRes.json();
  testOrgId = org.id;
});

describe("Meetings API", () => {
  test("POST /meetings creates meeting", async () => {
    const res = await request(app, "POST", `/meetings?orgId=${testOrgId}`, {
      userId: testUserId,
      title: "Team Standup",
      notes: "Discussed project progress",
      meetingDate: "2024-12-20T10:00:00Z",
      participants: ["john@test.com", "jane@test.com"],
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.title).toBe("Team Standup");
    expect(body.participants).toContain("john@test.com");
  });

  test("GET /meetings lists meetings for org", async () => {
    const res = await request(app, "GET", `/meetings?orgId=${testOrgId}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  test("GET /meetings/:id returns meeting", async () => {
    const createRes = await request(app, "POST", `/meetings?orgId=${testOrgId}`, {
      userId: testUserId,
      title: "Get Test Meeting",
    });
    const meeting = await createRes.json();

    const res = await request(app, "GET", `/meetings/${meeting.id}`);

    expect(res.status).toBe(200);
    expect((await res.json()).title).toBe("Get Test Meeting");
  });

  test("PUT /meetings/:id updates meeting", async () => {
    const createRes = await request(app, "POST", `/meetings?orgId=${testOrgId}`, {
      userId: testUserId,
      title: "Original Meeting",
    });
    const meeting = await createRes.json();

    const res = await request(app, "PUT", `/meetings/${meeting.id}`, {
      title: "Updated Meeting",
      notes: "Added notes",
    });

    expect(res.status).toBe(200);
    expect((await res.json()).title).toBe("Updated Meeting");
  });

  test("DELETE /meetings/:id deletes meeting", async () => {
    const createRes = await request(app, "POST", `/meetings?orgId=${testOrgId}`, {
      userId: testUserId,
      title: "Delete Me",
    });
    const meeting = await createRes.json();

    const res = await request(app, "DELETE", `/meetings/${meeting.id}`);

    expect(res.status).toBe(200);

    const getRes = await request(app, "GET", `/meetings/${meeting.id}`);
    expect(getRes.status).toBe(404);
  });
});
