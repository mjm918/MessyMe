import { eq, and, SQL } from "drizzle-orm";

export function withTenant<T extends { orgId: any }>(
  table: T,
  orgId: string
): SQL {
  return eq(table.orgId, orgId);
}

export function withUser<T extends { userId: any }>(
  table: T,
  userId: string
): SQL {
  return eq(table.userId, userId);
}

export function withTenantAndUser<T extends { orgId: any; userId: any }>(
  table: T,
  orgId: string,
  userId: string
): SQL {
  return and(eq(table.orgId, orgId), eq(table.userId, userId))!;
}
