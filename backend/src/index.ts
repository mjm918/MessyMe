import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";

import { usersRoute } from "./routes/users";
import { orgsRoute } from "./routes/orgs";
import { tasksRoute } from "./routes/tasks";
import { recordingsRoute } from "./routes/recordings";
import { meetingsRoute } from "./routes/meetings";
import { locationsRoute } from "./routes/locations";
import { breaksRoute } from "./routes/breaks";
import { aiRoute } from "./routes/ai";
import { startWorker } from "./worker";

const app = new Hono();

app.use("*", logger());
app.use("*", cors());

app.get("/", (c) => c.json({ message: "MessyMe API" }));
app.get("/health", (c) => c.json({ status: "ok" }));

app.route("/users", usersRoute);
app.route("/orgs", orgsRoute);
app.route("/tasks", tasksRoute);
app.route("/recordings", recordingsRoute);
app.route("/meetings", meetingsRoute);
app.route("/locations", locationsRoute);
app.route("/breaks", breaksRoute);
app.route("/ai", aiRoute);

// Start background worker for async jobs
startWorker().catch((err) => {
  console.error("[Worker] Failed to start:", err.message);
});

export default {
  port: process.env.PORT || 3000,
  fetch: app.fetch,
};
