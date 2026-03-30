# Feedback & Awareness — Design Spec

**Date:** 2026-03-30
**Status:** Approved
**Scope:** Menu bar state reflection, in-app toast system, skeleton loading states, macOS notifications

## Problem

Loom performs critical actions silently. Sessions can stop due to idle or sleep with no visual or audible feedback. Sync failures are swallowed. Loading states show misleading "No sessions" messages. The user's primary feedback channel — the menu bar — doesn't distinguish between tracking, stopped, and error states.

## Design

### 1. Menu Bar State Reflection

The menu bar icon and text must reflect the current app state at a glance. The user's chosen icon (from Settings) is always used — only the fill variant and accompanying text change.

| State | Icon variant | Text | Behavior |
|-------|-------------|------|----------|
| Tracking | Filled (e.g. `clock.fill`) | `1:24 Coding` | Current behavior, unchanged |
| Idle stop | Outline (e.g. `clock`) | `Stopped (idle)` | Persists until user starts new session |
| Sleep stop | Outline (e.g. `clock`) | `Stopped (sleep)` | Persists until user starts new session |
| Inactive | Outline (e.g. `clock`) | No text | Current behavior, unchanged |
| Sync error | Filled + `exclamationmark.triangle` | `1:24 Coding ⚠` | Warning triangle appended; auto-clears when sync succeeds |

**Implementation notes:**
- Add a `menuBarState` enum to `AppState`: `.tracking`, `.stoppedIdle`, `.stoppedSleep`, `.inactive`
- Add a `syncError: Bool` flag that overlays the warning triangle independent of tracking state
- `updateMenuBarTitle()` reads `menuBarState` to determine icon variant and text
- `SessionEngine.handleIdle()` sets state to `.stoppedIdle`; sleep handler sets `.stoppedSleep`
- Starting a new session resets to `.tracking`; stopping resets to `.inactive`

### 2. In-App Toast System

A lightweight overlay toast component for the main window.

**Toast types:**

| Type | Color | Icon | Auto-dismiss | Action |
|------|-------|------|-------------|--------|
| Success | Green (#2e4a2e bg, #81c784 text) | Checkmark circle | 3 seconds | None |
| Info | Blue (#2e3a4a bg, #64b5f6 text) | Info circle | 3 seconds | None |
| Warning | Amber (#4a3a2e bg, #ffb74d text) | Triangle exclamation | Persistent until dismissed | Dismiss X |
| Error | Red (#4a2e2e bg, #ef5350 text) | X circle | Persistent until dismissed/resolved | Retry button |

**Behavior:**
- Position: top of main window, horizontally centered, overlaid (does not push content)
- Padding: 10px vertical, 16px horizontal; border-radius: 10px; 1px border matching type
- Max 2 visible simultaneously; newest replaces oldest if at limit
- Slide-in from top with fade; fade-out on dismiss
- z-index above all content

**Trigger mapping:**

| Event | Toast type | Message |
|-------|-----------|---------|
| Session saved (stop/finalize) | Success | "Session saved" |
| Session deleted | Success | "Session deleted" |
| Idle time logged (idle return panel) | Success | "Logged as {label}" |
| Settings updated | Info | "Settings updated" |
| Category config synced | Info | "Categories synced" |
| Session stopped (idle) | Warning | "Session stopped due to inactivity" |
| Session stopped (sleep) | Warning | "Session stopped — Mac went to sleep" |
| Sync failure | Error | "Couldn't sync — check your connection" + Retry |
| Calendar write failure | Error | "Session couldn't be saved to calendar" + Retry |

**Implementation notes:**
- New `ToastManager` observable class on `AppState`
- New `ToastOverlayView` rendered in `MainWindowView` via `.overlay(alignment: .top)`
- `ToastManager.show(_ type: ToastType, message: String, action: (() -> Void)? = nil)`
- Auto-dismiss uses `Task.sleep` with cancellation on manual dismiss
- Each toast has a unique ID for animation identity

### 3. Skeleton Loading States

When Sessions or Calendar tabs are fetching data from CloudKit, show pulsing placeholder shapes instead of "No sessions".

**Design:**
- 3 placeholder session cards: rounded rectangles matching `SessionCardView` dimensions
- Pulsing opacity animation: 0.3 → 0.6, 1.5s duration, ease-in-out, repeating
- Fill color: `Theme.trackFill`
- Each placeholder card: full-width, 60px height, 10px corner radius, 8px gap between cards
- Replace with real content once fetch completes
- If fetch completes with 0 results, show actual "No sessions" empty state

**Implementation notes:**
- New `SkeletonLoadingView` component (reusable)
- Add `isLoading: Bool` state to `SessionsTabView` and `CalendarTabView`
- Set `isLoading = true` before `await syncEngine.fetchSessions()`; `false` after
- Guard: if `isLoading`, show skeleton; else show content or empty state

### 4. macOS Notifications

Extend `ReminderManager` with methods for each notification type. All use the existing `UNUserNotificationCenter` infrastructure.

| Event | Title | Body | Sound | Category |
|-------|-------|------|-------|----------|
| Idle stop | "Session stopped" | "Your {category} session was stopped due to inactivity" | Default | SESSION_REMINDER |
| Sleep stop | "Session stopped" | "Your {category} session was stopped — Mac went to sleep" | Default | SESSION_REMINDER |
| Calendar write failed | "Session not saved" | "Couldn't save your session to calendar" | Default | SESSION_REMINDER |
| Sync failure | "Sync issue" | "Couldn't sync your session — check your connection" | None (silent) | SESSION_REMINDER |
| Remote session started | "Tracking from another device" | "A {category} session started from iPhone — now tracking on Mac" | None (silent) | SESSION_REMINDER |

**Implementation notes:**
- `notifySessionStoppedDueToIdle(category:)` already exists (built earlier this session)
- Add: `notifySessionStoppedDueToSleep(category:)`, `notifyCalendarWriteFailed()`, `notifySyncFailed()`, `notifyRemoteSessionStarted(category:)`
- Wire sleep notification in `setupSleepWakeHandlers`
- Wire calendar failure in `CalendarWriter.createEvent`/`finalizeEvent` catch blocks (pass callback or use NotificationCenter)
- Wire sync failure in `SyncEngine` catch blocks
- Wire remote session in `checkRemoteSession()` when starting a remote session locally

### 5. Already Shipped

These changes were made earlier in this session and are already committed:

- Idle stop macOS notification (`ReminderManager.notifySessionStoppedDueToIdle`)
- Fixed `ActivityMonitor.idleStartTime` timing bug (backdated to actual idle start)
- Disabled global hotkey (Option+Shift+T)

## Files to Modify

| File | Changes |
|------|---------|
| `Loom/LoomApp.swift` | Add `menuBarState` enum, wire toast triggers, wire sleep/remote notifications |
| `Loom/Services/ReminderManager.swift` | Add 4 new notification methods |
| `Loom/Services/CalendarWriter.swift` | Add failure callback/notification on write errors |
| `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift` | Add sync failure callback/notification |
| `Loom/Views/Window/MainWindowView.swift` | Add toast overlay |
| `Loom/Views/Window/SessionsTabView.swift` | Add loading state + skeleton |
| `Loom/Views/Window/CalendarTabView.swift` | Add loading state + skeleton |
| **New:** `Loom/Services/ToastManager.swift` | Toast state management |
| **New:** `Loom/Views/ToastOverlayView.swift` | Toast UI component |
| **New:** `Loom/Views/SkeletonLoadingView.swift` | Reusable skeleton placeholder |

## Out of Scope

- Standardized empty/error state components (deferred to Visual Polish phase)
- Accessibility labels and keyboard navigation (deferred to Visual Polish phase)
- Notification preferences/toggles per type (use existing notification authorization)
- Sound customization
