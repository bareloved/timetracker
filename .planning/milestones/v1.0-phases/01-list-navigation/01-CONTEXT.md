# Phase 1: List & Navigation - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Sessions tab with week/day navigation, session card list, inline app usage expansion, and live today merge. This phase delivers a read-only browsable view — edit/delete is Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Row Layout
- **D-01:** Card-style session rows — each session is a rounded card with category name, intention, time range, and duration
- **D-02:** Left color strip — thin vertical bar on the card's left edge using the category color (like Google Calendar events)
- **D-03:** Card layout: top line = category name + duration (right-aligned), middle = intention, bottom = time range

### App Detail View
- **D-04:** Per-app duration tracking — extend the Session model to track time spent per app, not just app names. This requires changes to `Session.appsUsed` (from `[String]` to a richer structure) and `SessionEngine` to accumulate per-app durations.
- **D-05:** Expanded detail shows each app with its duration (e.g., "Xcode — 45m")

### Empty & Edge States
- **D-06:** Empty day state — minimal centered "No sessions" text, no illustrations or hints
- **D-07:** Sessions with no intention — show muted placeholder text (e.g., "No intention")

### Architecture (from research/STATE.md)
- **D-08:** Use `ScrollView + ForEach` instead of native `List` — avoids confirmed DisclosureGroup animation bounce on macOS
- **D-09:** Expansion state as `@State private var expandedSessionId: UUID?` — accordion pattern, one row expanded at a time
- **D-10:** Reset `expandedSessionId` to nil on `onChange(of: selectedDate)`

### Claude's Discretion
- Expanded app detail visual treatment (simple list vs mini bars vs other) — Claude picks based on the design system and available space
- Tab icon choice for the Sessions tab
- Tab placement in the tab bar order

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Navigation Pattern
- `Loom/Views/Window/CalendarTabView.swift` — Reference implementation for week navigation, `loadWeekSessions`, live today merge, edit/delete handlers
- `Loom/Views/Window/WeekStripView.swift` — Reusable week strip component (week nav + day selection)

### Session Model
- `LoomKit/Sources/LoomKit/Models/Session.swift` — Session struct, `appsUsed: [String]` needs extension to per-app duration
- `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift` — CloudKit field mapping for sessions

### Tab Registration
- `Loom/Views/Window/MainWindowView.swift` — `AppTab` enum and tab bar wiring

### Edit Sheet (Phase 2 reference, but read for context)
- `Loom/Views/Window/BackfillSheetView.swift` — Session edit form (reused in Phase 2)

### Design System
- `.design-engineer/system.md` — Warm/matte/earthy aesthetic, terracotta accent, spacing and color tokens

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WeekStripView` — Complete week navigation component, directly reusable with zero changes
- `CalendarTabView.selectedDaySessions` — Computed property pattern for merging CloudKit data with live today data
- `CalendarTabView.loadWeekSessions()` — Async loading pattern using `syncEngine.fetchSessions(from:to:)`
- `BackfillSheetView` — Session edit form (Phase 2, but informs data flow design)
- Category colors via `CategoryColors` — Maps category names to SwiftUI `Color` values

### Established Patterns
- `@Observable` classes with `@MainActor` isolation for state management
- `syncEngine.fetchSessions(from:to:)` as canonical data source (not CalendarReader)
- `.task` modifier for async data loading on view appear
- `.onChange(of: selectedDate)` to trigger data reloads
- `sessionEngine.todaySessions` + `sessionEngine.currentSession` for live today data

### Integration Points
- `AppTab` enum in `MainWindowView.swift` — add `.sessions` case
- `MainWindowView` body — add `SessionsTabView` in the tab switch
- `AppState` in `LoomApp.swift` — passes `sessionEngine`, `syncEngine`, `categories` to tab views

</code_context>

<specifics>
## Specific Ideas

- Card style with left color strip chosen explicitly as the row layout — user wants it to feel like distinct session entries, not a flat list
- Per-app duration was chosen over name-only — the user wants the detail view to show meaningful time data per app

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-list-navigation*
*Context gathered: 2026-03-27*
