import { Hono } from "hono";
import { usersRoute } from "../routes/users";
import { orgsRoute } from "../routes/orgs";
import { tasksRoute } from "../routes/tasks";
import { recordingsRoute } from "../routes/recordings";
import { meetingsRoute } from "../routes/meetings";
import { locationsRoute } from "../routes/locations";
import { breaksRoute } from "../routes/breaks";
import { aiRoute } from "../routes/ai";

export function createTestApp() {
  const app = new Hono();

  app.get("/health", (c) => c.json({ status: "ok" }));

  app.route("/users", usersRoute);
  app.route("/orgs", orgsRoute);
  app.route("/tasks", tasksRoute);
  app.route("/recordings", recordingsRoute);
  app.route("/meetings", meetingsRoute);
  app.route("/locations", locationsRoute);
  app.route("/breaks", breaksRoute);
  app.route("/ai", aiRoute);

  return app;
}

export async function request(
  app: Hono,
  method: string,
  path: string,
  body?: any,
  headers?: Record<string, string>
) {
  const req = new Request(`http://localhost${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  return app.fetch(req);
}
