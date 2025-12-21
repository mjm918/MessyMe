# MessyMe Backend

Backend API for the MessyMe macOS menu bar task management app.

## Tech Stack

- **Runtime**: Bun
- **Framework**: Hono
- **Database**: PostgreSQL with Drizzle ORM (no migrations)
- **Vector DB**: Qdrant (separate collection per organization)
- **AI**: Google Gemini 2.5 Pro via AI SDK (@ai-sdk/google)
- **Embeddings**: gemini-embedding-001 (3072 dimensions)

## Architecture

```
┌─────────────────┐     REST API      ┌─────────────────┐
│   MessyMe App   │ ◄───────────────► │   Hono Backend  │
│   (macOS/Swift) │                   │     (Bun)       │
└─────────────────┘                   └────────┬────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
              ┌─────▼─────┐            ┌───────▼───────┐          ┌───────▼───────┐
              │ PostgreSQL │            │    Qdrant     │          │    Google     │
              │  (Drizzle) │            │  (per-org     │          │  Gemini API   │
              │            │            │  collections) │          │  (2.5 Pro)    │
              └────────────┘            └───────────────┘          └───────────────┘
```

## Core Concepts

### Multi-Tenancy

- Organizations act as tenants
- Every table has `org_id` (tenant_id) for data isolation
- Each org gets its own Qdrant collection: `org_{org_id}`

### Authentication

- No traditional auth management
- Just-In-Time (JIT) user creation based on email
- Frontend sends email, backend creates user if not exists

### Organization Management

- Create org with unique 6-character alphanumeric invite code (e.g., `ABC123`)
- Creator becomes admin
- Only admin can: kick users, delete org
- Others join via invite code

### Data Ownership

| Data Type | Scope | Description |
|-----------|-------|-------------|
| Tasks | Per User | Personal tasks with priority, due dates, tags, location context |
| Recordings | Per Org | Voice memos and meeting recordings with transcripts |
| Meetings | Per Org | Meeting notes, dates, participants |
| Breaks | Per User | Prayer, meal, rest schedules and history |
| Locations | Per User | Home, work, custom locations for geofencing |

## RAG System

### What Gets Embedded

Everything is embedded for comprehensive search:
- Meeting notes and transcripts
- Recording transcripts (sent from frontend)
- Task titles and descriptions
- Notes content

### Semantic Task Matching

RAG identifies semantically similar tasks across users in an org. If two users work on related tasks, AI coordinates their priorities.

## AI Features

### 1. Knowledge Base Search

Query org data via RAG, return relevant context from meetings, recordings, tasks.

### 2. AI-Powered Responses

Generate intelligent responses using retrieved context + Gemini.

### 3. Smart Task Prioritization

AI considers:
- Task priority, due dates, tags
- Location context (home/work tasks)
- Current user location (sent from frontend)
- Location + time patterns (learns when user is typically where)
- Break patterns (prayer, meals, rest history)
- Semantic similarity with other users' tasks in org

## Database Schema

### Users
- `id` (UUID, PK)
- `email` (unique)
- `name`
- `created_at`
- `updated_at`

### Organizations
- `id` (UUID, PK)
- `name`
- `invite_code` (unique, 6-char alphanumeric)
- `admin_user_id` (FK to users)
- `created_at`
- `updated_at`

### OrgMembers
- `id` (UUID, PK)
- `org_id` (FK)
- `user_id` (FK)
- `joined_at`

### Tasks
- `id` (UUID, PK)
- `user_id` (FK)
- `org_id` (FK, tenant_id)
- `title`
- `notes`
- `priority` (none, low, medium, high, urgent)
- `due_date` (nullable)
- `due_time` (nullable)
- `tags` (text array)
- `location_context` (none, home, work)
- `is_completed`
- `completed_at`
- `created_at`
- `updated_at`

### Recordings
- `id` (UUID, PK)
- `org_id` (FK, tenant_id)
- `user_id` (FK, creator)
- `type` (voice_memo, meeting)
- `title`
- `transcript` (text, sent from frontend)
- `duration_seconds`
- `created_at`
- `updated_at`

### Meetings
- `id` (UUID, PK)
- `org_id` (FK, tenant_id)
- `user_id` (FK, creator)
- `title`
- `notes`
- `meeting_date`
- `participants` (text array)
- `created_at`
- `updated_at`

### Locations
- `id` (UUID, PK)
- `user_id` (FK)
- `name` (e.g., "Home", "Work", "Gym")
- `type` (home, work, custom)
- `address`
- `latitude`
- `longitude`
- `created_at`
- `updated_at`

### Breaks
- `id` (UUID, PK)
- `user_id` (FK)
- `type` (prayer, meal, rest)
- `name` (e.g., "Fajr", "Lunch", "Afternoon Rest")
- `scheduled_time`
- `is_recurring`
- `recurrence_pattern` (daily, weekdays, custom)
- `created_at`
- `updated_at`

### BreakHistory
- `id` (UUID, PK)
- `break_id` (FK)
- `user_id` (FK)
- `started_at`
- `ended_at`
- `duration_minutes`

### LocationHistory
- `id` (UUID, PK)
- `user_id` (FK)
- `location_id` (FK, nullable)
- `latitude`
- `longitude`
- `recorded_at`

## API Endpoints

### Users
- `POST /users` - Create/get user (JIT by email)
- `GET /users/:id` - Get user details

### Organizations
- `POST /orgs` - Create org (returns invite code)
- `GET /orgs/:id` - Get org details
- `POST /orgs/join` - Join org via invite code
- `DELETE /orgs/:id` - Delete org (admin only)
- `DELETE /orgs/:id/members/:userId` - Kick user (admin only)

### Tasks
- `GET /tasks` - List user's tasks (with filters)
- `POST /tasks` - Create task
- `PUT /tasks/:id` - Update task
- `DELETE /tasks/:id` - Delete task
- `POST /tasks/:id/complete` - Mark complete

### Recordings
- `GET /orgs/:orgId/recordings` - List recordings
- `POST /orgs/:orgId/recordings` - Create recording (with transcript)
- `GET /orgs/:orgId/recordings/:id` - Get recording
- `DELETE /orgs/:orgId/recordings/:id` - Delete recording

### Meetings
- `GET /orgs/:orgId/meetings` - List meetings
- `POST /orgs/:orgId/meetings` - Create meeting
- `PUT /orgs/:orgId/meetings/:id` - Update meeting
- `DELETE /orgs/:orgId/meetings/:id` - Delete meeting

### Locations
- `GET /users/:userId/locations` - List user locations
- `POST /users/:userId/locations` - Create location
- `PUT /users/:userId/locations/:id` - Update location
- `DELETE /users/:userId/locations/:id` - Delete location
- `POST /users/:userId/location-history` - Log current location

### Breaks
- `GET /users/:userId/breaks` - List break schedules
- `POST /users/:userId/breaks` - Create break schedule
- `PUT /users/:userId/breaks/:id` - Update break
- `DELETE /users/:userId/breaks/:id` - Delete break
- `POST /users/:userId/breaks/:id/log` - Log break taken

### AI / RAG
- `POST /orgs/:orgId/search` - Search knowledge base (RAG)
- `POST /orgs/:orgId/ask` - Ask AI with RAG context
- `POST /users/:userId/prioritize` - Get AI task prioritization

## Environment Variables

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=messyme
DB_SCHEMA=public

GEMINI_API_KEY=your-api-key-here

QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_KEY=

PORT=3000
```

## Project Structure

```
src/
├── index.ts              # Hono app entry
├── db/
│   ├── index.ts          # Drizzle client
│   └── schema/           # Drizzle schemas
│       ├── users.ts
│       ├── organizations.ts
│       ├── tasks.ts
│       ├── recordings.ts
│       ├── meetings.ts
│       ├── locations.ts
│       └── breaks.ts
├── routes/
│   ├── users.ts
│   ├── orgs.ts
│   ├── tasks.ts
│   ├── recordings.ts
│   ├── meetings.ts
│   ├── locations.ts
│   ├── breaks.ts
│   └── ai.ts
├── services/
│   ├── qdrant.ts         # Vector DB operations
│   ├── embedding.ts      # Text embedding
│   ├── rag.ts            # RAG search
│   └── ai.ts             # Gemini AI operations
└── utils/
    ├── invite-code.ts    # Generate invite codes
    └── tenant.ts         # Multi-tenant helpers
```
