# App Window Design

## Overview

Add a main application window to TimeTracker, inspired by the "Session" app. The app shifts from passive always-on tracking to user-initiated sessions with auto-categorization. The existing menu bar dropdown remains unchanged.

## Core Model Change

- **User-initiated sessions:** The app no longer auto-tracks on launch. Users explicitly start and stop sessions.
- **Launch popup:** On app launch, a floating panel appears ("Ready to focus?") with an intention text field and "Start Session" button. Dismissible with "Not now." Includes an animated rising-arc sunrise illustration (terracotta half-circle revealing from below a horizon line with gradient glow).
- **Start flow:** User hits Start (from launch popup, Today tab CTA, mini-player, or menu bar). Optionally types an intention/note. Session begins immediately — no category selection.
- **Auto-categorization:** While a session is active, the app polls the frontmost app every 5s (existing behavior) and detects browser tabs (new). Category is auto-assigned and updated in real-time based on activity.
- **Stop flow:** User hits Stop. Session finalizes and writes to Apple Calendar.
- **Idle handling:** Unchanged — 5+ min idle pauses session, idle return panel asks what user was doing.
- **SessionEngine changes:** Waits for explicit `startSession(intention:)` call instead of auto-starting. ActivityMonitor only polls while a session is active.

## Session & Category Model

A user-initiated session is a **container** that may span multiple categories. Internally, the existing category-based session splitting continues — when the user switches from Coding to Email, the engine creates a new internal `Session`. All internal sessions between Start and Stop share the same `intention` and belong to the same user-initiated "tracking span."

```swift
struct Session {
    let id: UUID
    var category: String        // CHANGED: var, updated by auto-categorization
    let startTime: Date
    var endTime: Date?
    var appsUsed: [String]
    var intention: String?      // NEW: user-provided note
    var trackingSpanId: UUID?   // NEW: groups sessions within one Start→Stop span
}
```

Category auto-switching still creates new `Session` objects (preserving existing behavior). The `trackingSpanId` links them so the Stats "By Intention" view can aggregate correctly.

### ActivityRecord Update

```swift
struct ActivityRecord {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let pageURL: String?        // NEW: browser tab URL (nil for non-browsers)
    let timestamp: Date
}
```

### CategoryRule Update

```swift
struct CategoryRule: Codable {
    var apps: [String]
    var related: [String]?
    var urlPatterns: [String]?   // NEW: e.g. ["github.com", "stackoverflow.com"]
}
```

URL patterns are checked when the frontmost app is a browser. If the page URL or window title matches a pattern, that category is used.

## Calendar Event Storage

Sessions are written to Apple Calendar as `EKEvent` objects:

- **Title:** Category name (existing)
- **Location:** Primary app (existing)
- **Notes:** JSON with structured data: `{"apps": [...], "intention": "...", "spanId": "..."}`
- **Start/End:** Session start and end times (existing)

This replaces the current plain-text notes format. The JSON notes field allows the Calendar and Stats tabs to reconstruct full session data including intentions and tracking spans.

### Reading Historical Data

A new `CalendarReader` service fetches `EKEvent` objects from the "Time Tracker" calendar for a given date range and maps them back to displayable session objects. This powers the Calendar tab timeline and Stats tab aggregations.

## Window Structure

- **Size:** ~500px wide x ~700px tall, resizable
- **Navigation:** Bottom tab bar with 4 tabs — icon + label, terracotta highlight on active tab
- **Tabs:** Today, Calendar, Stats, Settings
- **Mini-player bar:** Persistent above the tab bar on every tab
- **Window behavior:** Standard macOS window. App switches to `.regular` activation policy when window is open (shows in Dock), switches back to `.accessory` when window is closed (Dock icon disappears, menu bar only). Cmd+W closes window, Cmd+Q quits app. Openable from menu bar dropdown via a button.

## Tab 1: Today

### Idle State (no active session)

- Centered CTA: "What are you working on?"
- Intention text field (placeholder: "Intention (optional)")
- Prominent "START SESSION" button (terracotta)
- Below: "Earlier today" section with timeline bar of completed sessions
- Below: Daily summary (category breakdown with durations)

### Active State

- **Hero timer:** Large centered timer (40pt bold, tabular-nums), live-updating
- **Session info:** Auto-detected category dot + name, intention text (italic)
- **Apps used:** App icons + names from current session
- **Timeline bar:** Today's sessions as colored blocks (expanded version of existing TimelineBarView)
- **Activity pulse:** 15-min slot bars showing activity intensity (existing ActivityPulseView)
- **Daily summary:** Category breakdown with progress bars and durations

## Tab 2: Calendar

- **Week navigation:** Left/right arrows around "Today" label
- **Week strip:** MON–SUN with dates and daily hour totals. Selected day highlighted (terracotta).
- **Overview bar:** Horizontal bar showing the full day's activity at a glance (colored segments by category)
- **Vertical day timeline:** Hours on the left, colored session blocks on the right. Each block shows category name and time range. Blocks colored by category.
- **Current time indicator:** Red line with timestamp label (when viewing today)
- **Session details:** Show category name and duration on hover/click of a block
- **Add button:** Floating "+" button (terracotta circle) in bottom-right to manually add a past session

### Manual Session Backfill

Tapping "+" opens a sheet/popover with:
- Category picker (dropdown of existing categories)
- Date picker (defaults to selected day)
- Start time and end time pickers
- Intention text field (optional)
- "Add Session" button — writes an EKEvent to the calendar with the same format as auto-tracked sessions

## Tab 3: Stats

- **Time range selector:** Today / This Week / This Month / Custom
- **Week strip:** Same as Calendar tab for context
- **Filter controls:** "Show notes only" toggle, Filter dropdown
- **Category Distribution section:** Card with table — columns: Category (with color dot + bar), Ratio %, Change (trend arrow vs previous period), Time Spent
- **By Intention section:** Card with table — columns: Intention text, Ratio %, Sessions count, Time Spent. Groups sessions by intention note. Sessions without intention shown as "(no intention)".

## Tab 4: Settings

Two-pane layout — sidebar navigation on the left, detail panel on the right.

### Sidebar Sections

- **General** — Daily streak target, intention suggestions, timer snap interval
- **Notification** — Session end alerts, idle warnings
- **Calendar** — Apple Calendar integration (which calendar, event format)
- **Category** — Manage categories, app-to-category mappings, related apps (existing category editor)
- **Window** — Window behavior (launch at login, show in dock, default tab)
- **Browser Tracking** — Enable/disable, supported browsers, URL-to-category rules

### Settings Mapping

Existing settings move to the new sidebar:
- **General:** Theme picker (light/dark/system), daily streak target, intention suggestions, timer snap interval, menu bar text toggle
- **Notification:** (new section — session end alerts, idle warnings)
- **Calendar:** Apple Calendar integration settings
- **Category:** Full category CRUD (existing category editor), focus goal config
- **Window:** Launch at login, show in dock, default tab
- **Browser Tracking:** Enable/disable, URL-to-category rules

## Mini-Player Bar

Persistent bar above the tab bar, visible on every tab.

### Active State

- Left: category color dot, category name, intention text (italic, truncated)
- Right: live timer (14pt, semibold, tabular-nums), stop button (terracotta circle with white square icon)

### Idle State

- Left: "No active session" (muted text)
- Right: "Start" button (terracotta pill)

## Launch Popup

Floating panel (similar to existing idle return panel). Appears on cold app launch only (not when opening the main window from menu bar, not when already tracking, not on login if launch-at-login is enabled).

- **Animation:** Terracotta rising-arc sunrise — half-circle sun reveals from below a horizon line with a gradient glow. Smooth ease-out animation over ~2s.
- **Title:** "Ready to focus?"
- **Subtitle:** "What are you working on?"
- **Input:** Intention text field (optional)
- **CTA:** "START SESSION" button (terracotta, full-width)
- **Dismiss:** "Not now" text link below

## Browser Tab Tracking

New capability for smarter auto-categorization.

- **Approach:** Accessibility API reads the URL bar / window title from supported browsers (Safari, Chrome, Arc, Firefox)
- **Behavior:** When frontmost app is a browser, read the active tab's title and URL (if accessible via AX) in addition to the app name
- **Category rules:** URL patterns map to categories (e.g., `github.com` → Coding, `gmail.com` → Email). Configurable in Settings > Browser Tracking.
- **Fallback:** If URL unreadable (permissions denied, unsupported browser), fall back to window title matching, then browser's default category
- **Privacy:** All local. URLs used for categorization only, not stored in calendar events.

## Menu Bar Dropdown

Updated to reflect the new start/stop model. Core layout stays the same, but behavioral changes:

- When no session is active: shows "No active session" with a Start button
- When active: shows live timer, category, apps (existing behavior)
- Adds a button to open the main window

## Design System

Uses existing design tokens from `.design-engineer/system.md`:

- Accent: terracotta (#c06040)
- Category colors: existing 7-color palette with light/dark variants
- Surfaces: cream/gray (light), charcoal/dark brown (dark)
- Spacing: 8px base unit
- Border radius: 14px (window), 10px (cards), 3px (buttons/timeline)
- Typography: system font, hero timer 40pt bold tabular-nums

## Non-Goals

- No Pomodoro/countdown timer (this is open-ended tracking)
- No sync/cloud features
- No social/team features
- No browser extension (using AX API instead)
