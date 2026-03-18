# Manual Session Tracking

**Date:** 2026-03-18
**Status:** Final

## Problem

The current auto-detection system is unreliable and confusing. It uses tentative category switching, buffering, interruption absorption, and threshold logic to decide what to write to the calendar. The result: sessions don't reflect what the user actually did, short switches are lost or misclassified, and the system is fragile.

## Design

Replace automatic category detection with explicit, user-triggered sessions. The user picks a category, optionally types an intention, and starts a timer. Apps are tracked passively in the background for self-analysis.

### Session Lifecycle

1. User opens session picker (launch popup or menu bar)
2. Picks category from list (populated from categories.json)
3. Optionally types intention
4. Presses Start → timer starts, calendar event created immediately
5. Event end time updates every 30 seconds while session is active
6. User presses Stop → session finalized, event end time set

Every explicit session gets a calendar event. No buffering, no thresholds, no filtering. Starting a new session while one is active implicitly stops the current session first.

### App Monitoring (Passive)

ActivityMonitor continues polling the frontmost app every 5 seconds. It only does one thing: append the app name to the current session's `appsUsed` list. No category resolution. No session switching. No tentative thresholds. Just a list of apps touched during the session.

### Idle Handling

When no activity is detected for 5 minutes:
- The current session is finalized at the time idle began
- Timer pauses

When the user returns:
- Idle return popup appears: "You were away for X minutes. What were you doing?"
- Options: Meeting / Break / Away / Custom / Skip
- Selecting a label creates a calendar event for the idle period
- Skip discards the idle time
- After the popup, the user can start a new session from the menu bar

### Launch Popup

On app launch, a popup appears with:
- Category picker (list of categories from categories.json)
- Intention text field (optional)
- Start button

Same popup is accessible from the menu bar "Start Session" button to start new sessions mid-day.

### Menu Bar

When session is active:
- Timer display (hours:minutes:seconds)
- Category name + intention
- Apps used (icons)
- Stop button
- "What are you working on?" editable intention field

When no session is active:
- "No active session"
- Start Session button (opens session picker popup)

### Calendar Event Format

**Title:** `Category — Intention` or just `Category` if no intention set.

**Location:** Primary app (first app used).

**Notes** (human-readable):
```
Building auth flow

Apps: Xcode, iTerm2, Safari, Finder
```

Intention line omitted if not set. No interruptions section. No JSON.

### SessionEngine Changes

SessionEngine becomes dramatically simpler:
- `startSession(category:intention:)` — creates session with given category, creates calendar event
- `stopSession()` — finalizes current session
- `updateIntention(_:)` — updates intention mid-session
- `process(_:)` — only appends app name to current session's appsUsed list. No category resolution, no tentative switching, no session creation/finalization.
- `handleIdle(at:)` — finalizes current session at idle time

**Removed from SessionEngine:**
- `tentativeCategory`, `tentativeSwitchTime` — no auto-switching
- `shortSwitchThreshold`, `resumeThreshold` — no thresholds
- Category resolution logic in `process()`
- Session resume logic (resuming finalized sessions of same category)
- Automatic session creation in `startNewSession()`

### CalendarWriter Changes

CalendarWriter returns to simple create/update/finalize:
- `createEvent(for:)` — creates EKEvent immediately
- `updateCurrentEvent(session:)` — updates end time, title, notes, location
- `finalizeEvent(for:)` — sets final end time, saves
- `createEventImmediately(for:)` — kept for idle events

**Removed from CalendarWriter:**
- `sessionBuffer`, `trackingStartTime`, `isLive` — no buffering
- `pendingInterruptions`, `activeInterruptions` — no interruptions
- `lastFinalizedEventIdentifier` — no deferred attachment
- `flushBuffer()`, `resetTracking()` — no threshold system
- `thresholdTimer`, `startThresholdTimer()`, `stopThresholdTimer()` — no threshold timer
- `writeThreshold` AppStorage — no minimum session length setting
- `createEventLive()`, `writeEventToCalendar()` — consolidated back into `createEvent`

### Settings Changes

**Removed:**
- "Minimum Session Length" picker

**Kept:**
- Calendar sync toggle, calendar name, account picker
- Time rounding picker
- Category configuration (for future use + populating picker)
- Appearance, menu bar icon, goal tracking
- All other existing settings

### CategoryConfig

Kept as-is. categories.json continues to define categories with apps, related apps, and URL patterns. Used to populate the category picker. The app-to-category mapping data is preserved for a future feature.

### Edge Cases

- **Starting new session while one is active:** Implicitly calls `stopSession()` then `startSession(category:intention:)`.
- **App termination while session is active:** Existing `setupTerminationHandler` calls `stopSession()` — preserved.
- **Sleep/wake while session is active:** Sleep pauses the timer (same as idle). Wake triggers idle return panel if away for 5+ minutes. Session is finalized at the time the machine slept. This matches idle behavior — in a manual-session world, the user can immediately start a new session after wake if they want to continue.
- **Config save mid-session:** `AppState.saveConfig` rebuilds the engine. Must preserve current session's category and intention when re-creating.

### What Gets Removed

- `Interruption` model
- Buffering/flush/threshold state machine in CalendarWriter
- Category resolution and tentative switch logic in SessionEngine
- Session resume logic in SessionEngine
- "Minimum Session Length" setting in SettingsTabView

### What Gets Modified

- **SessionEngine** — simplified to manual start/stop + passive app logging
- **CalendarWriter** — simplified to direct create/update/finalize
- **LaunchPopupController / LaunchPopupView** — add category picker
- **MenuBarView** — Start button opens session picker popup instead of auto-starting
- **AppState** — `startTracking` takes category + intention, simplified wiring
- **IdleReturnPanel** — unchanged (already works correctly)
- **ActivityMonitor** — unchanged (still polls every 5s, callbacks simplified)

## Data Flow

```
User picks category + intention → Start
  → SessionEngine.startSession(category:intention:)
  → CalendarWriter.createEvent(for:)
  → ActivityMonitor.start()

Every 5s:
  → ActivityMonitor fires onActivity
  → SessionEngine.process(record) — just adds app to session.appsUsed
  → CalendarWriter.updateCurrentEvent(session:)

Every 30s:
  → CalendarWriter update timer ticks
  → Updates event endDate to Date()

User presses Stop:
  → SessionEngine.stopSession()
  → CalendarWriter.finalizeEvent(for:)
  → ActivityMonitor.stop()

Idle detected (5 min no activity):
  → SessionEngine.handleIdle(at:) — finalizes session at idle start time
  → ActivityMonitor pauses

User returns from idle:
  → IdleReturnPanel shows
  → User labels idle time (or skips)
  → User starts new session from menu bar
```
