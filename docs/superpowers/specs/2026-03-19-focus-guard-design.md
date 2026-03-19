# Focus Guard — Anti-Interruption System

**Date:** 2026-03-19
**Status:** Approved

## Overview

When a tracked session is active, the Focus Guard monitors the frontmost app every 5 seconds. If the user stays on an app or website that doesn't belong to the current session's category for longer than a configurable threshold (default 30s), a borderless popup appears nudging them back to work. Each distraction is logged for later review.

## Behavior

1. **Only active during tracked sessions** — needs a category to determine what's "off-task"
2. **Uses existing category rules** — `CategoryConfig.resolve(bundleId:currentCategory:pageURL:)` determines whether the current app matches the session's category. The session's category is passed as `currentCategory` so that "related" apps resolve correctly.
3. **Countdown starts on drift** — when the user opens an off-category app, a timer starts
4. **Popup fires at threshold** — if the user stays off-category for the configured duration, the popup appears
5. **Auto-dismiss** — if the user switches back to an on-category app before interacting with the popup, it dismisses automatically. Since polling is every 5s, there may be up to a 5-second delay before auto-dismiss.
6. **Countdown resets on dismiss** — if the user dismisses with "Back to Work", the timer resets and will fire again if they drift again
7. **Snooze pauses the guard** — suppresses the popup for the configured snooze duration (default 5 min)
8. **Distraction logged** — every off-category episode is recorded
9. **Loom is exempt** — Loom's own bundle ID is always treated as on-category so opening Settings or the main window doesn't trigger the guard

## Edge Cases

- **Idle detection:** When `SessionEngine.handleIdle()` ends the session, FocusGuard resets and any visible popup is dismissed.
- **Sleep/wake:** FocusGuard resets `offCategoryStart` on wake to avoid stale timers from before sleep.
- **Category change mid-session:** If the user changes the session's category via the UI, the next `evaluate()` call uses the new category. If the popup is currently showing, it is dismissed since the context has changed.
- **Double-fire from ActivityMonitor:** `ActivityMonitor` fires `onActivity` twice per poll — once immediately (without pageURL) and once after the background AX fetch (with pageURL). FocusGuard only starts the drift timer on records where `pageURL` is populated (for browser apps). For non-browser apps, both fires resolve the same way so double evaluation is harmless.

## FocusGuard Service

New `@Observable @MainActor` class in `TimeTracker/Services/FocusGuard.swift`.

### State

| Property | Type | Description |
|----------|------|-------------|
| `offCategoryStart` | `Date?` | When the user first drifted off-category |
| `offCategoryAppName` | `String?` | The app that triggered the drift |
| `offCategoryURL` | `String?` | The URL if it was a browser |
| `snoozedUntil` | `Date?` | Snooze expiry time |
| `distractions` | `[Distraction]` | Log of off-category episodes for current session |
| `focusThreshold` | `TimeInterval` | Seconds before popup fires (default 30, stored in `@AppStorage`) |
| `snoozeDuration` | `TimeInterval` | Snooze length in seconds (default 300, stored in `@AppStorage`) |
| `isEnabled` | `Bool` | Master toggle (stored in `@AppStorage`) |

### Distraction Model

New file `TimeTracker/Models/Distraction.swift`:

```swift
struct Distraction: Identifiable, Equatable {
    let id: UUID
    let appName: String
    let bundleId: String
    let url: String?        // if browser
    let startTime: Date
    var duration: TimeInterval
    var snoozed: Bool
}
```

### Core Method: `evaluate(_ record: ActivityRecord)`

Called from `AppState` on every `ActivityMonitor.onActivity` callback (every 5s):

1. Guard: return if not enabled, currently snoozed, or no active session
2. Guard: return if record's bundleId is Loom's own bundle ID
3. For browser apps: if `record.pageURL` is nil, return (wait for the second callback with URL data)
4. Resolve the record's category via `CategoryConfig.resolve(bundleId:currentCategory:pageURL:)`, passing the session's category as `currentCategory`
5. If resolved category matches session category → reset `offCategoryStart`, auto-dismiss popup if showing, return
6. If doesn't match and `offCategoryStart` is nil → set it to now, record the app name/URL
7. If doesn't match and elapsed time ≥ `focusThreshold` → show popup, log distraction

### Reset

When a session starts or stops, FocusGuard resets its state: clears `offCategoryStart`, clears distractions for new session, clears snooze, dismisses any visible popup.

## Focus Popup

### Appearance

- **Borderless floating panel** — `NSPanel` with `styleMask: [.nonactivatingPanel, .borderless]`, plus manual rounded corners and background rendering via the SwiftUI content view
- Appears front and center over other apps (`panel.level = .floating`)
- Follows the app's design system (warm/matte/earthy, terracotta accent)

### Content

- The off-task app/website name that triggered it
- How long the user has been off-task (e.g., "You've been off-task for 30 seconds")
- **"Back to Work" button** — dismisses the popup, resets the countdown
- **"Snooze (5 min)" button** — dismisses and suppresses the guard for the configured duration (label reflects chosen snooze duration)

### Controller

New `FocusPopupController` using `NSPanel` (same hosting pattern as `IdleReturnPanelController`). Callbacks: `onDismiss()`, `onSnooze()`.

## Distraction Logging

Distractions are stored in the `FocusGuard`'s `distractions` array for the current session. The TodayTabView reads distractions directly from `FocusGuard` (no need to modify the `Session` model). When a new session starts, the previous session's distractions are cleared.

**Display:** A simple "X distractions" count on the session summary in the Today tab. Richer stats views can be added later.

## Settings

Three new controls in the Settings tab. Add a new `SettingsSection.focusGuard` case with its own sidebar entry and icon:

| Setting | Control | Range | Default |
|---------|---------|-------|---------|
| Focus Guard | Toggle | on/off | on |
| Distraction threshold | Slider | 15s–120s | 30s |
| Snooze duration | Segmented picker | 2 / 5 / 10 / 20 min | 5 min |

All persisted via `@AppStorage`.

## Wiring (AppState)

In `AppState.setup()`:

1. Create `FocusGuard` instance, pass it the `CategoryConfigLoader` reference and a reference to `SessionEngine`
2. In the existing `activityMonitor.onActivity` callback, add a call to `focusGuard.evaluate(record)` alongside the existing `sessionEngine.process(record)`
3. `FocusGuard` reads the current session category from `SessionEngine.currentSession`
4. Wire sleep/wake notifications to reset `offCategoryStart` on wake
5. When the popup fires, `FocusGuard` uses `FocusPopupController` to show the panel

## Files to Create

- `TimeTracker/Services/FocusGuard.swift` — service
- `TimeTracker/Models/Distraction.swift` — model
- `TimeTracker/Views/FocusPopupView.swift` — SwiftUI view
- `TimeTracker/Views/FocusPopupController.swift` — NSPanel controller

## Files to Modify

- `TimeTracker/TimeTrackerApp.swift` — wire FocusGuard in AppState.setup(), add sleep/wake hooks
- `TimeTracker/Views/Window/SettingsTabView.swift` — add FocusGuard settings section and sidebar entry
- `TimeTracker/Views/Window/TodayTabView.swift` — show distraction count on session summary
