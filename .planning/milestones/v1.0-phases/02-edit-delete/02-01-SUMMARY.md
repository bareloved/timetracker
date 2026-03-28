---
phase: 02-edit-delete
plan: 01
subsystem: ui
tags: [swiftui, cloudkit, sessions, edit, delete, context-menu]

# Dependency graph
requires:
  - phase: 01-sessions-tab
    provides: SessionCardView and SessionsTabView built in Phase 1
provides:
  - Context menu (right-click) Edit and Delete on session cards
  - Double-click to open BackfillSheetView for editing
  - Inline delete confirmation UI on the card
  - CloudKit persistence for edits and deletes from Sessions tab
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ".contextMenu for macOS right-click menus on SwiftUI views"
    - "Inline state toggle (showDeleteConfirmation) to transform card UI without modals"
    - ".onTapGesture(count: 2) for double-click gesture on macOS"
    - ".sheet(item: $editingSession) for presenting edit sheet"

key-files:
  created: []
  modified:
    - Loom/Views/Window/SessionCardView.swift
    - Loom/Views/Window/SessionsTabView.swift

key-decisions:
  - "onDelete closure left as no-op on card — delete confirmation is inline card state, not a parent-driven action"
  - "Ported saveEditedSession and deleteSession exactly from CalendarTabView for consistency"

patterns-established:
  - "Inline card confirmation: @State showDeleteConfirmation toggles card content in-place, no modal"
  - "Edit callbacks: onEdit fires for both double-click and context menu Edit item"
  - "Closure pattern: SessionCardView receives onEdit/onDelete/onConfirmDelete from parent, keeps card stateless for data"

requirements-completed: [EDIT-01, EDIT-02, EDIT-03, DEL-01, DEL-02]

# Metrics
duration: 4min
completed: 2026-03-27
---

# Phase 2 Plan 01: Edit & Delete Session Cards Summary

**Right-click context menu and double-click on session cards open BackfillSheetView for editing; context menu Delete shows inline card confirmation; both mutations persist to CloudKit via SyncEngine**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-27T20:50:00Z
- **Completed:** 2026-03-27T20:54:21Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- SessionCardView gains `.contextMenu` with Edit/Delete items and `.onTapGesture(count: 2)` for double-click edit
- Inline delete confirmation transforms the card in-place using `@State showDeleteConfirmation` — no modal
- SessionsTabView wires `editingSession` state, `.sheet(item:)` with BackfillSheetView, `saveEditedSession`, and `deleteSession` methods

## Task Commits

1. **Task 1: Add context menu, double-click, and inline delete confirmation to SessionCardView** - `4b67f6f` (feat)
2. **Task 2: Wire edit/delete state, BackfillSheetView sheet, and CloudKit methods into SessionsTabView** - `b522de6` (feat)

## Files Created/Modified

- `Loom/Views/Window/SessionCardView.swift` - Added onEdit/onDelete/onConfirmDelete closures, showDeleteConfirmation state, double-click gesture, context menu, inline delete confirmation UI
- `Loom/Views/Window/SessionsTabView.swift` - Added editingSession state, wired SessionCardView callbacks, added .sheet for BackfillSheetView, saveEditedSession and deleteSession methods

## Decisions Made

- `onDelete` closure on SessionCardView is a no-op because the card handles delete confirmation internally with `showDeleteConfirmation` state; only `onConfirmDelete` triggers the actual deletion in the parent
- Ported `saveEditedSession` and `deleteSession` verbatim from CalendarTabView to maintain consistency across tabs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 02 complete — all 5 requirements addressed (EDIT-01, EDIT-02, EDIT-03, DEL-01, DEL-02)
- Sessions tab now has full CRUD capability matching the Calendar tab
- No blockers for milestone completion

---
*Phase: 02-edit-delete*
*Completed: 2026-03-27*
