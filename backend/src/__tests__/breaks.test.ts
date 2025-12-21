import { describe, test, expect, beforeAll } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

let testUserId: string;

beforeAll(async () => {
  const userRes = await request(app, "POST", "/users", {
    email: "breaktest@example.com",
  });
  const user = await userRes.json();
  testUserId = user.id;
});

describe("Breaks API", () => {
  test("POST /breaks creates prayer break", async () => {
    const res = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "prayer",
      name: "Fajr",
      scheduledTime: "05:30",
      isRecurring: true,
      recurrencePattern: "daily",
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.type).toBe("prayer");
    expect(body.name).toBe("Fajr");
    expect(body.isRecurring).toBe(true);
  });

  test("POST /breaks creates meal break", async () => {
    const res = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "meal",
      name: "Lunch",
      scheduledTime: "12:00",
      recurrencePattern: "weekdays",
    });

    expect(res.status).toBe(201);
    expect((await res.json()).type).toBe("meal");
  });

  test("POST /breaks creates rest break", async () => {
    const res = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "rest",
      name: "Afternoon Break",
      scheduledTime: "15:00",
    });

    expect(res.status).toBe(201);
    expect((await res.json()).type).toBe("rest");
  });

  test("GET /breaks lists user breaks", async () => {
    const res = await request(app, "GET", `/breaks?userId=${testUserId}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBeGreaterThan(0);
  });

  test("PUT /breaks/:id updates break", async () => {
    const createRes = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "rest",
      name: "Original Break",
    });
    const breakSchedule = await createRes.json();

    const res = await request(app, "PUT", `/breaks/${breakSchedule.id}`, {
      name: "Updated Break",
      scheduledTime: "16:00",
    });

    expect(res.status).toBe(200);
    expect((await res.json()).name).toBe("Updated Break");
  });

  test("DELETE /breaks/:id deletes break", async () => {
    const createRes = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "rest",
      name: "Delete Me",
    });
    const breakSchedule = await createRes.json();

    const res = await request(app, "DELETE", `/breaks/${breakSchedule.id}`);

    expect(res.status).toBe(200);

    const getRes = await request(app, "GET", `/breaks/${breakSchedule.id}`);
    expect(getRes.status).toBe(404);
  });

  test("POST /breaks/log logs a break taken", async () => {
    const createRes = await request(app, "POST", `/breaks?userId=${testUserId}`, {
      type: "prayer",
      name: "Dhuhr",
    });
    const breakSchedule = await createRes.json();

    const res = await request(app, "POST", `/breaks/log?userId=${testUserId}`, {
      breakId: breakSchedule.id,
      startedAt: new Date().toISOString(),
      endedAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
      durationMinutes: 15,
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.breakId).toBe(breakSchedule.id);
    expect(body.durationMinutes).toBe(15);
  });

  test("GET /breaks/history/list returns break history", async () => {
    const res = await request(
      app,
      "GET",
      `/breaks/history/list?userId=${testUserId}`
    );

    expect(res.status).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });
});
