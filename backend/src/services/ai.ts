import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { generateText } from "ai";
import { searchSimilar, findSimilarTasks } from "./qdrant";
import type { SearchResult } from "./qdrant";
import { db, schema } from "../db";
import { eq, and } from "drizzle-orm";

const google = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY!,
});

const model = google("gemini-flash-latest");

export interface RAGContext {
  results: SearchResult[];
  formattedContext: string;
}

export async function getRAGContext(
  orgId: string,
  query: string,
  limit = 10
): Promise<RAGContext> {
  const results = await searchSimilar(orgId, query, limit);

  const formattedContext = results
    .map((r, i) => {
      return `[${i + 1}] (${r.type}) ${r.content}`;
    })
    .join("\n\n");

  return { results, formattedContext };
}

export async function askWithRAG(
  orgId: string,
  query: string
): Promise<{ answer: string; sources: SearchResult[] }> {
  const { results, formattedContext } = await getRAGContext(orgId, query);

  const systemPrompt = `You are a helpful assistant for the MessyMe productivity app.
You have access to the user's organization data including tasks, meetings, and recordings.
Answer questions based on the provided context. If you cannot find relevant information in the context, say so.
Be concise and helpful.`;

  const userPrompt = `Context from knowledge base:
${formattedContext}

User question: ${query}

Please answer based on the context above.`;

  const { text } = await generateText({
    model,
    system: systemPrompt,
    prompt: userPrompt,
  });

  return {
    answer: text,
    sources: results,
  };
}

export interface PrioritizationContext {
  tasks: any[];
  breakHistory: any[];
  locationHistory: any[];
  currentLocation?: { latitude: number; longitude: number };
  currentTime: Date;
  similarTasksMap: Map<string, SearchResult[]>;
}

export async function prioritizeTasks(
  userId: string,
  orgId: string,
  currentLocation?: { latitude: number; longitude: number }
): Promise<any[]> {
  // Get user's tasks
  const tasks = await db
    .select()
    .from(schema.tasks)
    .where(
      and(
        eq(schema.tasks.userId, userId),
        eq(schema.tasks.orgId, orgId),
        eq(schema.tasks.isCompleted, false)
      )
    );

  if (tasks.length === 0) {
    return [];
  }

  // Get break history (last 7 days)
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const breakHistory = await db
    .select()
    .from(schema.breakHistory)
    .where(eq(schema.breakHistory.userId, userId));

  // Get location history (last 7 days)
  const locationHistory = await db
    .select()
    .from(schema.locationHistory)
    .where(eq(schema.locationHistory.userId, userId));

  // Get user's locations (home/work)
  const locations = await db
    .select()
    .from(schema.locations)
    .where(eq(schema.locations.userId, userId));

  // Find similar tasks for each task (for org-wide coordination)
  const similarTasksMap = new Map<string, SearchResult[]>();
  for (const task of tasks) {
    const taskContent = `${task.title} ${task.notes || ""}`;
    const similar = await findSimilarTasks(orgId, taskContent, task.id, 3);
    similarTasksMap.set(task.id, similar);
  }

  // Determine current location context
  let locationContext = "unknown";
  if (currentLocation && locations.length > 0) {
    for (const loc of locations) {
      if (loc.latitude && loc.longitude) {
        const distance = calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          loc.latitude,
          loc.longitude
        );
        if (distance < 0.5) {
          // Within 500m
          locationContext = loc.type || "custom";
          break;
        }
      }
    }
  }

  // Build context for AI
  const tasksContext = tasks
    .map((t) => {
      const similar = similarTasksMap.get(t.id) || [];
      const similarInfo =
        similar.length > 0
          ? `Similar tasks in org: ${similar.map((s) => s.metadata.title).join(", ")}`
          : "";
      return `- ID: ${t.id}
  Title: ${t.title}
  Priority: ${t.priority}
  Due: ${t.dueDate || "No due date"} ${t.dueTime || ""}
  Location: ${t.locationContext}
  Tags: ${t.tags?.join(", ") || "none"}
  ${similarInfo}`;
    })
    .join("\n\n");

  const breakPatterns = analyzeBreakPatterns(breakHistory);
  const locationPatterns = analyzeLocationPatterns(locationHistory, locations);

  const systemPrompt = `You are an AI assistant that helps prioritize tasks for maximum productivity.
Consider the following factors when prioritizing:
1. Due dates and urgency
2. Explicit priority levels set by user
3. Current location (${locationContext}) - prioritize matching tasks
4. Break patterns - avoid scheduling heavy tasks during typical break times
5. Location patterns - predict where user will be and suggest accordingly
6. Similar tasks across the organization - coordinate priorities for team alignment

Current time: ${new Date().toISOString()}
Current location context: ${locationContext}

Break patterns: ${breakPatterns}
Location patterns: ${locationPatterns}`;

  const userPrompt = `Please prioritize these tasks and return them in order of suggested priority.
For each task, provide a brief reason for its position.

Tasks:
${tasksContext}

Return a JSON array with this structure:
[
  {
    "id": "task-uuid",
    "suggestedPriority": 1,
    "reason": "Brief explanation"
  }
]

Only return the JSON array, no other text.`;

  try {
    const { text } = await generateText({
      model,
      system: systemPrompt,
      prompt: userPrompt,
    });

    // Parse AI response
    const jsonMatch = text.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      // Fallback: return tasks sorted by existing priority and due date
      return tasks.sort((a, b) => {
        const priorityOrder = { urgent: 0, high: 1, medium: 2, low: 3, none: 4 };
        const aPriority = priorityOrder[a.priority as keyof typeof priorityOrder] ?? 4;
        const bPriority = priorityOrder[b.priority as keyof typeof priorityOrder] ?? 4;
        if (aPriority !== bPriority) return aPriority - bPriority;
        if (a.dueDate && b.dueDate) return a.dueDate.localeCompare(b.dueDate);
        if (a.dueDate) return -1;
        if (b.dueDate) return 1;
        return 0;
      });
    }

    const priorities = JSON.parse(jsonMatch[0]);
    const taskMap = new Map(tasks.map((t) => [t.id, t]));

    return priorities.map((p: any) => ({
      ...taskMap.get(p.id),
      suggestedPriority: p.suggestedPriority,
      priorityReason: p.reason,
    }));
  } catch (error) {
    console.error("AI prioritization failed:", error);
    // Fallback
    return tasks.sort((a, b) => {
      const priorityOrder = { urgent: 0, high: 1, medium: 2, low: 3, none: 4 };
      const aPriority = priorityOrder[a.priority as keyof typeof priorityOrder] ?? 4;
      const bPriority = priorityOrder[b.priority as keyof typeof priorityOrder] ?? 4;
      return aPriority - bPriority;
    });
  }
}

function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function analyzeBreakPatterns(breakHistory: any[]): string {
  if (breakHistory.length === 0) return "No break history available";

  const byType: Record<string, number[]> = {};

  for (const b of breakHistory) {
    const hour = new Date(b.startedAt).getHours();
    const type = b.type || "unknown";
    if (!byType[type]) byType[type] = [];
    byType[type].push(hour);
  }

  const patterns = Object.entries(byType)
    .map(([type, hours]) => {
      const avgHour = Math.round(hours.reduce((a, b) => a + b, 0) / hours.length);
      return `${type}: typically around ${avgHour}:00`;
    })
    .join(", ");

  return patterns || "No clear patterns";
}

function analyzeLocationPatterns(
  locationHistory: any[],
  locations: any[]
): string {
  if (locationHistory.length === 0) return "No location history available";

  const locationMap = new Map(locations.map((l) => [l.id, l]));
  const byHour: Record<number, string[]> = {};

  for (const h of locationHistory) {
    const hour = new Date(h.recordedAt).getHours();
    const loc = h.locationId ? locationMap.get(h.locationId) : null;
    const locType = loc?.type || "unknown";
    if (!byHour[hour]) byHour[hour] = [];
    byHour[hour].push(locType);
  }

  // Find most common location per time block
  const morningLocs = [...(byHour[8] || []), ...(byHour[9] || []), ...(byHour[10] || [])];
  const afternoonLocs = [...(byHour[14] || []), ...(byHour[15] || []), ...(byHour[16] || [])];
  const eveningLocs = [...(byHour[18] || []), ...(byHour[19] || []), ...(byHour[20] || [])];

  const getMostCommon = (arr: string[]) => {
    if (arr.length === 0) return "unknown";
    const counts: Record<string, number> = {};
    arr.forEach((l) => (counts[l] = (counts[l] || 0) + 1));
    return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  };

  return `Morning: typically at ${getMostCommon(morningLocs)}, Afternoon: ${getMostCommon(afternoonLocs)}, Evening: ${getMostCommon(eveningLocs)}`;
}
