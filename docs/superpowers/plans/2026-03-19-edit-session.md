# Edit Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to select and edit existing sessions in the Calendar timeline via single-click highlight and double-click edit sheet.

**Architecture:** Add `eventIdentifier` to Session model so calendar-persisted sessions can be updated/deleted. Extend BackfillSheetView with edit mode. Add click handlers to VerticalTimelineView session blocks. Wire everything through CalendarTabView.

**Tech Stack:** SwiftUI, EventKit

---

### Task 1: Add `eventIdentifier` to Session model

**Files:**
- Modify: `TimeTracker/Models/Session.swift`

- [ ] **Step 1: Add property and update init**

```swift
// In Session struct, add after trackingSpanId:
var eventIdentifier: String?

// Update init signature to include it:
init(
    id: UUID = UUID(),
    category: String,
    startTime: Date,
    endTime: Date? = nil,
    appsUsed: [String],
    intention: String? = nil,
    trackingSpanId: UUID? = nil,
    eventIdentifier: String? = nil
) {
    // ... existing assignments ...
    self.eventIdentifier = eventIdentifier
}
```

- [ ] **Step 2: Build to verify no breakage**

Run: `swift build -c release 2>&1 | grep -E "error:|Build complete"`
Expected: Build complete (existing callers use defaults, so no breakage)

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Models/Session.swift
git commit -m "feat: add eventIdentifier to Session model"
```

---

### Task 2: Preserve event identifier in CalendarReader

**Files:**
- Modify: `TimeTracker/Services/CalendarReader.swift:102-115` (`sessionFromEvent`)

- [ ] **Step 1: Update sessionFromEvent to store eventIdentifier**

In `sessionFromEvent(_:)`, add `eventIdentifier: event.eventIdentifier` to the Session init call:

```swift
private func sessionFromEvent(_ event: EKEvent) -> Session? {
    guard let title = event.title, !title.isEmpty else { return nil }

    let (apps, intention, spanId) = parseNotes(event.notes)

    return Session(
        category: title,
        startTime: event.startDate,
        endTime: event.endDate,
        appsUsed: apps,
        intention: intention,
        trackingSpanId: spanId,
        eventIdentifier: event.eventIdentifier
    )
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build -c release 2>&1 | grep -E "error:|Build complete"`
Expected: Build complete

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/CalendarReader.swift
git commit -m "feat: preserve EventKit identifier when reading sessions"
```

---

### Task 3: Add updateEvent and deleteEvent to CalendarWriter

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`

- [ ] **Step 1: Add updateEvent method**

Add after `createEventImmediately(for:)` (after line 231):

```swift
func updateEvent(eventIdentifier: String, session: Session) {
    guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
        print("Failed to find event for update: \(eventIdentifier)")
        return
    }

    event.title = Self.buildTitle(session: session)
    event.startDate = session.startTime
    event.endDate = session.endTime ?? Date()
    event.notes = Self.buildHumanNotes(session: session)
    event.location = session.category

    do {
        try eventStore.save(event, span: .thisEvent)
    } catch {
        print("Failed to update event: \(error)")
    }
}
```

- [ ] **Step 2: Add deleteEvent method**

Add after `updateEvent`:

```swift
func deleteEvent(eventIdentifier: String) {
    guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
        print("Failed to find event for deletion: \(eventIdentifier)")
        return
    }

    do {
        try eventStore.remove(event, span: .thisEvent)
    } catch {
        print("Failed to delete event: \(error)")
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build -c release 2>&1 | grep -E "error:|Build complete"`
Expected: Build complete

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: add updateEvent and deleteEvent to CalendarWriter"
```

---

### Task 4: Extend BackfillSheetView with edit mode and delete

**Files:**
- Modify: `TimeTracker/Views/Window/BackfillSheetView.swift`

- [ ] **Step 1: Add edit mode properties**

Replace the current struct declaration and init with:

```swift
struct BackfillSheetView: View {
    let date: Date
    let categories: [String]
    let onAdd: (String, Date, Date, String?) -> Void
    let onCancel: () -> Void
    var editingSession: Session? = nil
    var onSave: ((Session) -> Void)? = nil
    var onDelete: ((Session) -> Void)? = nil

    @State private var selectedCategory: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intention: String = ""
    @State private var showDeleteConfirm = false

    private var isEditMode: Bool { editingSession != nil }

    init(
        date: Date,
        categories: [String],
        onAdd: @escaping (String, Date, Date, String?) -> Void,
        onCancel: @escaping () -> Void,
        editingSession: Session? = nil,
        onSave: ((Session) -> Void)? = nil,
        onDelete: ((Session) -> Void)? = nil
    ) {
        self.date = date
        self.categories = categories
        self.onAdd = onAdd
        self.onCancel = onCancel
        self.editingSession = editingSession
        self.onSave = onSave
        self.onDelete = onDelete

        if let session = editingSession {
            self._selectedCategory = State(initialValue: session.category)
            self._startTime = State(initialValue: session.startTime)
            self._endTime = State(initialValue: session.endTime ?? Date())
            self._intention = State(initialValue: session.intention ?? "")
        } else {
            let cal = Calendar.current
            let now = Date()
            let dayStart = cal.startOfDay(for: date)
            let defaultStart = cal.isDate(date, inSameDayAs: now)
                ? now.addingTimeInterval(-3600)
                : dayStart.addingTimeInterval(9 * 3600)
            let defaultEnd = cal.isDate(date, inSameDayAs: now)
                ? now
                : dayStart.addingTimeInterval(10 * 3600)
            self._selectedCategory = State(initialValue: categories.first ?? "Other")
            self._startTime = State(initialValue: defaultStart)
            self._endTime = State(initialValue: defaultEnd)
        }
    }
```

- [ ] **Step 2: Update body with edit mode UI**

Replace the body with:

```swift
var body: some View {
    VStack(spacing: 16) {
        Text(isEditMode ? "Edit Session" : "Add Session")
            .font(.headline)

        Form {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { cat in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(CategoryColors.color(for: cat))
                            .frame(width: 8, height: 8)
                        Text(cat)
                    }
                    .tag(cat)
                }
            }

            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)

            TextField("Intention (optional)", text: $intention)
        }
        .formStyle(.grouped)

        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Spacer()

            if isEditMode {
                Button("Save Changes") {
                    var updated = editingSession!
                    updated.category = selectedCategory
                    updated.endTime = endTime
                    updated.intention = intention.isEmpty ? nil : intention
                    onSave?(updated)
                }
                .buttonStyle(.borderedProminent)
                .tint(CategoryColors.accent)
                .disabled(endTime <= startTime)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Add Session") {
                    onAdd(
                        selectedCategory,
                        startTime,
                        endTime,
                        intention.isEmpty ? nil : intention
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(CategoryColors.accent)
                .disabled(endTime <= startTime)
                .keyboardShortcut(.defaultAction)
            }
        }

        // Delete section (edit mode only)
        if isEditMode, let session = editingSession {
            Divider()

            if showDeleteConfirm {
                HStack {
                    Text("Are you sure?")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Cancel") { showDeleteConfirm = false }
                        .buttonStyle(.plain)
                    Button("Delete") {
                        onDelete?(session)
                    }
                    .foregroundStyle(.red)
                }
            } else {
                Button("Delete Session") {
                    showDeleteConfirm = true
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(20)
    .frame(width: 320)
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build -c release 2>&1 | grep -E "error:|Build complete"`
Expected: Build complete

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/BackfillSheetView.swift
git commit -m "feat: extend BackfillSheetView with edit mode and delete"
```

---

### Task 5: Add selection and double-click to VerticalTimelineView

**Files:**
- Modify: `TimeTracker/Views/Window/VerticalTimelineView.swift`

- [ ] **Step 1: Add selection and callback properties**

After the `@Binding var visibleHourRange` line, add:

```swift
var selectedSessionId: Binding<String?> = .constant(nil)
var onSessionDoubleClick: ((Session) -> Void)? = nil
```

- [ ] **Step 2: Update sessionBlock to support selection highlight**

Replace the `sessionBlock` function:

```swift
@ViewBuilder
private func sessionBlock(session: Session, height: CGFloat) -> some View {
    let color = CategoryColors.color(for: session.category)
    let isSelected = selectedSessionId.wrappedValue == session.id.uuidString

    VStack(alignment: .leading, spacing: 2) {
        Text(session.category)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

        Text(timeRange(session))
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.8))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: height)
    .background(isSelected ? color.brightness(0.1) : color)
    .overlay(
        isSelected
            ? RoundedRectangle(cornerRadius: 6)
                .stroke(color.brightness(0.3), lineWidth: 2)
            : nil
    )
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .onTapGesture(count: 2) {
        onSessionDoubleClick?(session)
    }
    .onTapGesture(count: 1) {
        selectedSessionId.wrappedValue = session.id.uuidString
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build -c release 2>&1 | grep -E "error:|Build complete"`
Expected: Build complete

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/VerticalTimelineView.swift
git commit -m "feat: add selection highlight and double-click to timeline sessions"
```

---

### Task 6: Wire edit flow in CalendarTabView

**Files:**
- Modify: `TimeTracker/Views/Window/CalendarTabView.swift`

- [ ] **Step 1: Add state variables**

After `@State private var visibleHourRange`, add:

```swift
@State private var selectedSessionId: String?
@State private var editingSession: Session?
```

- [ ] **Step 2: Update VerticalTimelineView call**

Pass the new properties:

```swift
VerticalTimelineView(
    sessions: selectedDaySessions,
    isToday: calendar.isDateInToday(selectedDate),
    backgroundEvents: backgroundEvents,
    visibleHourRange: $visibleHourRange,
    selectedSessionId: $selectedSessionId,
    onSessionDoubleClick: { session in
        editingSession = session
    }
)
```

- [ ] **Step 3: Add edit sheet**

After the existing `.sheet(isPresented: $showBackfill)`, add:

```swift
.sheet(item: $editingSession) { session in
    BackfillSheetView(
        date: selectedDate,
        categories: categories,
        onAdd: { _, _, _, _ in },
        onCancel: { editingSession = nil },
        editingSession: session,
        onSave: { updated in
            saveEditedSession(updated)
            editingSession = nil
        },
        onDelete: { session in
            deleteSession(session)
            editingSession = nil
        }
    )
}
```

Note: This requires `Session` to conform to `Identifiable` (it already does).

- [ ] **Step 4: Add save and delete helper methods**

Add after `backfillSession`:

```swift
private func saveEditedSession(_ session: Session) {
    guard let eventId = session.eventIdentifier else { return }
    calendarWriter.updateEvent(eventIdentifier: eventId, session: session)
    loadWeekSessions()
}

private func deleteSession(_ session: Session) {
    guard let eventId = session.eventIdentifier else { return }
    calendarWriter.deleteEvent(eventIdentifier: eventId)
    loadWeekSessions()
}
```

- [ ] **Step 5: Build and run**

Run: `./run.sh`
Expected: Build complete, app launches

- [ ] **Step 6: Manual test**
- Navigate to Calendar tab, select a day with sessions
- Single click a session → should highlight with border
- Double click a session → edit sheet opens with pre-populated fields
- Change category and save → session updates
- Double click again → delete with confirmation works

- [ ] **Step 7: Commit**

```bash
git add TimeTracker/Views/Window/CalendarTabView.swift
git commit -m "feat: wire session edit and delete flow in CalendarTabView"
```
