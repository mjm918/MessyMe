import {
  pgTable,
  uuid,
  varchar,
  text,
  doublePrecision,
  timestamp,
} from "drizzle-orm/pg-core";
import { users } from "./users";

export const locationTypeEnum = ["home", "work", "custom"] as const;

export const locations = pgTable("locations", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  name: varchar("name", { length: 255 }).notNull(),
  type: varchar("type", { length: 20 }).default("custom"),
  address: text("address"),
  latitude: doublePrecision("latitude"),
  longitude: doublePrecision("longitude"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow(),
});

export const locationHistory = pgTable("location_history", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  locationId: uuid("location_id").references(() => locations.id, {
    onDelete: "set null",
  }),
  latitude: doublePrecision("latitude").notNull(),
  longitude: doublePrecision("longitude").notNull(),
  recordedAt: timestamp("recorded_at", { withTimezone: true }).defaultNow(),
});

export type Location = typeof locations.$inferSelect;
export type NewLocation = typeof locations.$inferInsert;
export type LocationHistory = typeof locationHistory.$inferSelect;
export type NewLocationHistory = typeof locationHistory.$inferInsert;
