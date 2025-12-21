import { describe, test, expect, beforeAll } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

let testUserId: string;

beforeAll(async () => {
  const userRes = await request(app, "POST", "/users", {
    email: "locationtest@example.com",
  });
  const user = await userRes.json();
  testUserId = user.id;
});

describe("Locations API", () => {
  test("POST /locations creates home location", async () => {
    const res = await request(app, "POST", `/locations?userId=${testUserId}`, {
      name: "Home",
      type: "home",
      address: "123 Main St",
      latitude: 40.7128,
      longitude: -74.006,
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.name).toBe("Home");
    expect(body.type).toBe("home");
    expect(body.latitude).toBe(40.7128);
  });

  test("POST /locations creates work location", async () => {
    const res = await request(app, "POST", `/locations?userId=${testUserId}`, {
      name: "Office",
      type: "work",
      address: "456 Business Ave",
      latitude: 40.758,
      longitude: -73.9855,
    });

    expect(res.status).toBe(201);
    expect((await res.json()).type).toBe("work");
  });

  test("GET /locations lists user locations", async () => {
    const res = await request(app, "GET", `/locations?userId=${testUserId}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBeGreaterThan(0);
  });

  test("PUT /locations/:id updates location", async () => {
    const createRes = await request(app, "POST", `/locations?userId=${testUserId}`, {
      name: "Gym",
      type: "custom",
    });
    const location = await createRes.json();

    const res = await request(app, "PUT", `/locations/${location.id}`, {
      name: "New Gym",
      address: "789 Fitness Blvd",
    });

    expect(res.status).toBe(200);
    expect((await res.json()).name).toBe("New Gym");
  });

  test("DELETE /locations/:id deletes location", async () => {
    const createRes = await request(app, "POST", `/locations?userId=${testUserId}`, {
      name: "Delete Me",
      type: "custom",
    });
    const location = await createRes.json();

    const res = await request(app, "DELETE", `/locations/${location.id}`);

    expect(res.status).toBe(200);

    const getRes = await request(app, "GET", `/locations/${location.id}`);
    expect(getRes.status).toBe(404);
  });

  test("POST /locations/history logs location", async () => {
    const res = await request(app, "POST", `/locations/history?userId=${testUserId}`, {
      latitude: 40.7128,
      longitude: -74.006,
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.latitude).toBe(40.7128);
  });

  test("GET /locations/history/list returns location history", async () => {
    const res = await request(
      app,
      "GET",
      `/locations/history/list?userId=${testUserId}`
    );

    expect(res.status).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });
});
