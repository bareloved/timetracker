# Calendar Write Threshold Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Buffer calendar event creation until a tracking span crosses a configurable time threshold, absorbing short sessions as interruptions in neighboring long sessions' notes.

**Architecture:** All buffering logic lives in `CalendarWriter`. SessionEngine is unchanged except for one `resetTracking()` call in `stopSession()`. A new `Interruption` struct captures short session data. The existing JSON-based `buildNotes` is replaced with a human-readable format. A snap Picker in SettingsTabView controls the threshold.

**Tech Stack:** Swift, SwiftUI, EventKit, Swift Testing

---

### Task 1: Add `Interruption` model and update `buildNotes` to human-readable format

**Files:**
- Create: `TimeTracker/Models/Interruption.swift`
- Modify: `TimeTracker/Services/CalendarWriter.swift:134-156`
- Test: `TimeTrackerTests/CalendarNotesTests.swift`

- [ ] **Step 1: Write failing tests for the new notes builder**

Create `TimeTrackerTests/CalendarNotesTests.swift`:

```swift
import Testing
import Foundation
@testable import Loom

@Suite("Calendar Notes Builder")
struct CalendarNotesTests {

    @Test("Notes with intention, apps, and interruptions")
    func fullNotes() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode", "Terminal", "Safari"],
            intention: "Building auth flow"
        )
        let interruptions = [
            Interruption(
                category: "Communication",
                app: "Mail",
                start: Calendar.current.date(bySettingHour: 14, minute: 47, second: 0, of: Date())!,
                duration: 180
            ),
            Interruption(
                category: "Communication",
                app: "Slack",
                start: Calendar.current.date(bySettingHour: 15, minute: 15, second: 0, of: Date())!,
                duration: 120
            ),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Building auth flow"))
        #expect(notes.contains("Apps: Xcode, Terminal, Safari"))
        #expect(notes.contains("Interruptions:"))
        #expect(notes.contains("Mail (3 min)"))
        #expect(notes.contains("Slack (2 min)"))
    }

    @Test("Notes with no intention and no interruptions")
    func appsOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: [])

        #expect(notes == "Apps: Xcode")
        #expect(!notes.contains("Interruptions"))
    }

    @Test("Notes with intention but no interruptions")
    func intentionOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"],
            intention: "Deep work"
        )

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: [])

        #expect(notes == "Deep work\n\nApps: Xcode")
    }

    @Test("Interruption with no app falls back to category")
    func interruptionNoApp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )
        let interruptions = [
            Interruption(category: "Other", app: nil, start: Date(), duration: 60),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Other (1 min)"))
    }

    @Test("Interruption duration rounds up to nearest minute")
    func interruptionRoundsUp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )
        let interruptions = [
            Interruption(category: "Email", app: "Mail", start: Date(), duration: 90),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Mail (2 min)"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter CalendarNotesTests 2>&1 | tail -20`
Expected: Compilation errors — `Interruption` and `buildHumanNotes` don't exist yet.

- [ ] **Step 3: Create Interruption model**

Create `TimeTracker/Models/Interruption.swift`:

```swift
import Foundation

struct Interruption {
    let category: String
    let app: String?
    let start: Date
    let duration: TimeInterval
}
```

- [ ] **Step 4: Implement `buildHumanNotes` and replace `buildNotes`**

In `TimeTracker/Services/CalendarWriter.swift`, replace the `buildTitle` and `buildNotes` methods (lines 132-156) with:

```swift
    // MARK: - Title & Notes Builders

    static func buildTitle(session: Session) -> String {
        if let intention = session.intention, !intention.isEmpty {
            return "\(session.category) — \(intention)"
        }
        return session.category
    }

    static func buildHumanNotes(session: Session, interruptions: [Interruption] = []) -> String {
        var lines: [String] = []
        if let intention = session.intention, !intention.isEmpty {
            lines.append(intention)
            lines.append("")
        }
        lines.append("Apps: \(session.appsUsed.joined(separator: ", "))")
        if !interruptions.isEmpty {
            lines.append("")
            lines.append("Interruptions:")
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            for interruption in interruptions {
                let time = formatter.string(from: interruption.start)
                let app = interruption.app ?? interruption.category
                let mins = Int(ceil(interruption.duration / 60))
                lines.append("  \(time) — \(app) (\(mins) min)")
            }
        }
        return lines.joined(separator: "\n")
    }
```

Note: `buildTitle` changes from `private static` to `static` (needed for tests and later use). `buildHumanNotes` is `static` (not `private`) for testability.

- [ ] **Step 5: Update all callsites from `buildNotes` to `buildHumanNotes`**

In `CalendarWriter.swift`, replace all three uses of `Self.buildNotes(session: session)` with `Self.buildHumanNotes(session: session)`:
- Line 168 in `createEvent`
- Line 188 in `updateCurrentEvent`
- Line 209 in `finalizeEvent`

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter CalendarNotesTests 2>&1 | tail -20`
Expected: All 5 tests PASS.

- [ ] **Step 7: Run all existing tests to verify no regressions**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add TimeTracker/Models/Interruption.swift TimeTrackerTests/CalendarNotesTests.swift TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: add Interruption model and human-readable calendar notes"
```

---

### Task 2: Add buffering state and threshold logic to CalendarWriter

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`
- Test: `TimeTrackerTests/CalendarWriterBufferTests.swift`

- [ ] **Step 1: Write failing tests for buffer logic**

Create `TimeTrackerTests/CalendarWriterBufferTests.swift`. These tests use `CalendarWriter` with `writeEnabled = true` but without calendar authorization, so no actual EventKit calls happen. We test the buffering state machine.

```swift
import Testing
import Foundation
@testable import Loom

@Suite("CalendarWriter Buffer Logic")
@MainActor
struct CalendarWriterBufferTests {

    private func makeWriter() -> CalendarWriter {
        let writer = CalendarWriter()
        writer.writeEnabled = true
        return writer
    }

    private func makeSession(
        category: String = "Coding",
        startTime: Date = Date(),
        endTime: Date? = nil,
        apps: [String] = ["Xcode"],
        intention: String? = nil
    ) -> Session {
        Session(
            category: category,
            startTime: startTime,
            endTime: endTime,
            appsUsed: apps,
            intention: intention
        )
    }

    @Test("createEvent buffers session instead of writing immediately")
    func createEventBuffers() {
        let writer = makeWriter()
        let session = makeSession()

        writer.createEvent(for: session)

        #expect(writer.sessionBuffer.count == 1)
        #expect(writer.isLive == false)
        #expect(writer.trackingStartTime != nil)
    }

    @Test("updateCurrentEvent updates buffer entry by session ID")
    func updateCurrentEventUpdatesBuffer() {
        let writer = makeWriter()
        var session = makeSession()
        writer.createEvent(for: session)

        session.addApp("Terminal")
        writer.updateCurrentEvent(session: session)

        #expect(writer.sessionBuffer.first?.appsUsed.contains("Terminal") == true)
    }

    @Test("finalizeEvent stamps end time in buffer")
    func finalizeEventStampsBuffer() {
        let writer = makeWriter()
        var session = makeSession()
        writer.createEvent(for: session)

        session.endTime = Date().addingTimeInterval(600)
        writer.finalizeEvent(for: session)

        #expect(writer.sessionBuffer.first?.endTime != nil)
    }

    @Test("resetTracking clears all buffer state")
    func resetTrackingClears() {
        let writer = makeWriter()
        let session = makeSession()
        writer.createEvent(for: session)

        writer.resetTracking()

        #expect(writer.sessionBuffer.isEmpty)
        #expect(writer.trackingStartTime == nil)
        #expect(writer.isLive == false)
        #expect(writer.pendingInterruptions.isEmpty)
    }

    @Test("flushBuffer classifies long sessions and short sessions")
    func flushBufferClassifies() {
        let writer = makeWriter()
        // Set threshold to 5 min for testing
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200) // 20 min ago

        // Long session: 10 min
        var longSession = makeSession(category: "Coding", startTime: t)
        longSession.endTime = t.addingTimeInterval(600)

        // Short session: 2 min
        var shortSession = makeSession(category: "Email", startTime: t.addingTimeInterval(600))
        shortSession.endTime = t.addingTimeInterval(720)

        // Another long session: 8 min (currently active)
        let activeSession = makeSession(category: "Coding", startTime: t.addingTimeInterval(720))

        writer.createEvent(for: longSession)
        writer.finalizeEvent(for: longSession)
        writer.createEvent(for: shortSession)
        writer.finalizeEvent(for: shortSession)
        writer.createEvent(for: activeSession)

        // Manually set trackingStartTime far enough back
        writer.trackingStartTime = t

        writer.flushBuffer()

        #expect(writer.isLive == true)
        #expect(writer.sessionBuffer.isEmpty)
        // The short Email session should have been absorbed as an interruption
        // We can't easily check EKEvent creation without authorization,
        // but we can check that the buffer was processed
    }

    @Test("Multiple short sessions before any long session are buffered")
    func multipleShortSessionsBuffered() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-600)

        // Two short sessions
        var s1 = makeSession(category: "Email", startTime: t)
        s1.endTime = t.addingTimeInterval(60)
        var s2 = makeSession(category: "Browsing", startTime: t.addingTimeInterval(60))
        s2.endTime = t.addingTimeInterval(120)

        writer.createEvent(for: s1)
        writer.finalizeEvent(for: s1)
        writer.createEvent(for: s2)
        writer.finalizeEvent(for: s2)

        #expect(writer.sessionBuffer.count == 2)
        #expect(writer.isLive == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter CalendarWriterBufferTests 2>&1 | tail -20`
Expected: Compilation errors — `sessionBuffer`, `isLive`, `trackingStartTime`, `pendingInterruptions`, `flushBuffer`, `resetTracking` don't exist yet.

- [ ] **Step 3: Add buffering state properties to CalendarWriter**

In `TimeTracker/Services/CalendarWriter.swift`, after the existing properties (line 18), add:

```swift
    @ObservationIgnored @AppStorage("calendarWriteThreshold") var writeThreshold: Int = 15 // minutes

    // Buffering state (internal access for testability)
    var sessionBuffer: [Session] = []
    var trackingStartTime: Date?
    var isLive = false
    var pendingInterruptions: [Interruption] = []
    var activeInterruptions: [Interruption] = []
    private var lastFinalizedEventIdentifier: String?
```

- [ ] **Step 4: Rewrite `createEvent` with buffering**

Replace the current `createEvent(for:)` method (lines 160-180) with:

```swift
    func createEvent(for session: Session) {
        guard writeEnabled else { return }

        if isLive {
            createEventLive(for: session)
            return
        }

        // Buffer mode: store session, start threshold timer
        sessionBuffer.append(session)
        if trackingStartTime == nil {
            trackingStartTime = Date()
            startThresholdTimer()
        }
    }
```

Note: The `writeEnabled` guard at the top prevents buffering when writes are disabled, so the threshold timer never starts and `flushBuffer` is never reached.
```

- [ ] **Step 5: Add `createEventLive` helper**

Add this below `createEvent`:

```swift
    private func createEventLive(for session: Session) {
        let duration = session.endTime.map { $0.timeIntervalSince(session.startTime) }
            ?? Date().timeIntervalSince(session.startTime)
        let thresholdSeconds = TimeInterval(writeThreshold * 60)

        if duration < thresholdSeconds {
            // Short session — add as pending interruption
            pendingInterruptions.append(Interruption(
                category: session.category,
                app: session.primaryApp,
                start: session.startTime,
                duration: duration
            ))
            return
        }

        // Long session — create EKEvent
        writeEventToCalendar(for: session, interruptions: pendingInterruptions)
        activeInterruptions = pendingInterruptions
        pendingInterruptions = []
        startUpdateTimer()
    }
```

- [ ] **Step 6: Add `writeEventToCalendar` helper**

Add this helper that performs the actual EventKit write:

```swift
    private func writeEventToCalendar(for session: Session, interruptions: [Interruption] = []) {
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session, interruptions: interruptions)
        event.startDate = roundDown(session.startTime)
        event.endDate = session.endTime.map { roundUp($0) } ?? Date()
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            currentEventIdentifier = event.eventIdentifier
        } catch {
            print("Failed to create event: \(error)")
        }
    }
```

- [ ] **Step 7: Rewrite `updateCurrentEvent` with buffer support**

Replace the current `updateCurrentEvent(session:)` method with:

```swift
    func updateCurrentEvent(session: Session) {
        if !isLive {
            // Buffer mode: find and update by session ID
            if let index = sessionBuffer.firstIndex(where: { $0.id == session.id }) {
                sessionBuffer[index] = session
            } else {
                // Resume case: session was finalized then resumed
                sessionBuffer.append(session)
            }
            return
        }

        // Live mode
        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.title = Self.buildTitle(session: session)
        event.endDate = Date()
        event.notes = Self.buildHumanNotes(session: session, interruptions: activeInterruptions)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to update event: \(error)")
        }
    }
```

- [ ] **Step 8: Rewrite `finalizeEvent` with buffer support**

Replace the current `finalizeEvent(for:)` method with:

```swift
    func finalizeEvent(for session: Session) {
        if !isLive {
            // Buffer mode: stamp end time
            if let index = sessionBuffer.firstIndex(where: { $0.id == session.id }) {
                sessionBuffer[index].endTime = session.endTime
            }
            return
        }

        // Live mode
        stopUpdateTimer()

        if let identifier = currentEventIdentifier,
           let event = eventStore.event(withIdentifier: identifier) {
            // Attach any trailing pending interruptions
            let allInterruptions = activeInterruptions + pendingInterruptions
            event.title = Self.buildTitle(session: session)
            event.endDate = roundUp(session.endTime ?? Date())
            event.notes = Self.buildHumanNotes(session: session, interruptions: allInterruptions)
            event.location = session.primaryApp

            do {
                try eventStore.save(event, span: .thisEvent)
            } catch {
                print("Failed to finalize event: \(error)")
            }

            lastFinalizedEventIdentifier = identifier
            currentEventIdentifier = nil
            activeInterruptions = []
            pendingInterruptions = []
        } else {
            // No event exists (session was short/pending) — check if it grew long enough
            let duration = (session.endTime ?? Date()).timeIntervalSince(session.startTime)
            let thresholdSeconds = TimeInterval(writeThreshold * 60)
            if duration >= thresholdSeconds {
                writeEventToCalendar(for: session, interruptions: pendingInterruptions)
                if let id = currentEventIdentifier,
                   let event = eventStore.event(withIdentifier: id) {
                    event.endDate = roundUp(session.endTime ?? Date())
                    try? eventStore.save(event, span: .thisEvent)
                    lastFinalizedEventIdentifier = id
                    currentEventIdentifier = nil
                }
                pendingInterruptions = []
            } else {
                // Still short — add as interruption now that we know its final duration
                pendingInterruptions.append(Interruption(
                    category: session.category,
                    app: session.primaryApp,
                    start: session.startTime,
                    duration: duration
                ))
            }
        }
    }
```

- [ ] **Step 9: Implement `flushBuffer`**

Add this method:

```swift
    func flushBuffer() {
        guard !sessionBuffer.isEmpty else {
            isLive = true
            return
        }

        let thresholdSeconds = TimeInterval(writeThreshold * 60)

        // Separate active session (no endTime) from completed ones
        var completed: [Session] = []
        var active: Session?
        for session in sessionBuffer {
            if session.endTime == nil {
                active = session
            } else {
                completed.append(session)
            }
        }
        sessionBuffer = []

        // Classify completed sessions as long or short
        var longSessions: [(session: Session, interruptions: [Interruption])] = []
        var pendingShort: [Interruption] = []

        for session in completed {
            let duration = session.duration
            if duration >= thresholdSeconds {
                // Long session — absorb any preceding short sessions
                var sessionInterruptions = pendingShort
                longSessions.append((session: session, interruptions: sessionInterruptions))
                pendingShort = []
            } else {
                // Short session — add as interruption
                pendingShort.append(Interruption(
                    category: session.category,
                    app: session.primaryApp,
                    start: session.startTime,
                    duration: duration
                ))
            }
        }

        // If there are trailing short sessions with no long session after them,
        // attach to the last long session
        if !pendingShort.isEmpty, !longSessions.isEmpty {
            let lastIndex = longSessions.count - 1
            longSessions[lastIndex].interruptions += pendingShort
            pendingShort = []
        }

        // Write long sessions to EventKit
        for (session, interruptions) in longSessions {
            writeEventToCalendar(for: session, interruptions: interruptions)
            // Finalize immediately (these are completed sessions)
            if let id = currentEventIdentifier,
               let event = eventStore.event(withIdentifier: id) {
                event.endDate = roundUp(session.endTime ?? Date())
                event.notes = Self.buildHumanNotes(session: session, interruptions: interruptions)
                try? eventStore.save(event, span: .thisEvent)
                lastFinalizedEventIdentifier = id
                currentEventIdentifier = nil
            }
        }

        // Handle active session
        if let active = active {
            let activeDuration = Date().timeIntervalSince(active.startTime)
            if activeDuration >= thresholdSeconds {
                // Long active session — create event, start update timer
                let allInterruptions = pendingShort
                writeEventToCalendar(for: active, interruptions: allInterruptions)
                activeInterruptions = allInterruptions
                self.pendingInterruptions = []
                startUpdateTimer()
            } else {
                // Short active session — carry forward preceding short sessions only.
                // Do NOT add the active session itself as an interruption (it's still running
                // and may grow long). SessionEngine will continue calling updateCurrentEvent
                // (no-op in live mode with nil currentEventIdentifier) and eventually
                // finalizeEvent, which handles the nil-identifier case correctly:
                // if the session grew long, it creates a one-shot event; if still short,
                // it stays as a pending interruption at that point.
                self.pendingInterruptions = pendingShort
            }
        } else {
            // No active session — any remaining short sessions go to pending
            self.pendingInterruptions = pendingShort
        }

        isLive = true
        stopThresholdTimer()
    }
```

- [ ] **Step 10: Implement `resetTracking`**

Add this method:

```swift
    func resetTracking() {
        // Attach trailing interruptions to last finalized event
        if !pendingInterruptions.isEmpty,
           let lastId = lastFinalizedEventIdentifier,
           let event = eventStore.event(withIdentifier: lastId) {
            // Parse existing notes and append interruptions
            var existingNotes = event.notes ?? ""
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            if !existingNotes.contains("Interruptions:") {
                existingNotes += "\n\nInterruptions:"
            }
            for interruption in pendingInterruptions {
                let time = formatter.string(from: interruption.start)
                let app = interruption.app ?? interruption.category
                let mins = Int(ceil(interruption.duration / 60))
                existingNotes += "\n  \(time) — \(app) (\(mins) min)"
            }
            event.notes = existingNotes
            try? eventStore.save(event, span: .thisEvent)
        }

        sessionBuffer = []
        trackingStartTime = nil
        isLive = false
        pendingInterruptions = []
        activeInterruptions = []
        lastFinalizedEventIdentifier = nil
        currentEventIdentifier = nil
        stopUpdateTimer()
        stopThresholdTimer()
    }
```

- [ ] **Step 11: Implement `createEventImmediately`**

Add this method:

```swift
    func createEventImmediately(for session: Session) {
        guard writeEnabled else { return }
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session)
        event.startDate = roundDown(session.startTime)
        event.endDate = roundUp(session.endTime ?? Date())
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to create immediate event: \(error)")
        }
    }
```

- [ ] **Step 12: Add threshold timer methods**

Add these alongside the existing timer methods:

```swift
    private var thresholdTimer: Timer?

    private func startThresholdTimer() {
        stopThresholdTimer()
        thresholdTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isLive, let start = self.trackingStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= TimeInterval(self.writeThreshold * 60) {
                    self.flushBuffer()
                }
            }
        }
    }

    private func stopThresholdTimer() {
        thresholdTimer?.invalidate()
        thresholdTimer = nil
    }
```

- [ ] **Step 13: Run tests to verify they pass**

Run: `swift test --filter CalendarWriterBufferTests 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 14: Run all tests to verify no regressions**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 15: Commit**

```bash
git add TimeTracker/Services/CalendarWriter.swift TimeTrackerTests/CalendarWriterBufferTests.swift
git commit -m "feat: add session buffering and threshold logic to CalendarWriter"
```

---

### Task 3: Wire SessionEngine and AppState to new CalendarWriter API

**Files:**
- Modify: `TimeTracker/Services/SessionEngine.swift:44-52`
- Modify: `TimeTracker/TimeTrackerApp.swift:380-392`
- Modify: `TimeTracker/Views/Window/CalendarTabView.swift:197-209`
- Test: `TimeTrackerTests/SessionEngineTests.swift`

- [ ] **Step 1: Add `resetTracking` call to SessionEngine.stopSession**

In `TimeTracker/Services/SessionEngine.swift`, modify `stopSession()` to call `resetTracking` after finalization:

```swift
    func stopSession() {
        finalizeCurrentSession()
        calendarWriter?.resetTracking()
        isTracking = false
        currentSpanId = nil
        currentIntention = nil
        tentativeCategory = nil
        tentativeSwitchTime = nil
        lastActivityTime = nil
    }
```

- [ ] **Step 2: Update `createIdleEvent` in AppState**

In `TimeTracker/TimeTrackerApp.swift`, replace the `createIdleEvent` method (lines 380-392):

```swift
    private func createIdleEvent(label: String, duration: TimeInterval) {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-duration)
        let session = Session(
            category: label,
            startTime: startTime,
            endTime: endTime,
            appsUsed: []
        )
        calendarWriter.createEventImmediately(for: session)
    }
```

- [ ] **Step 3: Update `backfillSession` in CalendarTabView**

In `TimeTracker/Views/Window/CalendarTabView.swift`, find the `backfillSession` method and replace the `createEvent` + `finalizeEvent` pair:

```swift
    private func backfillSession(category: String, start: Date, end: Date, intention: String?) {
        let session = Session(
            category: category,
            startTime: start,
            endTime: end,
            appsUsed: [],
            intention: intention
        )
        calendarWriter.createEventImmediately(for: session)
        loadWeekSessions()
    }
```

- [ ] **Step 4: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Services/SessionEngine.swift TimeTracker/TimeTrackerApp.swift TimeTracker/Views/Window/CalendarTabView.swift
git commit -m "feat: wire SessionEngine and AppState to CalendarWriter buffering API"
```

---

### Task 4: Add threshold snap Picker to SettingsTabView

**Files:**
- Modify: `TimeTracker/Views/Window/SettingsTabView.swift:398-416`

- [ ] **Step 1: Add the Minimum Session Length picker**

In `TimeTracker/Views/Window/SettingsTabView.swift`, after the "Time Rounding" `settingsCard` (after line 416) and before the Status card (line 418), insert:

```swift
        settingsCard("Minimum Session Length") {
            HStack {
                Text("Write to calendar after")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("", selection: Binding(
                    get: { calendarWriter.writeThreshold },
                    set: { calendarWriter.writeThreshold = $0 }
                )) {
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                    Text("20 min").tag(20)
                    Text("30 min").tag(30)
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }
```

This follows the exact same pattern as the existing "Time Rounding" picker.

- [ ] **Step 2: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build complete.

- [ ] **Step 3: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/SettingsTabView.swift
git commit -m "feat: add minimum session length picker to settings"
```

---

### Task 5: Integration test and manual verification

**Files:**
- Test: `TimeTrackerTests/CalendarWriterBufferTests.swift` (add integration-style tests)

- [ ] **Step 1: Add integration test for full buffer→flush→live cycle**

Append to `TimeTrackerTests/CalendarWriterBufferTests.swift`:

```swift
    @Test("Full cycle: buffer → flush → live mode")
    func fullCycle() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200)

        // Session 1: Coding 10 min (long)
        var s1 = makeSession(category: "Coding", startTime: t, apps: ["Xcode"])
        writer.createEvent(for: s1)
        s1.endTime = t.addingTimeInterval(600)
        writer.finalizeEvent(for: s1)

        // Session 2: Email 2 min (short)
        var s2 = makeSession(category: "Email", startTime: t.addingTimeInterval(600), apps: ["Mail"])
        writer.createEvent(for: s2)
        s2.endTime = t.addingTimeInterval(720)
        writer.finalizeEvent(for: s2)

        // Session 3: Coding active (long, still running)
        let s3 = makeSession(category: "Coding", startTime: t.addingTimeInterval(720), apps: ["Xcode"])
        writer.createEvent(for: s3)

        #expect(writer.sessionBuffer.count == 3)
        #expect(writer.isLive == false)

        // Simulate threshold crossing
        writer.trackingStartTime = t
        writer.flushBuffer()

        #expect(writer.isLive == true)
        #expect(writer.sessionBuffer.isEmpty)
    }

    @Test("resetTracking after live mode clears everything")
    func resetAfterLive() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200)
        var s1 = makeSession(category: "Coding", startTime: t, apps: ["Xcode"])
        writer.createEvent(for: s1)
        writer.trackingStartTime = t
        writer.flushBuffer()

        #expect(writer.isLive == true)

        writer.resetTracking()

        #expect(writer.isLive == false)
        #expect(writer.sessionBuffer.isEmpty)
        #expect(writer.trackingStartTime == nil)
        #expect(writer.pendingInterruptions.isEmpty)
    }
```

- [ ] **Step 2: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 3: Build and deploy for manual testing**

Run: `./run.sh`

Manual verification checklist:
1. Open Settings → Calendar → verify "Minimum Session Length" picker shows with default 15 min
2. Start tracking → verify no calendar event appears immediately
3. Wait 15+ minutes → verify calendar event appears with correct start time
4. Switch apps briefly during tracking → verify short switches appear as interruptions in the event notes
5. Stop tracking before threshold → verify no calendar event was written
6. Change threshold in settings → verify it takes effect on next tracking session

- [ ] **Step 4: Commit**

```bash
git add TimeTrackerTests/CalendarWriterBufferTests.swift
git commit -m "test: add integration tests for calendar write threshold"
```

- [ ] **Step 5: Delete old JSON buildNotes if any references remain**

Search for any remaining references to the old `buildNotes` method or JSON format. If found, update them to use `buildHumanNotes`.

Run: `grep -r "buildNotes" TimeTracker/ TimeTrackerTests/`
Expected: No results (all replaced with `buildHumanNotes`).

- [ ] **Step 6: Final commit if cleanup was needed**

```bash
git add -A
git commit -m "chore: clean up remaining buildNotes references"
```
