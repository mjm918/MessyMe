# MessyMe

A minimalist macOS menu bar task management app designed for productivity without distraction.

## Purpose

MessyMe lives quietly in your menu bar, providing quick access to task management without the overhead of a full-windowed application. It's designed for users who want to capture tasks quickly, stay organized, and get back to work with minimal friction.

## Features

### Menu Bar Interface
- **Always accessible** from the menu bar icon
- **Global hotkey** (⌘+Shift+Space) to quickly open the popover
- **No dock icon** - stays out of your way
- **Monochrome design** - clean, distraction-free aesthetic

### Task Management
- **Quick task entry** - add tasks in seconds with just a title
- **Rich task details**:
  - Title and notes
  - Priority levels (None, Low, Medium, High, Urgent)
  - Flexible due dates (Date only, Date & Time, No date)
  - Custom tags for organization
- **Smart filtering**:
  - Today - tasks due today
  - All - complete task overview
  - Upcoming - future tasks
  - Overdue - past-due items highlighted

### Audio Recordings
- **Voice memos** - quick audio notes captured from menu bar
- **Meeting recordings** - longer format recordings for meetings
- **Speech transcription** - automatic transcription using Apple's Speech framework
- **iOS Voice Memos-like UI** - familiar, intuitive interface

### Claude AI Integration
- **AI-powered prioritization** - let Claude help organize your tasks
- **Smart suggestions** for task management

### Location Awareness
- **Geofencing** for Home and Work locations
- **Location-based reminders** - get notified when arriving/leaving
- **MapKit integration** - search and set locations easily
- **Custom location names** and addresses

### Break Tracking
- **Prayer time tracking** - for users with religious obligations
- **Meal breaks** - lunch, dinner reminders
- **Rest breaks** - scheduled rest periods
- **Break history** - track your break patterns

### Shopping List
- **Smart tag system** - use #shopping tag for shopping items
- **Quick capture** - add items on the go
- **Separate view** - dedicated shopping list interface

### Search Data
- **Search Knowledgebase** - call backend API to search for related data on task, recording, meetings

## Design Philosophy

### Monochrome Aesthetic
MessyMe uses a strict black and white color scheme to minimize visual distraction. The interface relies on:
- Clean typography
- Subtle shadows and borders
- Rounded corners for a modern feel
- Hover states for interactivity

### Native macOS Integration
- Uses native AppKit/SwiftUI components
- Respects system appearance (Light/Dark mode)
- Standard macOS button styles and text fields
- Keyboard navigation support

## Technical Stack

- **SwiftUI** - Modern declarative UI framework
- **Postgresql** - Data persistence
- **Combine** - Reactive programming
- **CoreLocation** - Location services
- **MapKit** - Map search and display
- **Speech** - Audio transcription
- **Network** - OAuth callback server

## Requirements

- macOS 14.0 (Sonoma) or later
- Microphone access (for recordings)
- Location access (optional, for geofencing)
- Speech recognition access (for transcription)

## Privacy

MessyMe requests the following permissions:
- **Microphone** - For audio recordings
- **Speech Recognition** - For transcribing recordings
- **Location** - For Home/Work geofencing (optional)

All data is stored locally on your Mac using SwiftData.

## Getting Started

1. Launch MessyMe
2. Click the menu bar icon or press ⌘+Shift+Space
3. Add your first task using the quick input field
4. Click on a task to view and edit details
5. Set up locations in Settings for geofencing
6. Connect Claude AI for smart prioritization (optional)