import { describe, test, expect, beforeAll } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

let testUserId: string;
let testOrgId: string;

beforeAll(async () => {
  // Create test user
  const userRes = await request(app, "POST", "/users", {
    email: "tasktest@example.com",
    name: "Task Tester",
  });
  const user = await userRes.json();
  testUserId = user.id;

  // Create test org
  const orgRes = await request(app, "POST", "/orgs", {
    name: "Task Test Org",
    adminEmail: "tasktest@example.com",
  });
  const org = await orgRes.json();
  testOrgId = org.id;
});

describe("Tasks API", () => {
  test("POST /tasks creates a task with required fields", async () => {
    const res = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Test Task",
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.title).toBe("Test Task");
    expect(body.userId).toBe(testUserId);
    expect(body.orgId).toBe(testOrgId);
    expect(body.isCompleted).toBe(false);
  });

  test("POST /tasks creates a task with all fields", async () => {
    const res = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Full Task",
      notes: "Some notes",
      priority: "high",
      dueDate: "2024-12-31",
      dueTime: "14:00",
      tags: ["work", "urgent"],
      locationContext: "work",
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.title).toBe("Full Task");
    expect(body.notes).toBe("Some notes");
    expect(body.priority).toBe("high");
    expect(body.dueDate).toBe("2024-12-31");
    expect(body.tags).toContain("work");
    expect(body.locationContext).toBe("work");
  });

  test("POST /tasks rejects missing title", async () => {
    const res = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
    });

    expect(res.status).toBe(400);
  });

  test("GET /tasks returns user tasks for org", async () => {
    const res = await request(
      app,
      "GET",
      `/tasks?userId=${testUserId}&orgId=${testOrgId}`
    );

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBeGreaterThan(0);
  });

  test("GET /tasks/:id returns task by id", async () => {
    // Create task
    const createRes = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Get Test Task",
    });
    const task = await createRes.json();

    // Get task
    const res = await request(app, "GET", `/tasks/${task.id}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.id).toBe(task.id);
    expect(body.title).toBe("Get Test Task");
  });

  test("PUT /tasks/:id updates task", async () => {
    // Create task
    const createRes = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Original Title",
    });
    const task = await createRes.json();

    // Update task
    const res = await request(app, "PUT", `/tasks/${task.id}`, {
      title: "Updated Title",
      priority: "urgent",
    });

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.title).toBe("Updated Title");
    expect(body.priority).toBe("urgent");
  });

  test("POST /tasks/:id/complete marks task complete", async () => {
    // Create task
    const createRes = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Complete Me",
    });
    const task = await createRes.json();

    // Complete task
    const res = await request(app, "POST", `/tasks/${task.id}/complete`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.isCompleted).toBe(true);
    expect(body.completedAt).toBeDefined();
  });

  test("POST /tasks/:id/uncomplete marks task incomplete", async () => {
    // Create and complete task
    const createRes = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Uncomplete Me",
    });
    const task = await createRes.json();
    await request(app, "POST", `/tasks/${task.id}/complete`);

    // Uncomplete task
    const res = await request(app, "POST", `/tasks/${task.id}/uncomplete`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.isCompleted).toBe(false);
    expect(body.completedAt).toBeNull();
  });

  test("DELETE /tasks/:id deletes task", async () => {
    // Create task
    const createRes = await request(app, "POST", "/tasks", {
      userId: testUserId,
      orgId: testOrgId,
      title: "Delete Me",
    });
    const task = await createRes.json();

    // Delete task
    const res = await request(app, "DELETE", `/tasks/${task.id}`);

    expect(res.status).toBe(200);

    // Verify deleted
    const getRes = await request(app, "GET", `/tasks/${task.id}`);
    expect(getRes.status).toBe(404);
  });

  test("GET /tasks filters by completed=false", async () => {
    const res = await request(
      app,
      "GET",
      `/tasks?userId=${testUserId}&orgId=${testOrgId}&completed=false`
    );

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
    body.forEach((task: any) => {
      expect(task.isCompleted).toBe(false);
    });
  });
});
