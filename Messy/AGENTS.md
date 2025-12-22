# AGENTS.md - Messy macOS App

A macOS menu bar task management app built with SwiftUI. The app lives in the menu bar and provides task management, recordings, AI-powered search, and organization features.

## Build & Run Commands

```bash
# Build the project (from Messy.xcodeproj directory)
xcodebuild -project Messy.xcodeproj -scheme Messy -configuration Debug build

# Build for release
xcodebuild -project Messy.xcodeproj -scheme Messy -configuration Release build

# Open in Xcode
open Messy.xcodeproj
```

The app requires a backend API server running on `http://127.0.0.1:3000` by default. Configure via environment variables:
- `API_HOST` - API server host (default: `127.0.0.1`)
- `API_PORT` - API server port (default: `3000`)

## Project Structure

```
Messy/
├── Messy.xcodeproj/          # Xcode project config
└── Messy/                    # Main app source
    ├── MessyApp.swift        # App entry point, menu bar setup
    ├── Info.plist            # App configuration
    ├── Messy.entitlements    # App entitlements
    ├── Assets.xcassets/      # App icons and colors
    ├── API/                  # Backend API layer
    │   ├── APIClient.swift   # Base HTTP client (singleton)
    │   ├── Models.swift      # All Codable data models
    │   ├── TasksAPI.swift    # Task endpoints
    │   ├── AIAPI.swift       # AI/RAG endpoints
    │   ├── RecordingsAPI.swift
    │   ├── UsersAPI.swift
    │   ├── OrganizationsAPI.swift
    │   ├── BreaksAPI.swift
    │   ├── LocationsAPI.swift
    │   └── MeetingsAPI.swift
    ├── ViewModels/
    │   └── AppState.swift    # Central state management (singleton)
    ├── Views/
    │   ├── MainContentView.swift   # Root view with navigation
    │   ├── TaskListView.swift      # Task list with filters
    │   ├── TaskDetailView.swift    # Task editing detail view
    │   ├── RecordingsView.swift    # Recordings list
    │   ├── SearchView.swift        # Search + AI Ask
    │   ├── SettingsView.swift      # Settings panels
    │   ├── UIComponents.swift      # Reusable UI components
    │   └── Components/             # (empty, for future components)
    ├── Extensions/                 # (empty, for future extensions)
    ├── Components/                 # (empty, for future components)
    └── Utilities/                  # (empty, for future utilities)
```

## Architecture Patterns

### State Management
- **Singleton Pattern**: `AppState.shared` is the central state manager
- **`@MainActor`**: All state and API classes are MainActor-isolated
- **`@Published` properties**: Reactive updates via Combine
- **`@EnvironmentObject`**: Views access `AppState` via environment injection

```swift
// AppState is injected at root
MainContentView()
    .environmentObject(AppState.shared)

// Views consume it
@EnvironmentObject var appState: AppState
```

### API Layer
- **Singleton**: `APIClient.shared` handles all HTTP requests
- **Extension Pattern**: Each API domain extends `APIClient`
- **Async/Await**: All API methods are async
- **Generic Requests**: `request<T: Decodable>()` for type-safe responses

```swift
// API extensions pattern
extension APIClient {
    func getTasks(userId: String, orgId: String) async throws -> [TaskItem] {
        // ...
    }
}
```

### Navigation
- **`NavigationTab` enum**: Defines all navigation destinations
- **Tab-based filtering**: `selectedTab` drives content view switching
- **Hero animations**: Task detail uses matched geometry transitions

## Naming Conventions

### Files
- `*View.swift` - SwiftUI views
- `*API.swift` - API endpoint extensions
- `AppState.swift` - Central state management
- `Models.swift` - All data models in one file

### Types
- **Models**: PascalCase, match backend schema (`TaskItem`, `Recording`, `Organization`)
- **Enums**: PascalCase with lowercase cases (`TaskPriority.high`, `NavigationTab.today`)
- **Request/Response**: Named by operation (`CreateTaskRequest`, `AskResponse`)

### SwiftUI
- **View structs**: PascalCase (`TaskListView`, `GlassMorphicCard`)
- **Private computed properties**: camelCase (`private var headerView`)
- **View modifiers**: `.messyFont(.headline)`, `.glow(color:radius:)`

## Code Patterns

### Creating API Endpoints
1. Add models to `Models.swift` if needed
2. Create or extend `*API.swift` file in `API/` directory
3. Add corresponding methods to `AppState.swift`

```swift
// Models.swift
struct MyNewRequest: Codable {
    let field: String
}

// MyAPI.swift (new file or extension)
extension APIClient {
    func myEndpoint(param: String) async throws -> MyResponse {
        let request = MyNewRequest(field: param)
        return try await post(path: "/my/endpoint", body: request)
    }
}

// AppState.swift
func doMyThing(param: String) async {
    do {
        let result = try await api.myEndpoint(param: param)
        // Update published properties
    } catch {
        showError(error)
    }
}
```

### Creating Views
- Use `@EnvironmentObject var appState: AppState`
- Use `GlassMorphicCard` for card-style containers
- Use `.messyFont()` modifier for typography
- Use `BouncyButtonStyle()` for interactive buttons
- Use `withAnimation(.spring(...))` for state changes

### Error Handling
- `AppState.showError(_:)` sets `errorMessage` and `showError`
- Errors auto-dismiss after 3 seconds
- Error banner displays in `MainContentView`

## UI/Design System

### Brand Color
```swift
Color.messyBrand  // Orange (.orange)
```

### Typography (via `.messyFont()`)
- `.largeTitle` - 24pt bold rounded
- `.title` - 20pt semibold rounded
- `.headline` - 16pt semibold
- `.body` - 14pt regular
- `.caption` - 12pt medium

### Components
- `GlassMorphicCard` - Frosted glass card container
- `BouncyButtonStyle` - Scale-bounce button interaction
- `VisualEffectBlur` - NSVisualEffectView wrapper
- `FloatingParticlesView` - Ambient particles animation
- `.shimmer()` - Loading shimmer effect
- `.glow()` - Shadow glow effect

### Animations
- Use `.spring(response: 0.3-0.5, dampingFraction: 0.7-0.85)`
- Use `withAnimation(.spring(...))` for state-driven animations
- Use `.symbolEffect(.bounce)` for SF Symbol animations

## Data Models Overview

### Core Entities
- `User` - User account (id, email, name)
- `Organization` - Team/workspace (id, name, inviteCode)
- `TaskItem` - Task with priority, due date, tags, location context
- `Recording` - Voice memo or meeting recording
- `Meeting` - Meeting with participants
- `Location` - Saved location (home, work, custom)
- `Break` - Scheduled break (prayer, meal, rest)

### Enums
- `TaskPriority`: none, low, medium, high, urgent
- `LocationContext`: none, home, work
- `RecordingType`: voice_memo, meeting
- `LocationType`: home, work, custom
- `BreakType`: prayer, meal, rest

## Backend API Endpoints

The app expects these REST endpoints on the API server:

### Users
- `POST /users` - Create/get user
- `GET /users/:id/organizations` - Get user's orgs

### Organizations
- `POST /organizations` - Create org
- `POST /organizations/join` - Join via invite code

### Tasks
- `GET /tasks` - List tasks (query: userId, orgId, filter, completed)
- `POST /tasks` - Create task
- `GET /tasks/:id` - Get task
- `PUT /tasks/:id` - Update task
- `DELETE /tasks/:id` - Delete task
- `POST /tasks/:id/complete` - Mark complete
- `POST /tasks/:id/uncomplete` - Mark incomplete

### AI/RAG
- `POST /ai/search` - Search knowledge base
- `POST /ai/ask` - Ask AI with RAG context
- `POST /ai/prioritize` - Get AI task prioritization

### Recordings
- `GET /recordings` - List recordings
- `POST /recordings` - Create recording
- `DELETE /recordings/:id` - Delete recording

### Other
- Similar CRUD patterns for breaks, locations, meetings

## Key Gotchas

### Menu Bar App Behavior
- App uses `.accessory` activation policy (no dock icon)
- Uses `NSPopover` for the main UI window
- Global hotkey: `Cmd+Shift+Space` to toggle
- Click outside popover closes it

### API Host Configuration
- Uses `127.0.0.1` instead of `localhost` to avoid DNS issues in sandboxed apps
- Configure via environment variables, not hardcoded

### Date Handling
- Backend dates come as ISO8601 strings with varying formats
- `APIClient` has custom date decoding strategy handling:
  - ISO8601 with fractional seconds
  - ISO8601 without fractional seconds
  - Date-only format (yyyy-MM-dd)
- Due dates stored as `String?` in `TaskItem` (not `Date`)

### Session Persistence
- User session stored in UserDefaults (`messy_user_email`, `messy_user_id`, `messy_org_id`)
- Session restored automatically on app launch
- `logout()` clears session and all cached data

### Sign In with Apple
- Uses stable user identifier for email: `\(userIdentifier)@apple.messy.id`
- Not using actual Apple email to maintain consistent identity

### Task Filtering
- Filtering happens client-side in `AppState.filterTasks()`
- Uses local timezone for date comparisons
- Due date is compared as string prefix `yyyy-MM-dd`

### Empty Directories
- `Extensions/`, `Components/`, `Utilities/`, `Views/Components/` are placeholder directories
- Add new helpers and components to appropriate locations

## Testing

No test files currently exist. When adding tests:
- Create `MessyTests` target in Xcode
- Use XCTest framework
- Mock `APIClient` for unit tests
- Consider UI tests for critical flows (login, task creation)

## Dependencies

- **SwiftUI** - UI framework
- **Combine** - Reactive data binding
- **AuthenticationServices** - Sign In with Apple
- **MapKit** - Location features (in SettingsView)
- **AppKit** - macOS native integration (NSStatusItem, NSPopover)

No external package dependencies (SPM/CocoaPods).
