import { describe, test, expect } from "bun:test";
import { createTestApp, request } from "./setup";

const app = createTestApp();

function uniqueEmail(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`;
}

describe("Users API", () => {
  test("POST /users creates a new user with valid email", async () => {
    const email = uniqueEmail("newuser");
    const res = await request(app, "POST", "/users", {
      email,
      name: "Test User",
    });

    expect(res.status).toBe(201);

    const body = await res.json();
    expect(body.email).toBe(email);
    expect(body.name).toBe("Test User");
    expect(body.id).toBeDefined();
  });

  test("POST /users returns existing user if email exists", async () => {
    const email = uniqueEmail("existing");

    // First create
    const first = await request(app, "POST", "/users", {
      email,
      name: "First",
    });
    expect(first.status).toBe(201);

    // Second request with same email
    const res = await request(app, "POST", "/users", {
      email,
      name: "Second",
    });

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.email).toBe(email);
    expect(body.name).toBe("First"); // Should keep original name
  });

  test("POST /users rejects invalid email", async () => {
    const res = await request(app, "POST", "/users", {
      email: "not-an-email",
      name: "Test",
    });

    expect(res.status).toBe(400);
  });

  test("GET /users/:id returns user by id", async () => {
    const email = uniqueEmail("getuser");

    // Create user first
    const createRes = await request(app, "POST", "/users", {
      email,
      name: "Get User",
    });
    const created = await createRes.json();

    // Get by id
    const res = await request(app, "GET", `/users/${created.id}`);

    expect(res.status).toBe(200);

    const body = await res.json();
    expect(body.id).toBe(created.id);
    expect(body.email).toBe(email);
  });

  test("GET /users/:id returns 404 for non-existent user", async () => {
    const res = await request(app, "GET", "/users/00000000-0000-0000-0000-000000000000");

    expect(res.status).toBe(404);
  });
});
