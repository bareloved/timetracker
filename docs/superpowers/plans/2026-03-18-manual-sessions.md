# Manual Sessions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace automatic category detection with explicit user-triggered sessions where the user picks a category and optionally types an intention.

**Architecture:** Simplify SessionEngine to manual start/stop with passive app logging. Strip CalendarWriter back to direct create/update/finalize (no buffering). Add category picker to launch popup. Update MenuBarView to open popup instead of auto-starting.

**Tech Stack:** Swift, SwiftUI, EventKit, Swift Testing

---

### Task 1: Simplify SessionEngine to manual sessions

**Files:**
- Modify: `TimeTracker/Services/SessionEngine.swift`
- Rewrite: `TimeTrackerTests/SessionEngineTests.swift`

- [ ] **Step 1: Rewrite SessionEngine**

Replace the entire contents of `TimeTracker/Services/SessionEngine.swift` with:

```swift
import Foundation

@Observable
@MainActor
final class SessionEngine {

    private(set) var currentSession: Session?
    private(set) var todaySessions: [Session] = []
    private(set) var isTracking = false

    private let calendarWriter: CalendarWriter?

    init(calendarWriter: CalendarWriter?) {
        self.calendarWriter = calendarWriter
    }

    func startSession(category: String, intention: String? = nil) {
        // Implicitly stop current session if one is active
        if isTracking {
            stopSession()
        }

        isTracking = true
        let session = Session(
            category: category,
            startTime: Date(),
            appsUsed: [],
            intention: intention
        )
        currentSession = session
        calendarWriter?.createEvent(for: session)
    }

    func stopSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
        isTracking = false
    }

    func updateIntention(_ intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespaces)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        if var session = currentSession {
            session.intention = value
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
        }
    }

    func process(_ record: ActivityRecord) {
        guard isTracking, var session = currentSession else { return }
        session.addApp(record.appName)
        currentSession = session
        calendarWriter?.updateCurrentEvent(session: session)
    }

    func handleIdle(at time: Date) {
        guard var session = currentSession else { return }
        session.endTime = time
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
        isTracking = false
    }
}
```

- [ ] **Step 2: Rewrite SessionEngine tests**

Replace the entire contents of `TimeTrackerTests/SessionEngineTests.swift` with:

```swift
import Testing
import Foundation
@testable import Loom

@Suite("Session Engine")
@MainActor
struct SessionEngineTests {

    private func makeEngine() -> SessionEngine {
        SessionEngine(calendarWriter: nil)
    }

    @Test("startSession creates session with given category")
    func startSession() {
        let engine = makeEngine()
        engine.startSession(category: "Coding", intention: "Build feature")

        #expect(engine.isTracking == true)
        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.intention == "Build feature")
    }

    @Test("stopSession finalizes and stores session")
    func stopSession() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.stopSession()

        #expect(engine.isTracking == false)
        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
        #expect(engine.todaySessions.first?.endTime != nil)
    }

    @Test("process adds app to current session")
    func processAddsApp() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: nil,
            timestamp: Date()
        ))

        #expect(engine.currentSession?.appsUsed.contains("Xcode") == true)
    }

    @Test("process does nothing when not tracking")
    func processGatedByTracking() {
        let engine = makeEngine()

        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: nil,
            timestamp: Date()
        ))

        #expect(engine.currentSession == nil)
    }

    @Test("process adds multiple unique apps")
    func processMultipleApps() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        let t = Date()
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil, timestamp: t.addingTimeInterval(5)))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(10)))

        #expect(engine.currentSession?.appsUsed == ["Xcode", "Terminal"])
    }

    @Test("handleIdle finalizes session at idle time")
    func handleIdle() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")
        let idleTime = Date().addingTimeInterval(600)

        engine.handleIdle(at: idleTime)

        #expect(engine.isTracking == false)
        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.endTime == idleTime)
    }

    @Test("updateIntention updates current session")
    func updateIntention() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.updateIntention("Deep work")

        #expect(engine.currentSession?.intention == "Deep work")
    }

    @Test("Starting new session implicitly stops current one")
    func implicitStop() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")
        engine.startSession(category: "Email")

        #expect(engine.currentSession?.category == "Email")
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter SessionEngineTests 2>&1 | tail -15`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Services/SessionEngine.swift TimeTrackerTests/SessionEngineTests.swift
git commit -m "feat: simplify SessionEngine to manual start/stop with passive app logging"
```

---

### Task 2: Simplify CalendarWriter — remove buffering

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`
- Delete: `TimeTracker/Models/Interruption.swift`
- Delete: `TimeTrackerTests/CalendarWriterBufferTests.swift`
- Modify: `TimeTrackerTests/CalendarNotesTests.swift`

- [ ] **Step 1: Rewrite CalendarWriter**

Replace the entire contents of `TimeTracker/Services/CalendarWriter.swift` with:

```swift
import EventKit
import Foundation
import AppKit
import SwiftUI

@Observable
@MainActor
final class CalendarWriter {

    private let eventStore = EKEventStore()
    private var timeTrackerCalendar: EKCalendar?
    private var currentEventIdentifier: String?
    private var updateTimer: Timer?
    private(set) var isAuthorized = false

    @ObservationIgnored @AppStorage("calendarName") var calendarName = "Loom"
    @ObservationIgnored @AppStorage("calendarWriteEnabled") var writeEnabled = true
    @ObservationIgnored @AppStorage("timeRounding") var timeRounding: Int = 5 // minutes

    private func roundDown(_ date: Date) -> Date {
        guard timeRounding > 0 else { return date }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = (comps.minute ?? 0) / timeRounding * timeRounding
        return cal.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: comps.hour, minute: minute, second: 0
        )) ?? date
    }

    private func roundUp(_ date: Date) -> Date {
        guard timeRounding > 0 else { return date }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let rounded = ((minute + timeRounding - 1) / timeRounding) * timeRounding
        return cal.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: comps.hour, minute: rounded, second: 0
        )) ?? date
    }

    var availableSources: [EKSource] {
        eventStore.sources.filter { $0.sourceType == .calDAV || $0.sourceType == .local }
    }

    var currentCalendarTitle: String {
        timeTrackerCalendar?.title ?? calendarName
    }

    var currentSourceTitle: String {
        timeTrackerCalendar?.source.title ?? "Unknown"
    }

    var sharedEventStore: EKEventStore { eventStore }

    init() {
        observeStoreChanges()
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                ensureCalendarExists()
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Calendar Management

    private func ensureCalendarExists() {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarName }) {
            timeTrackerCalendar = existing
            return
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = NSColor.systemBlue.cgColor

        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            timeTrackerCalendar = calendar
        } catch {
            print("Failed to create calendar: \(error)")
        }
    }

    func switchSource(to sourceTitle: String) {
        guard let newSource = eventStore.sources.first(where: { $0.title == sourceTitle }) else { return }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.source = newSource
        calendar.cgColor = NSColor.systemBlue.cgColor

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            timeTrackerCalendar = calendar
        } catch {
            print("Failed to switch calendar source: \(error)")
        }
    }

    func renameCalendar(to newName: String) {
        guard !newName.isEmpty, let calendar = timeTrackerCalendar else { return }
        calendar.title = newName
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            calendarName = newName
        } catch {
            print("Failed to rename calendar: \(error)")
        }
    }

    // MARK: - Title & Notes Builders

    static func buildTitle(session: Session) -> String {
        if let intention = session.intention, !intention.isEmpty {
            return "\(session.category) — \(intention)"
        }
        return session.category
    }

    static func buildHumanNotes(session: Session) -> String {
        var lines: [String] = []
        if let intention = session.intention, !intention.isEmpty {
            lines.append(intention)
            lines.append("")
        }
        lines.append("Apps: \(session.appsUsed.joined(separator: ", "))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Event Management

    func createEvent(for session: Session) {
        guard writeEnabled else { return }
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session)
        event.startDate = roundDown(session.startTime)
        event.endDate = roundUp(session.startTime.addingTimeInterval(300))
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            currentEventIdentifier = event.eventIdentifier
            startUpdateTimer()
        } catch {
            print("Failed to create event: \(error)")
        }
    }

    func updateCurrentEvent(session: Session) {
        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.title = Self.buildTitle(session: session)
        event.endDate = Date()
        event.notes = Self.buildHumanNotes(session: session)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to update event: \(error)")
        }
    }

    func finalizeEvent(for session: Session) {
        stopUpdateTimer()

        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else {
            currentEventIdentifier = nil
            return
        }

        event.title = Self.buildTitle(session: session)
        event.endDate = roundUp(session.endTime ?? Date())
        event.notes = Self.buildHumanNotes(session: session)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to finalize event: \(error)")
        }

        currentEventIdentifier = nil
    }

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

    // MARK: - Weekly Stats

    func weeklyStats() async -> [String: TimeInterval] {
        let calendar = Calendar.current
        let now = Date()

        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [:] }

        let todayStart = calendar.startOfDay(for: now)

        guard let tracker = timeTrackerCalendar else { return [:] }

        let predicate = eventStore.predicateForEvents(
            withStart: monday,
            end: todayStart,
            calendars: [tracker]
        )

        let events = eventStore.events(matching: predicate)
        var totals: [String: TimeInterval] = [:]

        for event in events {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            if duration > 0 {
                totals[event.title, default: 0] += duration
            }
        }

        return totals
    }

    // MARK: - Timers

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let identifier = self.currentEventIdentifier,
                      let event = self.eventStore.event(withIdentifier: identifier) else { return }

                event.endDate = Date()
                try? self.eventStore.save(event, span: .thisEvent)
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Store Change Observation

    private func observeStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureCalendarExists()
            }
        }
    }
}
```

- [ ] **Step 2: Delete Interruption model and buffer tests**

```bash
rm TimeTracker/Models/Interruption.swift
rm TimeTrackerTests/CalendarWriterBufferTests.swift
```

- [ ] **Step 3: Update CalendarNotesTests**

Replace `TimeTrackerTests/CalendarNotesTests.swift` — remove interruption tests, update `buildHumanNotes` calls:

```swift
import Testing
import Foundation
@testable import Loom

@Suite("Calendar Notes Builder")
@MainActor
struct CalendarNotesTests {

    @Test("Notes with intention and apps")
    func fullNotes() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode", "Terminal", "Safari"],
            intention: "Building auth flow"
        )

        let notes = CalendarWriter.buildHumanNotes(session: session)

        #expect(notes.contains("Building auth flow"))
        #expect(notes.contains("Apps: Xcode, Terminal, Safari"))
    }

    @Test("Notes with no intention")
    func appsOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )

        let notes = CalendarWriter.buildHumanNotes(session: session)

        #expect(notes == "Apps: Xcode")
    }

    @Test("Notes with intention but no apps")
    func intentionNoApps() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [],
            intention: "Deep work"
        )

        let notes = CalendarWriter.buildHumanNotes(session: session)

        #expect(notes == "Deep work\n\nApps: ")
    }

    @Test("Title with intention")
    func titleWithIntention() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [],
            intention: "auth flow"
        )

        #expect(CalendarWriter.buildTitle(session: session) == "Coding — auth flow")
    }

    @Test("Title without intention")
    func titleWithoutIntention() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: []
        )

        #expect(CalendarWriter.buildTitle(session: session) == "Coding")
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter "CalendarNotes|SessionEngine" 2>&1 | tail -15`
Expected: All tests PASS.

- [ ] **Step 5: Remove "Minimum Session Length" from SettingsTabView**

In `TimeTracker/Views/Window/SettingsTabView.swift`, delete the entire `settingsCard("Minimum Session Length")` block (the one with `calendarWriteThreshold`).

- [ ] **Step 6: Build to verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build complete.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: simplify CalendarWriter — remove buffering, interruptions, threshold"
```

---

### Task 3: Add category picker to launch popup

**Files:**
- Modify: `TimeTracker/Views/LaunchPopup.swift`
- Modify: `TimeTracker/Views/LaunchPopupController.swift` (if separate file)

- [ ] **Step 1: Update LaunchPopupView to include category picker**

Replace `TimeTracker/Views/LaunchPopup.swift` (the view file) with:

```swift
import SwiftUI

struct LaunchPopupView: View {
    let categories: [String]
    let onStart: (String, String?) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategory: String
    @State private var intention = ""

    init(categories: [String], onStart: @escaping (String, String?) -> Void, onDismiss: @escaping () -> Void) {
        self.categories = categories
        self.onStart = onStart
        self.onDismiss = onDismiss
        self._selectedCategory = State(initialValue: categories.first ?? "Other")
    }

    var body: some View {
        VStack(spacing: 14) {
            SunriseAnimation()
                .padding(.top, 4)

            Text("Ready to focus?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            // Category picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(CategoryColors.color(for: category))
                                    .frame(width: 6, height: 6)
                                Text(category)
                                    .font(.system(size: 11, weight: selectedCategory == category ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(selectedCategory == category ? CategoryColors.color(for: category).opacity(0.15) : Theme.trackFill)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedCategory == category ? CategoryColors.color(for: category).opacity(0.4) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Intention field
            TextField("What are you working on? (optional)", text: $intention)
                .textFieldStyle(.roundedBorder)
                .onSubmit { startSession() }

            Button(action: startSession) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button("Not now") {
                onDismiss()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: 320)
        .background(Theme.background)
    }

    private func startSession() {
        onStart(selectedCategory, intention.isEmpty ? nil : intention)
    }
}
```

- [ ] **Step 2: Update LaunchPopupController**

Find the `LaunchPopupController` (in `LaunchPopup.swift` or `LaunchPopupController.swift`) and update the `show` method signature:

```swift
func show(categories: [String], onStart: @escaping (String, String?) -> Void, onDismiss: @escaping () -> Void) {
    let view = LaunchPopupView(
        categories: categories,
        onStart: { [weak self] category, intention in
            onStart(category, intention)
            self?.dismiss()
        },
        onDismiss: { [weak self] in
            onDismiss()
            self?.dismiss()
        }
    )

    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
        styleMask: [.nonactivatingPanel, .titled, .closable],
        backing: .buffered,
        defer: false
    )
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.title = "Loom"
    panel.contentView = NSHostingView(rootView: view)
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    self.panel = panel
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Compilation errors — `AppState` still passes old signature. That's expected, we fix it in Task 4.

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/LaunchPopup*.swift
git commit -m "feat: add category picker to launch popup"
```

---

### Task 4: Update AppState and MenuBarView wiring

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift` (AppState)
- Modify: `TimeTracker/Views/MenuBarView.swift`

- [ ] **Step 1: Update AppState**

In `TimeTracker/TimeTrackerApp.swift`, make these changes:

**a) Update `setup()` — SessionEngine init no longer takes config, launch popup gets categories:**

Replace the engine creation and wiring block (around lines 96-104):
```swift
        let engine = SessionEngine(calendarWriter: calendarWriter)
        self.sessionEngine = engine

        activityMonitor.onActivity = { [weak engine] record in
            engine?.process(record)
        }
        activityMonitor.onIdle = { [weak engine] in
            engine?.handleIdle(at: Date())
        }
```

Replace the launch popup block (around lines 132-139):
```swift
        let categoryNames = Array(config.categories.keys).sorted()
        launchPopupController.show(
            categories: categoryNames,
            onStart: { [weak self] category, intention in
                self?.startTracking(category: category, intention: intention)
                self?.openMainWindow()
            },
            onDismiss: { }
        )
```

**b) Update `startTracking`:**
```swift
    func startTracking(category: String, intention: String? = nil) {
        sessionEngine?.startSession(category: category, intention: intention)
        activityMonitor.start()
    }
```

**c) Update `stopTracking`:**
```swift
    func stopTracking() {
        sessionEngine?.stopSession()
        activityMonitor.stop()
    }
```

**d) Update `saveConfig` — no longer rebuilds engine (engine doesn't use config):**
```swift
    func saveConfig(_ newConfig: CategoryConfig) {
        do {
            try CategoryConfigLoader.save(newConfig)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
```

**e) Keep `config` stored for category list access — add a property:**

Add after `var launchPopupController`:
```swift
    private(set) var categoryConfig: CategoryConfig?
```

In `setup()`, after loading config:
```swift
        self.categoryConfig = config
```

Update `saveConfig` to also store it:
```swift
    func saveConfig(_ newConfig: CategoryConfig) {
        do {
            try CategoryConfigLoader.save(newConfig)
            self.categoryConfig = newConfig
        } catch {
            print("Failed to save config: \(error)")
        }
    }
```

- [ ] **Step 2: Update MenuBarView**

In `TimeTracker/Views/MenuBarView.swift`:

**a) Change the `onStartTracking` signature:**
```swift
    let onStartTracking: (String, String?) -> Void
```

**b) Replace the "Start Session" button in the no-session state** to show the launch popup. The simplest approach: the button calls `onStartTracking` with a default category. But per spec, it should open the popup. So we add a new callback:

Actually, simpler: add an `onShowSessionPicker` callback and use it:

```swift
    let onShowSessionPicker: () -> Void
```

Replace the "No active session" VStack:
```swift
                    VStack(spacing: 8) {
                        Text("No active session")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Button(action: onShowSessionPicker) {
                            Text("Start Session")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(CategoryColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
```

Replace the bottom play button too:
```swift
                } else {
                    Button(action: onShowSessionPicker) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
```

**c) Remove the unused `onStartTracking` property** (it's replaced by `onShowSessionPicker`).

- [ ] **Step 3: Update TimeTrackerApp MenuBarView instantiation**

In the `MenuBarExtra` body, update the `MenuBarView` instantiation:

```swift
                    MenuBarView(
                        sessionEngine: engine,
                        activityMonitor: appState.activityMonitor,
                        accessibilityGranted: appState.accessibilityGranted,
                        goalCategory: appState.goalCategory,
                        goalHours: appState.goalHours,
                        isTracking: engine.isTracking,
                        onShowSessionPicker: { appState.showSessionPicker() },
                        onStopTracking: { appState.stopTracking() },
                        onQuit: appState.quit
                    )
```

**d) Add `showSessionPicker` to AppState:**

```swift
    func showSessionPicker() {
        let categoryNames = categoryConfig.map { Array($0.categories.keys).sorted() } ?? ["Other"]
        launchPopupController.show(
            categories: categoryNames,
            onStart: { [weak self] category, intention in
                self?.startTracking(category: category, intention: intention)
            },
            onDismiss: { }
        )
    }
```

- [ ] **Step 4: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build complete.

- [ ] **Step 5: Run all tests**

Run: `swift test 2>&1 | tail -15`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire manual sessions through AppState and MenuBarView"
```

---

### Task 5: Clean up and verify

**Files:**
- Verify all files compile and tests pass

- [ ] **Step 1: Run full test suite**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS (no pre-existing failures since we rewrote the tests).

- [ ] **Step 2: Build and deploy**

Run: `./run.sh`

Manual verification:
1. App launches → popup shows with category picker + intention field
2. Pick a category, type intention, press Start → timer starts, calendar event created
3. Switch between apps → apps list updates in menu bar
4. Click "What are you working on?" → can edit intention mid-session
5. Press Stop → session finalized, calendar event saved with correct end time
6. Press Start (from menu bar) → session picker popup opens
7. Start new session while one is active → old session stops, new one starts
8. Go idle for 5+ min → session finalized, idle return popup on return

- [ ] **Step 3: Commit if any fixes needed**

```bash
git add -A
git commit -m "fix: cleanup after manual sessions migration"
```
