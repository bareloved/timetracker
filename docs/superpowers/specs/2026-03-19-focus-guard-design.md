# Focus Guard — Anti-Interruption System

**Date:** 2026-03-19
**Status:** Approved

## Overview

When a tracked session is active, the Focus Guard monitors the frontmost app every 5 seconds. If the user stays on an app or website that doesn't belong to the current session's category for longer than a configurable threshold (default 30s), a borderless popup appears nudging them back to work. Each distraction is logged for later review.

## Behavior

1. **Only active during tracked sessions** — needs a category to determine what's "off-task"
2. **Uses existing category rules** — `CategoryConfig.resolve(bundleId, pageURL)` determines whether the current app matches the session's category
3. **Countdown starts on drift** — when the user opens an off-category app, a timer starts
4. **Popup fires at threshold** — if the user stays off-category for the configured duration, the popup appears
5. **Auto-dismiss** — if the user switches back to an on-category app before interacting with the popup, it dismisses automatically
6. **Countdown resets on dismiss** — if the user dismisses with "Back to Work", the timer resets and will fire again if they drift again
7. **Snooze pauses the guard** — suppresses the popup for the configured snooze duration (default 5 min)
8. **Distraction logged** — every off-category episode is recorded

## FocusGuard Service

New `@Observable @MainActor` class in `TimeTracker/Services/FocusGuard.swift`.

### State

| Property | Type | Description |
|----------|------|-------------|
| `offCategoryStart` | `Date?` | When the user first drifted off-category |
| `snoozedUntil` | `Date?` | Snooze expiry time |
| `distractions` | `[Distraction]` | Log of off-category episodes for current session |
| `threshold` | `TimeInterval` | Seconds before popup fires (default 30, stored in `@AppStorage`) |
| `snoozeDuration` | `TimeInterval` | Snooze length in seconds (default 300, stored in `@AppStorage`) |
| `isEnabled` | `Bool` | Master toggle (stored in `@AppStorage`) |

### Distraction Model

```swift
struct Distraction {
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
2. Resolve the record's category via `CategoryConfig.resolve(bundleId, pageURL)`
3. If resolved category matches session category → reset `offCategoryStart`, return
4. If doesn't match and `offCategoryStart` is nil → set it to now, record the app info
5. If doesn't match and elapsed time ≥ threshold → show popup, log distraction

### Reset

When a session starts or stops, `FocusGuard` resets its state (clear timer, clear distractions for new session, clear snooze).

## Focus Popup

### Appearance

- **Borderless floating panel** — no title bar, no traffic light buttons
- Appears front and center over other apps
- Follows the app's design system (warm/matte/earthy, terracotta accent)

### Content

- The off-task app/website name that triggered it
- How long the user has been off-task (e.g., "You've been off-task for 30 seconds")
- **"Back to Work" button** — dismisses the popup, resets the countdown
- **"Snooze (5 min)" button** — dismisses and suppresses the guard for the configured duration (label reflects chosen snooze duration)

### Controller

New `FocusPopupController` using `NSPanel` (similar pattern to `IdleReturnPanelController`), with `NSPanel.StyleMask` configured for borderless appearance. Callbacks: `onDismiss()`, `onSnooze()`.

## Distraction Logging

Each distraction is stored in the `FocusGuard`'s `distractions` array for the current session. When the session ends, distractions are attached to the session data.

**Display:** A simple "X distractions" count on the session summary in the Today tab. Richer stats views can be added later.

## Settings

Three new controls in the Settings tab under a "Focus Guard" section:

| Setting | Control | Range | Default |
|---------|---------|-------|---------|
| Focus Guard | Toggle | on/off | on |
| Distraction threshold | Slider | 15s–120s | 30s |
| Snooze duration | Segmented picker | 2 / 5 / 10 / 20 min | 5 min |

All persisted via `@AppStorage`.

## Wiring (AppState)

In `AppState.setup()`:

1. Create `FocusGuard` instance, pass it the `CategoryConfigLoader` reference
2. In the existing `activityMonitor.onActivity` callback, add a call to `focusGuard.evaluate(record)` alongside the existing `sessionEngine.process(record)`
3. `FocusGuard` reads the current session category from `SessionEngine.currentSession`
4. When the popup fires, `FocusGuard` instantiates `FocusPopupController` and shows the panel

## Files to Create

- `TimeTracker/Services/FocusGuard.swift` — service
- `TimeTracker/Models/Distraction.swift` — model
- `TimeTracker/Views/FocusPopupView.swift` — SwiftUI view
- `TimeTracker/Views/FocusPopupController.swift` — NSPanel controller

## Files to Modify

- `TimeTracker/TimeTrackerApp.swift` — wire FocusGuard in AppState.setup()
- `TimeTracker/Views/Window/SettingsTabView.swift` — add Focus Guard settings section
- `TimeTracker/Views/Window/TodayTabView.swift` — show distraction count on session summary
