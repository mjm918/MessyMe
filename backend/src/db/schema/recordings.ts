import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  timestamp,
} from "drizzle-orm/pg-core";
import { users } from "./users";
import { organizations } from "./organizations";

export const recordingTypeEnum = ["voice_memo", "meeting"] as const;
export const transcriptionStatusEnum = ["pending", "processing", "completed", "failed"] as const;
export type TranscriptionStatus = typeof transcriptionStatusEnum[number];

export const recordings = pgTable("recordings", {
  id: uuid("id").primaryKey().defaultRandom(),
  orgId: uuid("org_id")
    .notNull()
    .references(() => organizations.id, { onDelete: "cascade" }),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  type: varchar("type", { length: 20 }).notNull(),
  title: varchar("title", { length: 500 }),
  transcript: text("transcript"),
  audioUrl: text("audio_url"),
  durationSeconds: integer("duration_seconds"),
  transcriptionStatus: varchar("transcription_status", { length: 20 }).default("pending"),
  transcriptionError: text("transcription_error"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow(),
});

export type Recording = typeof recordings.$inferSelect;
export type NewRecording = typeof recordings.$inferInsert;
