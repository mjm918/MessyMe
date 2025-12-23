import { run, makeWorkerUtils } from "graphile-worker";
import type { WorkerUtils, TaskList } from "graphile-worker";
import { transcribeRecording } from "./tasks/transcribe";

let workerUtils: WorkerUtils | null = null;

// Task definitions
const taskList: TaskList = {
  transcribe_recording: transcribeRecording,
};

/**
 * Get or create the worker utils singleton for adding jobs
 */
export async function getWorkerUtils(): Promise<WorkerUtils> {
  if (!workerUtils) {
    workerUtils = await makeWorkerUtils({
      connectionString: getConnectionString(),
    });
  }
  return workerUtils;
}

/**
 * Add a transcription job to the queue
 */
export async function addTranscriptionJob(recordingId: string, audioUrl: string, orgId: string) {
  const utils = await getWorkerUtils();
  await utils.addJob(
    "transcribe_recording",
    { recordingId, audioUrl, orgId },
    {
      maxAttempts: 3,
      jobKey: `transcribe:${recordingId}`, // Prevent duplicate jobs
    }
  );
}

/**
 * Start the worker process
 */
export async function startWorker() {
  const connectionString = getConnectionString();

  console.log("[Worker] Starting graphile-worker...");

  const runner = await run({
    connectionString,
    concurrency: 2, // Process 2 jobs concurrently
    noHandleSignals: false,
    pollInterval: 1000, // Poll every second
    taskList,
  });

  console.log("[Worker] Worker started successfully");

  // Handle graceful shutdown
  process.on("SIGTERM", async () => {
    console.log("[Worker] Received SIGTERM, shutting down...");
    await runner.stop();
    if (workerUtils) {
      await workerUtils.release();
    }
  });

  return runner;
}

function getConnectionString(): string {
  const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = process.env;
  return `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT || "5432"}/${DB_NAME}`;
}
