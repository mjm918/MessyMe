import { QdrantClient } from "@qdrant/js-client-rest";
import { generateEmbedding } from "./embedding";

const VECTOR_SIZE = 3072; // gemini-embedding-001 dimension

const qdrantHost = process.env.QDRANT_HOST || "localhost";
const qdrantPort = process.env.QDRANT_PORT || "6333";
const qdrantKey = process.env.QDRANT_KEY;

const client = new QdrantClient({
  url: `http://${qdrantHost}:${qdrantPort}`,
  ...(qdrantKey && { apiKey: qdrantKey }),
});

function getCollectionName(orgId: string): string {
  return `org_${orgId.replace(/-/g, "_")}`;
}

export async function createOrgCollection(orgId: string): Promise<void> {
  const collectionName = getCollectionName(orgId);

  try {
    await client.createCollection(collectionName, {
      vectors: {
        size: VECTOR_SIZE,
        distance: "Cosine",
      },
    });
    console.log(`Created Qdrant collection: ${collectionName}`);
  } catch (error: any) {
    // Collection might already exist
    if (!error.message?.includes("already exists")) {
      throw error;
    }
  }
}

export async function deleteOrgCollection(orgId: string): Promise<void> {
  const collectionName = getCollectionName(orgId);

  try {
    await client.deleteCollection(collectionName);
    console.log(`Deleted Qdrant collection: ${collectionName}`);
  } catch (error: any) {
    // Collection might not exist
    if (!error.message?.includes("not found")) {
      throw error;
    }
  }
}

export interface EmbeddingDocument {
  id: string;
  type: "task" | "recording" | "meeting";
  content: string;
  metadata: Record<string, any>;
}

export async function embedAndStore(
  orgId: string,
  doc: EmbeddingDocument
): Promise<void> {
  const collectionName = getCollectionName(orgId);

  // Generate embedding
  const embedding = await generateEmbedding(doc.content);

  // Upsert point
  await client.upsert(collectionName, {
    wait: true,
    points: [
      {
        id: doc.id,
        vector: embedding,
        payload: {
          type: doc.type,
          content: doc.content,
          ...doc.metadata,
        },
      },
    ],
  });
}

export async function deleteEmbedding(
  orgId: string,
  docId: string
): Promise<void> {
  const collectionName = getCollectionName(orgId);

  try {
    await client.delete(collectionName, {
      wait: true,
      points: [docId],
    });
  } catch (error) {
    // Ignore if point doesn't exist
    console.error("Error deleting embedding:", error);
  }
}

export interface SearchResult {
  id: string;
  score: number;
  type: string;
  content: string;
  metadata: Record<string, any>;
}

export async function searchSimilar(
  orgId: string,
  query: string,
  limit = 10,
  filter?: Record<string, any>
): Promise<SearchResult[]> {
  const collectionName = getCollectionName(orgId);

  // Generate query embedding
  const queryEmbedding = await generateEmbedding(query);

  // Search
  const results = await client.search(collectionName, {
    vector: queryEmbedding,
    limit,
    with_payload: true,
    filter: filter
      ? {
          must: Object.entries(filter).map(([key, value]) => ({
            key,
            match: { value },
          })),
        }
      : undefined,
  });

  return results.map((result) => ({
    id: result.id as string,
    score: result.score,
    type: (result.payload?.type as string) || "",
    content: (result.payload?.content as string) || "",
    metadata: result.payload || {},
  }));
}

export async function findSimilarTasks(
  orgId: string,
  taskContent: string,
  excludeTaskId?: string,
  limit = 5
): Promise<SearchResult[]> {
  const collectionName = getCollectionName(orgId);

  const queryEmbedding = await generateEmbedding(taskContent);

  const results = await client.search(collectionName, {
    vector: queryEmbedding,
    limit: limit + 1, // Get extra in case we need to exclude one
    with_payload: true,
    filter: {
      must: [{ key: "type", match: { value: "task" } }],
    },
  });

  return results
    .filter((r) => r.id !== excludeTaskId)
    .slice(0, limit)
    .map((result) => ({
      id: result.id as string,
      score: result.score,
      type: "task",
      content: (result.payload?.content as string) || "",
      metadata: result.payload || {},
    }));
}
