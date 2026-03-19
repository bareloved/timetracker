# Edit Session — Design Spec

## Overview
Allow users to select and edit existing sessions in the Calendar tab's timeline view. Single click highlights a session, double click opens an edit sheet.

## Interaction

### Selection (Single Click)
- Single click on a session block highlights it with a subtle border/outline in the category color
- Clicking another session moves the highlight
- Clicking empty space deselects

### Edit (Double Click)
- Double click on a session block opens the edit sheet
- Edit sheet is a modal `.sheet` on CalendarTabView

## Edit Sheet

Reuse `BackfillSheetView` layout, extended for edit mode:

- **Title**: "Edit Session"
- **Fields**: Category picker, start DatePicker, end DatePicker, intention TextField — all pre-populated
- **Actions**: "Cancel" and "Save Changes" buttons
- **Delete**: Red "Delete Session" button at bottom. First tap shows confirmation row: "Are you sure?" with "Cancel" / "Delete" buttons

## Data Flow

### Model Change
Add `eventIdentifier: String?` to `Session` struct. Default `nil`, populated when read from calendar.

### CalendarReader
`sessionFromEvent(_:)` stores `event.eventIdentifier` into `Session.eventIdentifier`.

### CalendarWriter — New Methods
- `updateEvent(eventIdentifier: String, session: Session)` — Fetches EKEvent by identifier, updates startDate, endDate, title (via `buildTitle`), notes (via `buildHumanNotes`), location (category), saves with `.thisEvent` span.
- `deleteEvent(eventIdentifier: String)` — Fetches EKEvent by identifier, removes with `.thisEvent` span.

### Refresh
After edit or delete, `CalendarTabView` calls `loadWeekSessions()` to refresh data.

## View Changes

### VerticalTimelineView
- New properties: `selectedSessionId: Binding<String?>`, `onSessionDoubleClick: (Session) -> Void` callback
- `sessionBlock`: adds `.onTapGesture(count: 2)` for edit, `.onTapGesture(count: 1)` for select
- Selected state: 2px border in category color with slight background brightness boost

### CalendarTabView
- New `@State var selectedSessionId: String?`
- New `@State var editingSession: Session?`
- Presents edit sheet when `editingSession` is set
- On save: calls `CalendarWriter.updateEvent()`, then `loadWeekSessions()`
- On delete: calls `CalendarWriter.deleteEvent()`, then `loadWeekSessions()`

### BackfillSheetView (Extended)
- New optional `editingSession: Session?` parameter
- When set: pre-populates fields, changes title to "Edit Session", button to "Save Changes"
- Adds `onDelete: ((Session) -> Void)?` callback, shown only in edit mode
- Delete button with two-stage confirmation

## Files Modified
1. `TimeTracker/Models/Session.swift` — add `eventIdentifier`
2. `TimeTracker/Services/CalendarReader.swift` — preserve event ID
3. `TimeTracker/Services/CalendarWriter.swift` — `updateEvent`, `deleteEvent`
4. `TimeTracker/Views/Window/VerticalTimelineView.swift` — selection + double-click
5. `TimeTracker/Views/Window/CalendarTabView.swift` — edit state + sheet wiring
6. `TimeTracker/Views/Window/BackfillSheetView.swift` — edit mode + delete
