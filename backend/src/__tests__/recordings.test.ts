import { describe, test, expect, beforeAll } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

let testUserId: string;
let testOrgId: string;

beforeAll(async () => {
  const userRes = await request(app, "POST", "/users", {
    email: "recordingtest@example.com",
  });
  const user = await userRes.json();
  testUserId = user.id;

  const orgRes = await request(app, "POST", "/orgs", {
    name: "Recording Test Org",
    adminEmail: "recordingtest@example.com",
  });
  const org = await orgRes.json();
  testOrgId = org.id;
});

describe("Recordings API", () => {
  test("POST /recordings creates voice memo", async () => {
    const res = await request(app, "POST", `/recordings?orgId=${testOrgId}`, {
      userId: testUserId,
      type: "voice_memo",
      title: "Quick Note",
      transcript: "This is a test transcription",
      durationSeconds: 30,
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.type).toBe("voice_memo");
    expect(body.title).toBe("Quick Note");
    expect(body.transcript).toBe("This is a test transcription");
  });

  test("POST /recordings creates meeting recording", async () => {
    const res = await request(app, "POST", `/recordings?orgId=${testOrgId}`, {
      userId: testUserId,
      type: "meeting",
      title: "Team Standup",
      transcript: "Meeting transcript here",
      durationSeconds: 1800,
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.type).toBe("meeting");
  });

  test("GET /recordings lists recordings for org", async () => {
    const res = await request(app, "GET", `/recordings?orgId=${testOrgId}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  test("GET /recordings/:id returns recording", async () => {
    const createRes = await request(app, "POST", `/recordings?orgId=${testOrgId}`, {
      userId: testUserId,
      type: "voice_memo",
      title: "Get Test",
    });
    const recording = await createRes.json();

    const res = await request(app, "GET", `/recordings/${recording.id}`);

    expect(res.status).toBe(200);
    expect((await res.json()).title).toBe("Get Test");
  });

  test("PUT /recordings/:id updates recording", async () => {
    const createRes = await request(app, "POST", `/recordings?orgId=${testOrgId}`, {
      userId: testUserId,
      type: "voice_memo",
      title: "Original",
    });
    const recording = await createRes.json();

    const res = await request(app, "PUT", `/recordings/${recording.id}`, {
      title: "Updated",
      transcript: "New transcript",
    });

    expect(res.status).toBe(200);
    expect((await res.json()).title).toBe("Updated");
  });

  test("DELETE /recordings/:id deletes recording", async () => {
    const createRes = await request(app, "POST", `/recordings?orgId=${testOrgId}`, {
      userId: testUserId,
      type: "voice_memo",
    });
    const recording = await createRes.json();

    const res = await request(app, "DELETE", `/recordings/${recording.id}`);

    expect(res.status).toBe(200);

    const getRes = await request(app, "GET", `/recordings/${recording.id}`);
    expect(getRes.status).toBe(404);
  });
});
