import {
  pgTable,
  uuid,
  varchar,
  text,
  date,
  time,
  boolean,
  timestamp,
} from "drizzle-orm/pg-core";
import { users } from "./users";
import { organizations } from "./organizations";

export const priorityEnum = ["none", "low", "medium", "high", "urgent"] as const;
export const locationContextEnum = ["none", "home", "work"] as const;

export const tasks = pgTable("tasks", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  orgId: uuid("org_id")
    .notNull()
    .references(() => organizations.id, { onDelete: "cascade" }),
  title: varchar("title", { length: 500 }).notNull(),
  notes: text("notes"),
  priority: varchar("priority", { length: 20 }).default("none"),
  dueDate: date("due_date"),
  dueTime: time("due_time"),
  tags: text("tags").array().default([]),
  locationContext: varchar("location_context", { length: 20 }).default("none"),
  isCompleted: boolean("is_completed").default(false),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow(),
});

export type Task = typeof tasks.$inferSelect;
export type NewTask = typeof tasks.$inferInsert;
