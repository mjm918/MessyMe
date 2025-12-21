# AGENTS.md

## Overview

A minimal Bun TypeScript backend project. Currently in early development with a single entry point.

## Tech Stack

- **Runtime**: Bun (v1.1.34+)
- **Language**: TypeScript 5.0+
- **Dependencies**: `ai` SDK (v5.0.116) for AI/LLM integration

## Commands

```bash
# Install dependencies
bun install

# Run the application
bun run main.ts
```

## Project Structure

```
backend/
├── main.ts          # Entry point
├── package.json     # Dependencies and config
├── tsconfig.json    # TypeScript configuration
├── bun.lockb        # Bun lockfile
├── llm.txt          # RAG agent guide reference
└── README.md        # Basic setup docs
```

## TypeScript Configuration

- **Target**: ESNext with DOM lib
- **Module**: ESNext with bundler resolution
- **Strict mode**: Enabled
- **JSX**: react-jsx
- **No emit**: Uses Bun's native TypeScript execution

## Code Conventions

- ES Modules (`"type": "module"`)
- Use `.ts` imports directly (Bun supports this)
- Strict TypeScript (no implicit any, strict null checks)

## AI SDK Usage

The project includes the Vercel AI SDK (`ai` package). Reference `llm.txt` for patterns on:
- RAG (Retrieval Augmented Generation) implementation
- Embeddings and vector storage
- Multi-modal agents
- Tool calling with `streamText` and `generateText`
- Using `@ai-sdk/react` for frontend hooks

## Notes

- This is a fresh Bun project with minimal code
- No test framework configured yet
- No linting/formatting configured yet
- Designed for rapid prototyping with the AI SDK
