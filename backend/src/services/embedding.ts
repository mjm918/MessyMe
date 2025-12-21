import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { embed } from "ai";

const google = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY!,
});

const embeddingModel = google.textEmbedding("gemini-embedding-001");

export async function generateEmbedding(text: string): Promise<number[]> {
  const { embedding } = await embed({
    model: embeddingModel,
    value: text,
  });

  return embedding;
}

export async function generateEmbeddings(texts: string[]): Promise<number[][]> {
  const results = await Promise.all(
    texts.map((text) => generateEmbedding(text))
  );
  return results;
}
