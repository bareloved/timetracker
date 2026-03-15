# TimeTracker — Design Spec

A macOS menu bar app that automatically tracks what you're doing and writes it to Apple Calendar.

## Problem

You want a passive record of how you spend time on your Mac without manual timers or input. The output should live in Apple Calendar so it's visible alongside your existing schedule.

## Decisions

- **Platform:** Native SwiftUI macOS menu bar app
- **Tracking:** Automatic — detects frontmost app + window title
- **Calendar:** Apple Calendar via EventKit (dedicated "Time Tracker" calendar)
- **Categorization:** Rule-based with sensible defaults, user-editable
- **Session grouping:** Smart — clusters related apps into sessions, merges short interruptions
- **UI:** Menu bar only (no dock icon, no main window)
- **Persistence:** Calendar is the persistence layer — no database

## Architecture

Four components:

### 1. Activity Monitor

Polls every 5 seconds:
- Frontmost app bundle ID and name via `NSWorkspace.shared.frontmostApplication`
- Active window title via Accessibility API (`AXUIElementCopyAttributeValue`)

Produces raw activity records: `(bundleId, appName, windowTitle, timestamp)`.

Ignores idle time: if the screen is locked or the user is idle for > 5 minutes (detected via `CGEventSourceSecondsSinceLastEventType`), the monitor pauses and the current session is finalized.

### 2. Session Engine

Groups raw activities into sessions using two mechanisms:

**Categorization rules** — a JSON config mapping bundle IDs to categories:

```json
{
  "categories": {
    "Coding": {
      "apps": ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"],
      "related": ["com.apple.Terminal", "com.googlechrome.canary"]
    },
    "Email": {
      "apps": ["com.apple.mail", "com.readdle.smartemail.macos"]
    },
    "Communication": {
      "apps": ["com.tinyspeck.slackmacgap", "us.zoom.xos", "com.apple.MobileSMS"]
    },
    "Design": {
      "apps": ["com.figma.Desktop", "com.bohemiancoding.sketch3"]
    },
    "Writing": {
      "apps": ["com.apple.iWork.Pages", "com.microsoft.Word", "md.obsidian"]
    },
    "Browsing": {
      "apps": ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"]
    }
  },
  "default_category": "Other"
}
```

`apps` are primary indicators — if the frontmost app is in this list, the activity belongs to this category. `related` apps get absorbed into the current session if that category is already active (e.g. Terminal counts as "Coding" if you were just in Xcode, but as "Other" if you opened it cold).

**Session grouping logic:**
- A session starts when a new category is detected
- Short switches away (< 2 minutes) are absorbed back into the current session
- If the same category resumes within 5 minutes, the session is extended rather than creating a new one
- Idle periods > 5 minutes finalize the current session

The config file lives at `~/Library/Application Support/TimeTracker/categories.json`. On first launch, the app writes the defaults. Users edit this file to customize.

### 3. Calendar Writer

Uses EventKit framework:

- On first launch, requests calendar access and creates a "Time Tracker" calendar (color: blue)
- When a new session starts: creates an `EKEvent` with title = category name, notes = list of apps used
- While the session is active: updates the event's end time every 30 seconds
- When a session ends: finalizes the event with the actual end time and full app list
- Event structure:
  - **Title:** Category name (e.g. "Coding")
  - **Calendar:** "Time Tracker"
  - **Start/End:** Session timestamps
  - **Notes:** Apps used (e.g. "Xcode, Terminal, Safari")

Uses `EKEventStore` with `requestFullAccessToEvents`. Keeps a reference to the current `EKEvent` to update it in place rather than creating duplicates.

### 4. Menu Bar UI

SwiftUI `MenuBarExtra` with `.window` style for the detailed dropdown:

**Menu bar icon:** `clock.badge.checkmark` SF Symbol. No text in the menu bar itself.

**Dropdown contents:**
- Status indicator (green dot + "Tracking Active" or yellow dot + "Paused")
- Current session card: category name, duration, list of apps
- Today's summary: list of categories with total time, sorted by duration
- Controls: Pause/Resume toggle, Settings (opens categories.json in default editor), Quit

**App lifecycle:**
- `@main` App struct with `MenuBarExtra`
- No `NSApplicationDelegate` dock icon: set `LSUIElement = true` in Info.plist
- Launch at login: `SMAppService.mainApp.register()`

### Component Interaction

```
┌─────────────────┐
│ Activity Monitor │  polls every 5s
│  (NSWorkspace +  │──→ raw activity record
│  Accessibility)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Session Engine  │  categorizes + groups
│  (Rules + State) │──→ session start/update/end events
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────┐
│Calendar│ │ Menu Bar  │
│ Writer │ │    UI     │
│(Event- │ │ (SwiftUI  │
│  Kit)  │ │MenuBar-   │
└────────┘ │  Extra)   │
           └──────────┘
```

## Permissions

The app requires two permissions:
1. **Calendar access** — EventKit (`NSCalendarsFullAccessUsageDescription`)
2. **Accessibility access** — for reading window titles (user must grant in System Settings > Privacy & Security > Accessibility)

If accessibility access is not granted, the app still works but logs only app names, not window titles. The menu bar dropdown shows a subtle warning prompting the user to grant access.

## Project Structure

```
TimeTracker/
├── TimeTrackerApp.swift          # @main, MenuBarExtra setup
├── Models/
│   ├── ActivityRecord.swift      # Raw activity data struct
│   ├── Session.swift             # Session model
│   └── Category.swift            # Category + rules model
├── Services/
│   ├── ActivityMonitor.swift     # NSWorkspace + Accessibility polling
│   ├── SessionEngine.swift       # Categorization + grouping logic
│   ├── CalendarWriter.swift      # EventKit integration
│   └── IdleDetector.swift        # CGEventSource idle detection
├── Views/
│   ├── MenuBarView.swift         # Main dropdown view
│   ├── CurrentSessionView.swift  # Current session card
│   └── DailySummaryView.swift    # Today's category breakdown
├── Resources/
│   └── default-categories.json   # Default categorization rules
└── Info.plist
```

## Edge Cases

- **App not in any category:** Falls under "Other" — still tracked and written to calendar
- **Rapid app switching:** The 2-minute merge threshold absorbs quick switches (Cmd+Tab to check something)
- **Sleep/wake:** `NSWorkspace` sleep/wake notifications finalize the current session on sleep, resume monitoring on wake
- **Calendar deleted:** On each write, verify the "Time Tracker" calendar exists; recreate if missing
- **First launch:** Request permissions, create calendar, write default config, show onboarding tip in dropdown

## Non-Goals

- No analytics dashboard (the calendar is your dashboard)
- No sync or cloud features
- No browser tab tracking (just the app-level URL/title from accessibility)
- No AI/LLM categorization
- No database or export

## Tech Stack

- Swift 5.9+
- SwiftUI (MenuBarExtra)
- EventKit
- Accessibility API (ApplicationServices framework)
- macOS 14+ (Sonoma) deployment target
