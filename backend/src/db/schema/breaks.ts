import {
  pgTable,
  uuid,
  varchar,
  time,
  boolean,
  integer,
  timestamp,
} from "drizzle-orm/pg-core";
import { users } from "./users";

export const breakTypeEnum = ["prayer", "meal", "rest"] as const;
export const recurrencePatternEnum = [
  "daily",
  "weekdays",
  "weekends",
  "custom",
] as const;

export const breaks = pgTable("breaks", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  type: varchar("type", { length: 20 }).notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  scheduledTime: time("scheduled_time"),
  isRecurring: boolean("is_recurring").default(true),
  recurrencePattern: varchar("recurrence_pattern", { length: 20 }).default(
    "daily"
  ),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow(),
});

export const breakHistory = pgTable("break_history", {
  id: uuid("id").primaryKey().defaultRandom(),
  breakId: uuid("break_id").references(() => breaks.id, {
    onDelete: "set null",
  }),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
  endedAt: timestamp("ended_at", { withTimezone: true }),
  durationMinutes: integer("duration_minutes"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export type Break = typeof breaks.$inferSelect;
export type NewBreak = typeof breaks.$inferInsert;
export type BreakHistory = typeof breakHistory.$inferSelect;
export type NewBreakHistory = typeof breakHistory.$inferInsert;
