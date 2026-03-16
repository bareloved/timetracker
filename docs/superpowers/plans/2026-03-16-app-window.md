# App Window Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a main application window with 4 tabs (Today, Calendar, Stats, Settings), convert from always-on tracking to user-initiated sessions, add browser tab tracking, and add a launch popup.

**Architecture:** The app keeps its menu bar extra and adds a standard `Window` scene. The SessionEngine gains start/stop control and a `trackingSpanId` concept. A new `CalendarReader` service reads historical events. New views are organized by tab in `Views/Window/`.

**Tech Stack:** Swift 5.9, SwiftUI, EventKit, AppKit (Accessibility API), macOS 14+

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `TimeTracker/Services/CalendarReader.swift` | Fetch EKEvents from "Time Tracker" calendar, map to Session objects |
| `TimeTracker/Services/BrowserTracker.swift` | Read browser tab URL/title via Accessibility API |
| `TimeTracker/Views/Window/MainWindowView.swift` | Root window view with TabView + mini-player |
| `TimeTracker/Views/Window/TodayTabView.swift` | Today tab — idle CTA + active session hero |
| `TimeTracker/Views/Window/CalendarTabView.swift` | Calendar tab — week strip + vertical timeline |
| `TimeTracker/Views/Window/StatsTabView.swift` | Stats tab — category distribution + intention breakdown |
| `TimeTracker/Views/Window/SettingsTabView.swift` | Settings tab — two-pane sidebar layout |
| `TimeTracker/Views/Window/MiniPlayerBar.swift` | Persistent session control bar |
| `TimeTracker/Views/Window/WeekStripView.swift` | Reusable week day strip (used by Calendar + Stats) |
| `TimeTracker/Views/Window/VerticalTimelineView.swift` | Vertical hour-by-hour timeline with session blocks |
| `TimeTracker/Views/Window/BackfillSheetView.swift` | Manual session add form |
| `TimeTracker/Views/Window/SunriseAnimation.swift` | Rising-arc sunrise SwiftUI animation |
| `TimeTracker/Views/LaunchPopupView.swift` | "Ready to focus?" floating panel |
| `TimeTracker/Views/LaunchPopupController.swift` | NSPanel controller for launch popup |

### Modified Files

| File | Changes |
|------|---------|
| `TimeTracker/Models/Session.swift` | Add `intention`, `trackingSpanId`; change `category` to `var`; add init with all params |
| `TimeTracker/Models/ActivityRecord.swift` | Add `pageURL` field |
| `TimeTracker/Models/Category.swift` | Add `urlPatterns` to `CategoryRule`; add URL-aware resolve method |
| `TimeTracker/Services/SessionEngine.swift` | Add `startSession(intention:)`, `stopSession()`; gate `process()` behind `isTracking`; pass intention/spanId to new sessions |
| `TimeTracker/Services/ActivityMonitor.swift` | Add browser URL extraction in `poll()` |
| `TimeTracker/Services/CalendarWriter.swift` | Change notes format to JSON with intention/spanId |
| `TimeTracker/TimeTrackerApp.swift` | Add `Window` scene; update `AppState` for start/stop model; add launch popup logic; add window lifecycle (activation policy) |
| `TimeTracker/Views/MenuBarView.swift` | Add start/stop button; add "Open Window" button; update idle text |
| `TimeTracker/Views/CurrentSessionView.swift` | Use `CategoryColors.color(for:)` for dot color; show intention text |

---

## Chunk 1: Model & Engine Changes

### Task 1: Update Session Model

**Files:**
- Modify: `TimeTracker/Models/Session.swift`
- Modify: `TimeTrackerTests/SessionTests.swift`

- [ ] **Step 1: Update Session struct**

```swift
struct Session: Identifiable {
    let id: UUID
    var category: String
    let startTime: Date
    var endTime: Date?
    var appsUsed: [String]
    var intention: String?
    var trackingSpanId: UUID?

    init(
        id: UUID = UUID(),
        category: String,
        startTime: Date,
        endTime: Date? = nil,
        appsUsed: [String],
        intention: String? = nil,
        trackingSpanId: UUID? = nil
    ) {
        self.id = id
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.appsUsed = appsUsed
        self.intention = intention
        self.trackingSpanId = trackingSpanId
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var primaryApp: String? {
        appsUsed.first
    }

    var isActive: Bool {
        endTime == nil
    }

    mutating func addApp(_ appName: String) {
        if !appsUsed.contains(appName) {
            appsUsed.append(appName)
        }
    }
}
```

- [ ] **Step 2: Update tests to use new init**

Find all `Session(category:startTime:endTime:appsUsed:)` calls in tests and verify they still compile (the new init has defaults for the new params, so existing calls should work). Add a test for the new fields:

```swift
func testSessionIntentionAndSpanId() {
    let spanId = UUID()
    let session = Session(
        category: "Coding",
        startTime: Date(),
        appsUsed: ["Xcode"],
        intention: "Fix bug",
        trackingSpanId: spanId
    )
    XCTAssertEqual(session.intention, "Fix bug")
    XCTAssertEqual(session.trackingSpanId, spanId)
}
```

- [ ] **Step 3: Build and run tests**

Run: `cd /Users/bareloved/Github/timetracker && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Models/Session.swift TimeTrackerTests/SessionTests.swift
git commit -m "feat: add intention and trackingSpanId to Session model"
```

### Task 2: Update ActivityRecord

**Files:**
- Modify: `TimeTracker/Models/ActivityRecord.swift`

- [ ] **Step 1: Add pageURL field**

```swift
struct ActivityRecord {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let pageURL: String?
    let timestamp: Date
}
```

- [ ] **Step 2: Fix compilation — update all ActivityRecord inits**

The existing code creates `ActivityRecord` in `ActivityMonitor.poll()`. Update that call to include `pageURL: nil` for now. Search for any other `ActivityRecord(` calls and add the new param.

In `ActivityMonitor.swift:86-91`, change to:
```swift
let record = ActivityRecord(
    bundleId: bundleId,
    appName: appName,
    windowTitle: windowTitle,
    pageURL: nil,
    timestamp: Date()
)
```

- [ ] **Step 3: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Models/ActivityRecord.swift TimeTracker/Services/ActivityMonitor.swift
git commit -m "feat: add pageURL field to ActivityRecord"
```

### Task 3: Update CategoryRule with URL Patterns

**Files:**
- Modify: `TimeTracker/Models/Category.swift`
- Modify: `TimeTrackerTests/CategoryTests.swift`

- [ ] **Step 1: Write failing test**

```swift
func testResolveWithURLPattern() {
    let config = CategoryConfig(
        categories: [
            "Coding": CategoryRule(apps: [], related: nil, urlPatterns: ["github.com", "stackoverflow.com"]),
            "Email": CategoryRule(apps: ["com.apple.mail"], related: nil, urlPatterns: ["gmail.com"]),
        ],
        defaultCategory: "Other"
    )
    // URL match
    XCTAssertEqual(
        config.resolve(bundleId: "com.apple.Safari", currentCategory: nil, pageURL: "https://github.com/foo/bar"),
        "Coding"
    )
    // No URL match falls through to default
    XCTAssertEqual(
        config.resolve(bundleId: "com.apple.Safari", currentCategory: nil, pageURL: "https://reddit.com"),
        "Other"
    )
    // Nil URL uses existing logic
    XCTAssertEqual(
        config.resolve(bundleId: "com.apple.mail", currentCategory: nil, pageURL: nil),
        "Email"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/bareloved/Github/timetracker && swift test --filter testResolveWithURLPattern 2>&1 | tail -10`
Expected: FAIL — no `urlPatterns` parameter, no `pageURL` parameter on resolve

- [ ] **Step 3: Implement**

Update `Category.swift`:

```swift
struct CategoryRule: Codable {
    var apps: [String]
    var related: [String]?
    var urlPatterns: [String]?
}
```

Add a new `resolve` overload that accepts `pageURL`:

```swift
func resolve(bundleId: String, currentCategory: String?, pageURL: String? = nil) -> String {
    // 1. Check primary app match
    if let primary = category(forBundleId: bundleId) {
        return primary
    }
    // 2. Check URL patterns
    if let url = pageURL {
        let lowered = url.lowercased()
        for (name, rule) in categories {
            if let patterns = rule.urlPatterns {
                for pattern in patterns {
                    if lowered.contains(pattern.lowercased()) {
                        return name
                    }
                }
            }
        }
    }
    // 3. Check related
    if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
        return current
    }
    return defaultCategory
}
```

Remove the old `resolve(bundleId:currentCategory:)` method (the new one has a default `pageURL: nil` so all existing callers continue to work).

- [ ] **Step 4: Run tests**

Run: `cd /Users/bareloved/Github/timetracker && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Models/Category.swift TimeTrackerTests/CategoryTests.swift
git commit -m "feat: add URL pattern matching to category resolution"
```

### Task 4: Update SessionEngine for Start/Stop Control

**Files:**
- Modify: `TimeTracker/Services/SessionEngine.swift`
- Modify: `TimeTrackerTests/SessionEngineTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testStartSessionSetsTrackingState() {
    let engine = SessionEngine(config: config, calendarWriter: nil)
    XCTAssertFalse(engine.isTracking)
    engine.startSession(intention: "Fix bugs")
    XCTAssertTrue(engine.isTracking)
    XCTAssertNotNil(engine.currentSpanId)
}

func testProcessIgnoredWhenNotTracking() {
    let engine = SessionEngine(config: config, calendarWriter: nil)
    let record = ActivityRecord(bundleId: "com.apple.Xcode", appName: "Xcode", windowTitle: nil, pageURL: nil, timestamp: Date())
    engine.process(record)
    XCTAssertNil(engine.currentSession)
}

func testStopSessionFinalizesAndClearsTracking() {
    let engine = SessionEngine(config: config, calendarWriter: nil)
    engine.startSession(intention: "Work")
    let record = ActivityRecord(bundleId: "com.apple.Xcode", appName: "Xcode", windowTitle: nil, pageURL: nil, timestamp: Date())
    engine.process(record)
    XCTAssertNotNil(engine.currentSession)
    engine.stopSession()
    XCTAssertFalse(engine.isTracking)
    XCTAssertNil(engine.currentSession)
    XCTAssertEqual(engine.todaySessions.count, 1)
    XCTAssertEqual(engine.todaySessions.first?.intention, "Work")
}

func testSessionsShareTrackingSpanId() {
    let engine = SessionEngine(config: config, calendarWriter: nil)
    engine.startSession(intention: "Deep work")
    // Process two different categories to create two sessions
    let r1 = ActivityRecord(bundleId: "com.apple.Xcode", appName: "Xcode", windowTitle: nil, pageURL: nil, timestamp: Date())
    engine.process(r1)
    // Force category switch by advancing time
    let futureTime = Date().addingTimeInterval(150) // past 2-min threshold
    let r2 = ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, pageURL: nil, timestamp: futureTime)
    engine.process(r2)
    let r3 = ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, pageURL: nil, timestamp: futureTime.addingTimeInterval(150))
    engine.process(r3)
    // Both sessions should share the same spanId
    engine.stopSession()
    let spanIds = Set(engine.todaySessions.compactMap(\.trackingSpanId))
    XCTAssertEqual(spanIds.count, 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/bareloved/Github/timetracker && swift test --filter SessionEngineTests 2>&1 | tail -20`
Expected: FAIL — `isTracking`, `startSession`, `stopSession`, `currentSpanId` don't exist

- [ ] **Step 3: Implement start/stop in SessionEngine**

Add to `SessionEngine`:

```swift
private(set) var isTracking = false
private(set) var currentSpanId: UUID?
private var currentIntention: String?

func startSession(intention: String? = nil) {
    guard !isTracking else { return }
    isTracking = true
    currentSpanId = UUID()
    currentIntention = intention?.isEmpty == true ? nil : intention
}

func stopSession() {
    guard isTracking else { return }
    finalizeCurrentSession()
    isTracking = false
    currentSpanId = nil
    currentIntention = nil
}
```

Gate `process()` — add at the top of the method:
```swift
guard isTracking else { return }
```

Update `startNewSession` to pass intention and spanId:
```swift
private func startNewSession(category: String, appName: String, at time: Date) {
    // resumption check (existing code)...

    let session = Session(
        category: category,
        startTime: time,
        endTime: nil,
        appsUsed: [appName],
        intention: currentIntention,
        trackingSpanId: currentSpanId
    )
    currentSession = session
    calendarWriter?.createEvent(for: session)
}
```

Also update the resumed session path to set intention/spanId if they're nil:
```swift
if resumed.intention == nil { resumed.intention = currentIntention }
if resumed.trackingSpanId == nil { resumed.trackingSpanId = currentSpanId }
```

Update the call to `config.resolve` in `process()` to pass pageURL:
```swift
let category = config.resolve(
    bundleId: record.bundleId,
    currentCategory: currentSession?.category,
    pageURL: record.pageURL
)
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/bareloved/Github/timetracker && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Services/SessionEngine.swift TimeTrackerTests/SessionEngineTests.swift
git commit -m "feat: add start/stop session control to SessionEngine"
```

### Task 5: Update CalendarWriter Notes to JSON

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`

- [ ] **Step 1: Update createEvent and updateCurrentEvent to write JSON notes**

Replace the notes line in `createEvent`:
```swift
event.notes = Self.buildNotes(session: session)
```

Replace the notes line in `updateCurrentEvent`:
```swift
event.notes = Self.buildNotes(session: session)
```

Replace the notes line in `finalizeEvent`:
```swift
event.notes = Self.buildNotes(session: session)
```

Add the helper:
```swift
private static func buildNotes(session: Session) -> String {
    var dict: [String: Any] = ["apps": session.appsUsed]
    if let intention = session.intention {
        dict["intention"] = intention
    }
    if let spanId = session.trackingSpanId {
        dict["spanId"] = spanId.uuidString
    }
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
          let json = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return json
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: write session notes as JSON with intention and spanId"
```

### Task 6: Create CalendarReader Service

**Files:**
- Create: `TimeTracker/Services/CalendarReader.swift`

- [ ] **Step 1: Write CalendarReader**

```swift
import EventKit
import Foundation

@MainActor
final class CalendarReader {
    private let eventStore: EKEventStore
    private let calendarName = "Time Tracker"

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    func sessions(for dateRange: DateInterval) -> [Session] {
        guard let calendar = findCalendar() else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        return events.compactMap { event in
            sessionFromEvent(event)
        }.sorted { $0.startTime < $1.startTime }
    }

    func sessions(forDay date: Date) -> [Session] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return sessions(for: DateInterval(start: start, end: end))
    }

    func sessionsForWeek(containing date: Date) -> [Date: [Session]] {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps),
              let sunday = calendar.date(byAdding: .day, value: 7, to: monday) else { return [:] }

        let allSessions = sessions(for: DateInterval(start: monday, end: sunday))
        var grouped: [Date: [Session]] = [:]
        for session in allSessions {
            let dayStart = calendar.startOfDay(for: session.startTime)
            grouped[dayStart, default: []].append(session)
        }
        return grouped
    }

    private func findCalendar() -> EKCalendar? {
        eventStore.calendars(for: .event).first { $0.title == calendarName }
    }

    private func sessionFromEvent(_ event: EKEvent) -> Session? {
        guard let title = event.title, !title.isEmpty else { return nil }

        var apps: [String] = []
        var intention: String?
        var spanId: UUID?

        if let notes = event.notes,
           let data = notes.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            apps = (json["apps"] as? [String]) ?? []
            intention = json["intention"] as? String
            if let spanStr = json["spanId"] as? String {
                spanId = UUID(uuidString: spanStr)
            }
        } else if let notes = event.notes, notes.hasPrefix("Apps: ") {
            // Legacy format
            apps = String(notes.dropFirst(6)).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        return Session(
            category: title,
            startTime: event.startDate,
            endTime: event.endDate,
            appsUsed: apps,
            intention: intention,
            trackingSpanId: spanId
        )
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/CalendarReader.swift
git commit -m "feat: add CalendarReader service for historical session data"
```

### Task 7: Update AppState for Start/Stop Model

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Update AppState.setup() to not auto-start monitoring**

Change `setup()`: Remove `activityMonitor.start()`. The monitor should only start when a session starts.

Add methods to AppState:

```swift
func startTracking(intention: String? = nil) {
    sessionEngine?.startSession(intention: intention)
    activityMonitor.start()
}

func stopTracking() {
    sessionEngine?.stopSession()
    activityMonitor.stop()
}
```

Update `togglePause()`:
```swift
func togglePause() {
    if activityMonitor.isPaused {
        activityMonitor.resume()
    } else {
        activityMonitor.pause()
        sessionEngine?.handleIdle(at: Date())
    }
}
```

Update `quit()`:
```swift
func quit() {
    if sessionEngine?.isTracking == true {
        sessionEngine?.stopSession()
    }
    NSApplication.shared.terminate(nil)
}
```

Update `setupTerminationHandler` to call `stopSession` instead of `finalizeCurrentSession`.

Update sleep handler to call `stopSession` if tracking.

Add `calendarReader` property:
```swift
var calendarReader: CalendarReader?
```

Initialize it in `setup()` after calendar access is granted:
```swift
calendarReader = CalendarReader(eventStore: calendarWriter.eventStore)
```

This requires exposing `eventStore` from `CalendarWriter` — add a computed property:
```swift
// In CalendarWriter:
var sharedEventStore: EKEventStore { eventStore }
```

Then in setup:
```swift
calendarReader = CalendarReader(eventStore: calendarWriter.sharedEventStore)
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/TimeTrackerApp.swift TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: update AppState for user-initiated start/stop tracking"
```

---

## Chunk 2: Browser Tracking & Menu Bar Updates

### Task 8: Create BrowserTracker Service

**Files:**
- Create: `TimeTracker/Services/BrowserTracker.swift`

- [ ] **Step 1: Write BrowserTracker**

```swift
import AppKit
import ApplicationServices

enum BrowserTracker {
    private static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",  // Arc
        "org.mozilla.firefox",
        "com.brave.Browser",
        "com.microsoft.edgemac",
    ]

    static func isBrowser(bundleId: String) -> Bool {
        browserBundleIds.contains(bundleId)
    }

    static func activeTabURL(for app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)

        // Try to get the focused window
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else {
            return nil
        }

        let axWindow = window as! AXUIElement

        // Strategy: look for a text field with role "AXTextField" in the toolbar
        // that contains a URL-like string
        if let url = findURLInToolbar(axWindow) {
            return url
        }

        // Fallback: try the window's document attribute
        var document: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXDocumentAttribute as CFString, &document) == .success,
           let urlStr = document as? String {
            return urlStr
        }

        return nil
    }

    private static func findURLInToolbar(_ window: AXUIElement) -> String? {
        // Get toolbar
        var toolbar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXToolbarAttribute as CFString, &toolbar) == .success else {
            // Try children approach
            return findURLInChildren(window, depth: 0)
        }

        return findURLInChildren(toolbar as! AXUIElement, depth: 0)
    }

    private static func findURLInChildren(_ element: AXUIElement, depth: Int) -> String? {
        guard depth < 6 else { return nil }

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        if let roleStr = role as? String, roleStr == "AXTextField" || roleStr == "AXComboBox" {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
               let str = value as? String,
               looksLikeURL(str) {
                return str.hasPrefix("http") ? str : "https://\(str)"
            }
        }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil
        }

        for child in childArray.prefix(20) {
            if let url = findURLInChildren(child, depth: depth + 1) {
                return url
            }
        }

        return nil
    }

    private static func looksLikeURL(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        return trimmed.contains(".") && !trimmed.contains(" ") && trimmed.count > 4
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/BrowserTracker.swift
git commit -m "feat: add BrowserTracker for reading active tab URL via AX API"
```

### Task 9: Integrate BrowserTracker into ActivityMonitor

**Files:**
- Modify: `TimeTracker/Services/ActivityMonitor.swift`

- [ ] **Step 1: Update poll() to capture browser URL**

In `ActivityMonitor.poll()`, after getting `frontApp`, `bundleId`, `appName`, and `windowTitle`, add:

```swift
var pageURL: String? = nil
if BrowserTracker.isBrowser(bundleId) {
    pageURL = BrowserTracker.activeTabURL(for: frontApp)
}

let record = ActivityRecord(
    bundleId: bundleId,
    appName: appName,
    windowTitle: windowTitle,
    pageURL: pageURL,
    timestamp: Date()
)
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/ActivityMonitor.swift
git commit -m "feat: integrate browser URL detection into ActivityMonitor polling"
```

### Task 10: Update MenuBarView for Start/Stop

**Files:**
- Modify: `TimeTracker/Views/MenuBarView.swift`

- [ ] **Step 1: Update MenuBarView parameters and UI**

Add new parameters:
```swift
let isTracking: Bool
let onStartTracking: (String?) -> Void
let onStopTracking: () -> Void
let onOpenWindow: () -> Void
```

Update the body — replace the "Paused / Waiting for activity..." section:

```swift
if let session = sessionEngine.currentSession {
    CurrentSessionView(session: session)
} else if isTracking {
    Text("Starting...")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
} else {
    // Idle — show start CTA
    VStack(spacing: 8) {
        Text("No active session")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        Button(action: { onStartTracking(nil) }) {
            Text("Start Session")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(CategoryColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
}
```

Update bottom controls — replace pause/resume with start/stop:
```swift
if isTracking {
    Button(action: onStopTracking) {
        Image(systemName: "stop.fill")
            .font(.system(size: 13))
            .foregroundStyle(CategoryColors.accent)
    }
    .buttonStyle(.plain)
} else {
    Button(action: { onStartTracking(nil) }) {
        Image(systemName: "play.fill")
            .font(.system(size: 13))
            .foregroundStyle(CategoryColors.accent)
    }
    .buttonStyle(.plain)
}

Button(action: onOpenWindow) {
    Image(systemName: "macwindow")
        .font(.system(size: 13))
}
.buttonStyle(.plain)
```

- [ ] **Step 2: Update MenuBarView call site in TimeTrackerApp.swift**

```swift
MenuBarView(
    sessionEngine: engine,
    activityMonitor: appState.activityMonitor,
    accessibilityGranted: appState.accessibilityGranted,
    goalCategory: appState.goalCategory,
    goalHours: appState.goalHours,
    isTracking: engine.isTracking,
    onStartTracking: { intention in appState.startTracking(intention: intention) },
    onStopTracking: { appState.stopTracking() },
    onOpenSettings: appState.openSettings,
    onOpenWindow: { appState.openMainWindow() },
    onQuit: appState.quit
)
```

Add `openMainWindow()` stub to AppState (will implement in Task 13):
```swift
func openMainWindow() {
    // Will be implemented with Window scene
}
```

- [ ] **Step 3: Update CurrentSessionView to show intention**

In `CurrentSessionView.swift`, after the category dot and name, if `session.intention` is non-nil, show it:

```swift
if let intention = session.intention {
    Text("·")
        .foregroundStyle(Theme.textTertiary)
    Text("\"\(intention)\"")
        .font(.system(size: 12))
        .italic()
        .foregroundStyle(Theme.textTertiary)
        .lineLimit(1)
}
```

Also fix the dot color to use `CategoryColors.color(for:)`:
```swift
Circle()
    .fill(CategoryColors.color(for: session.category))
    .frame(width: 7, height: 7)
```

- [ ] **Step 4: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Views/MenuBarView.swift TimeTracker/Views/CurrentSessionView.swift TimeTracker/TimeTrackerApp.swift
git commit -m "feat: update menu bar for start/stop model with window open button"
```

---

## Chunk 3: Main Window — Shell & Today Tab

### Task 11: Create MiniPlayerBar

**Files:**
- Create: `TimeTracker/Views/Window/MiniPlayerBar.swift`

- [ ] **Step 1: Write MiniPlayerBar view**

```swift
import SwiftUI

struct MiniPlayerBar: View {
    let currentSession: Session?
    let isTracking: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            if let session = currentSession {
                // Category dot + name + intention
                Circle()
                    .fill(CategoryColors.color(for: session.category))
                    .frame(width: 7, height: 7)
                Text(session.category)
                    .font(.system(size: 11, weight: .medium))
                if let intention = session.intention {
                    Text("· \(intention)")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                // Timer
                Text(formattedTime(session))
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                // Stop button
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(CategoryColors.accent)
                            .frame(width: 26, height: 26)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("No active session")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(CategoryColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.backgroundSecondary)
        .onReceive(timer) { now = $0 }
    }

    private func formattedTime(_ session: Session) -> String {
        let duration = now.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/MiniPlayerBar.swift
git commit -m "feat: add MiniPlayerBar component"
```

### Task 12: Create TodayTabView

**Files:**
- Create: `TimeTracker/Views/Window/TodayTabView.swift`

- [ ] **Step 1: Write TodayTabView**

```swift
import SwiftUI

struct TodayTabView: View {
    let sessionEngine: SessionEngine
    let isTracking: Bool
    let onStart: (String?) -> Void
    let onStop: () -> Void

    @State private var intention = ""
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let session = sessionEngine.currentSession {
                    activeView(session: session)
                } else {
                    idleView
                }
            }
            .padding(24)
        }
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Idle State

    @ViewBuilder
    private var idleView: some View {
        Spacer().frame(height: 40)

        VStack(spacing: 14) {
            Text("What are you working on?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            TextField("Intention (optional)", text: $intention)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Button(action: { onStart(intention.isEmpty ? nil : intention); intention = "" }) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)

        Spacer().frame(height: 20)

        // Earlier today
        if !sessionEngine.todaySessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("EARLIER TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.5)

                TimelineBarView(
                    sessions: sessionEngine.todaySessions,
                    currentSession: nil
                )

                DailySummaryView(
                    sessions: sessionEngine.todaySessions,
                    currentSession: nil
                )
            }
        }
    }

    // MARK: - Active State

    @ViewBuilder
    private func activeView(session: Session) -> some View {
        // Hero timer
        VStack(spacing: 6) {
            Text(formattedTime(session))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .kerning(-1.5)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Circle()
                    .fill(CategoryColors.color(for: session.category))
                    .frame(width: 8, height: 8)
                Text(session.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                if let intention = session.intention {
                    Text("·")
                        .foregroundStyle(Theme.textTertiary)
                    Text("\"\(intention)\"")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // App icons
            HStack(spacing: 6) {
                ForEach(session.appsUsed.prefix(5), id: \.self) { appName in
                    if let bundleId = appBundleId(for: appName) {
                        Image(nsImage: AppIconCache.shared.icon(forBundleId: bundleId))
                            .resizable()
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                Text(session.appsUsed.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)

        // Timeline
        TimelineBarView(
            sessions: sessionEngine.todaySessions,
            currentSession: session
        )

        // Activity pulse
        ActivityPulseView(
            sessions: sessionEngine.todaySessions,
            currentSession: session
        )

        // Daily summary
        DailySummaryView(
            sessions: sessionEngine.todaySessions,
            currentSession: session
        )
    }

    private func formattedTime(_ session: Session) -> String {
        let duration = now.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private func appBundleId(for appName: String) -> String? {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName })?
            .bundleIdentifier
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/TodayTabView.swift
git commit -m "feat: add TodayTabView with idle CTA and active session hero"
```

### Task 13: Create MainWindowView and Wire Up Window Scene

**Files:**
- Create: `TimeTracker/Views/Window/MainWindowView.swift`
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Write MainWindowView (Today tab only for now, other tabs as placeholders)**

```swift
import SwiftUI

enum AppTab: String, CaseIterable {
    case today = "Today"
    case calendar = "Calendar"
    case stats = "Stats"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .today: return "clock"
        case .calendar: return "calendar"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    let appState: AppState

    @State private var selectedTab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            Group {
                switch selectedTab {
                case .today:
                    if let engine = appState.sessionEngine {
                        TodayTabView(
                            sessionEngine: engine,
                            isTracking: engine.isTracking,
                            onStart: { intention in appState.startTracking(intention: intention) },
                            onStop: { appState.stopTracking() }
                        )
                    }
                case .calendar:
                    Text("Calendar — coming soon")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                case .stats:
                    Text("Stats — coming soon")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                case .settings:
                    Text("Settings — coming soon")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Mini player
            if let engine = appState.sessionEngine {
                MiniPlayerBar(
                    currentSession: engine.currentSession,
                    isTracking: engine.isTracking,
                    onStart: { appState.startTracking() },
                    onStop: { appState.stopTracking() }
                )
            }

            Divider()

            // Tab bar
            HStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(selectedTab == tab ? CategoryColors.accent : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Theme.background)
    }
}
```

- [ ] **Step 2: Add Window scene to TimeTrackerApp**

In `TimeTrackerApp.body`, add after the `MenuBarExtra`:

```swift
Window("TimeTracker", id: "main") {
    MainWindowView(appState: appState)
        .preferredColorScheme(appearanceScheme)
}
.defaultSize(width: 500, height: 700)
```

- [ ] **Step 3: Implement openMainWindow() in AppState**

```swift
func openMainWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    // The Window scene with id "main" will handle showing
    if let window = NSApp.windows.first(where: { $0.title == "TimeTracker" || $0.identifier?.rawValue == "main" }) {
        window.makeKeyAndOrderFront(nil)
    }
}
```

Note: For proper Window scene opening, we'll use `@Environment(\.openWindow)`:

In `TimeTrackerApp`, add the openWindow action to AppState via a method. Since `openWindow` is an environment value only available in SwiftUI views, we'll need a different approach. Use `NSApp.sendAction` or store a reference.

Simpler approach — add an `@Environment(\.openWindow)` in the MenuBarExtra content and pass it through:

In `TimeTrackerApp.body`, inside the MenuBarExtra content:
```swift
@Environment(\.openWindow) var openWindow
```

Wait — `@Environment` can't be used at the `App` level. Instead, pass the open action through the view:

Update `MenuBarView` to have `onOpenWindow` callback, and in the `MenuBarExtra` body:

```swift
MenuBarView(
    ...
    onOpenWindow: {
        // Open the window
        NSApp.setActivationPolicy(.regular)
        for window in NSApp.windows {
            if window.title == "TimeTracker" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    },
    ...
)
```

Actually, the cleanest approach for SwiftUI Window scenes is to use `OpenWindowAction`. Let's inject it from a helper view:

In `MainWindowView`, monitor window lifecycle:
```swift
.onDisappear {
    // When all main windows close, revert to accessory
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.title == "TimeTracker" }
        if !hasVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
```

For now, keep `openMainWindow()` simple and rely on the Window scene being present. The user can also use the Dock icon or Cmd+1 to switch. We'll refine this in a later task.

- [ ] **Step 4: Build and test**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Views/Window/MainWindowView.swift TimeTracker/TimeTrackerApp.swift
git commit -m "feat: add main window with tab shell, mini-player, and Today tab"
```

---

## Chunk 4: Calendar Tab

### Task 14: Create WeekStripView

**Files:**
- Create: `TimeTracker/Views/Window/WeekStripView.swift`

- [ ] **Step 1: Write WeekStripView**

```swift
import SwiftUI

struct WeekStripView: View {
    let selectedDate: Date
    let dailyTotals: [Date: TimeInterval]
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)
                Button(action: { onSelectDate(date) }) {
                    VStack(spacing: 2) {
                        Text(dayLabel(for: date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textPrimary)
                        Text(formattedHours(dailyTotals[calendar.startOfDay(for: date)] ?? 0))
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)
                        if isToday {
                            Circle()
                                .fill(CategoryColors.accent)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? CategoryColors.accent.opacity(0.08) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekDays: [Date] {
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private func dayLabel(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat -> map to our array
        let index = (weekday + 5) % 7
        return dayLabels[index]
    }

    private func formattedHours(_ interval: TimeInterval) -> String {
        let hours = interval / 3600
        return String(format: "%.1fh", hours)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/WeekStripView.swift
git commit -m "feat: add WeekStripView component"
```

### Task 15: Create VerticalTimelineView

**Files:**
- Create: `TimeTracker/Views/Window/VerticalTimelineView.swift`

- [ ] **Step 1: Write VerticalTimelineView**

```swift
import SwiftUI

struct VerticalTimelineView: View {
    let sessions: [Session]
    let isToday: Bool

    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour lines
                    VStack(spacing: 0) {
                        ForEach(displayHours, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 8) {
                                Text(formatHour(hour))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 40, alignment: .trailing)
                                VStack {
                                    Divider()
                                    Spacer()
                                }
                            }
                            .frame(height: hourHeight)
                            .id(hour)
                        }
                    }

                    // Session blocks
                    ForEach(sessions) { session in
                        sessionBlock(session)
                    }

                    // Current time indicator
                    if isToday {
                        currentTimeIndicator
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                if isToday {
                    let currentHour = max(0, calendar.component(.hour, from: now) - 1)
                    proxy.scrollTo(currentHour, anchor: .top)
                }
            }
            .onReceive(timer) { now = $0 }
        }
    }

    private var displayHours: [Int] {
        guard let first = sessions.first else {
            let currentHour = calendar.component(.hour, from: now)
            let start = max(0, currentHour - 2)
            return Array(start...min(23, currentHour + 4))
        }
        let startHour = calendar.component(.hour, from: first.startTime)
        let endHour: Int
        if isToday {
            endHour = min(23, calendar.component(.hour, from: now) + 1)
        } else if let last = sessions.last {
            endHour = min(23, calendar.component(.hour, from: last.endTime ?? last.startTime) + 1)
        } else {
            endHour = min(23, startHour + 8)
        }
        return Array(max(0, startHour)...endHour)
    }

    @ViewBuilder
    private func sessionBlock(_ session: Session) -> some View {
        let startOffset = offsetForTime(session.startTime)
        let endTime = session.endTime ?? (isToday ? now : session.startTime.addingTimeInterval(300))
        let height = max(20, offsetForTime(endTime) - startOffset)

        HStack {
            Spacer().frame(width: 52) // left gutter for time labels
            RoundedRectangle(cornerRadius: 4)
                .fill(CategoryColors.color(for: session.category))
                .frame(height: height)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(timeRange(session))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(4)
                }
            Spacer().frame(width: 8)
        }
        .offset(y: startOffset)
    }

    @ViewBuilder
    private var currentTimeIndicator: some View {
        let offset = offsetForTime(now)
        HStack(spacing: 4) {
            Text(formatTime(now))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(CategoryColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Rectangle()
                .fill(CategoryColors.accent)
                .frame(height: 1)
        }
        .offset(y: offset)
    }

    private func offsetForTime(_ time: Date) -> CGFloat {
        guard let firstHour = displayHours.first else { return 0 }
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hoursSinceStart = Double(comps.hour ?? 0) - Double(firstHour) + Double(comps.minute ?? 0) / 60.0
        return CGFloat(hoursSinceStart) * hourHeight
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }

    private func timeRange(_ session: Session) -> String {
        let start = formatTime(session.startTime)
        if let end = session.endTime {
            return "\(start) → \(formatTime(end))"
        }
        return "\(start) → Now"
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/VerticalTimelineView.swift
git commit -m "feat: add VerticalTimelineView component"
```

### Task 16: Create BackfillSheetView

**Files:**
- Create: `TimeTracker/Views/Window/BackfillSheetView.swift`

- [ ] **Step 1: Write BackfillSheetView**

```swift
import SwiftUI

struct BackfillSheetView: View {
    let date: Date
    let categories: [String]
    let onAdd: (String, Date, Date, String?) -> Void
    let onCancel: () -> Void

    @State private var selectedCategory: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intention = ""

    init(date: Date, categories: [String], onAdd: @escaping (String, Date, Date, String?) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.categories = categories
        self.onAdd = onAdd
        self.onCancel = onCancel
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let start = calendar.date(bySettingHour: max(0, hour - 1), minute: 0, second: 0, of: date) ?? date
        let end = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        _selectedCategory = State(initialValue: categories.first ?? "Other")
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Session")
                .font(.headline)

            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        HStack {
                            Circle()
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                        }
                        .tag(cat)
                    }
                }

                DatePicker("Start", selection: $startTime, displayedComponents: [.hourAndMinute])
                DatePicker("End", selection: $endTime, displayedComponents: [.hourAndMinute])

                TextField("Intention (optional)", text: $intention)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
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
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/BackfillSheetView.swift
git commit -m "feat: add BackfillSheetView for manual session entry"
```

### Task 17: Create CalendarTabView

**Files:**
- Create: `TimeTracker/Views/Window/CalendarTabView.swift`

- [ ] **Step 1: Write CalendarTabView**

```swift
import SwiftUI

struct CalendarTabView: View {
    let sessionEngine: SessionEngine
    let calendarReader: CalendarReader?
    let calendarWriter: CalendarWriter
    let categories: [String]

    @State private var selectedDate = Date()
    @State private var weekSessions: [Date: [Session]] = [:]
    @State private var showingBackfill = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Navigation
            HStack {
                Button(action: { moveWeek(-1) }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isCurrentWeek ? "Today" : weekLabel)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: { moveWeek(1) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Week strip
            WeekStripView(
                selectedDate: selectedDate,
                dailyTotals: dailyTotals,
                onSelectDate: { selectedDate = $0 }
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            // Overview bar
            HStack(spacing: 1) {
                ForEach(Array(selectedDaySessions.enumerated()), id: \.offset) { _, session in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: session.category))
                        .frame(height: 8)
                }
                if selectedDaySessions.isEmpty {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.trackFill)
                        .frame(height: 8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 24)

            // Vertical timeline
            VerticalTimelineView(
                sessions: selectedDaySessions,
                isToday: calendar.isDateInToday(selectedDate)
            )
            .frame(maxHeight: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            // Add button
            Button(action: { showingBackfill = true }) {
                ZStack {
                    Circle()
                        .fill(CategoryColors.accent)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(24)
        }
        .sheet(isPresented: $showingBackfill) {
            BackfillSheetView(
                date: selectedDate,
                categories: categories,
                onAdd: { category, start, end, intention in
                    addBackfillSession(category: category, start: start, end: end, intention: intention)
                    showingBackfill = false
                },
                onCancel: { showingBackfill = false }
            )
        }
        .task { await loadWeekData() }
        .onChange(of: selectedDate) { await loadWeekData() }
    }

    private var selectedDaySessions: [Session] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        // If today, merge calendar data with live engine data
        if calendar.isDateInToday(selectedDate) {
            var sessions = sessionEngine.todaySessions
            if let current = sessionEngine.currentSession {
                sessions.append(current)
            }
            return sessions.sorted { $0.startTime < $1.startTime }
        }
        return weekSessions[dayStart] ?? []
    }

    private var dailyTotals: [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for (date, sessions) in weekSessions {
            totals[date] = sessions.reduce(0) { $0 + $1.duration }
        }
        // Add today's live data
        let todayStart = calendar.startOfDay(for: Date())
        var todayTotal: TimeInterval = sessionEngine.todaySessions.reduce(0) { $0 + $1.duration }
        if let current = sessionEngine.currentSession {
            todayTotal += current.duration
        }
        totals[todayStart] = todayTotal
        return totals
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: selectedDate)
    }

    private func moveWeek(_ direction: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadWeekData() async {
        guard let reader = calendarReader else { return }
        weekSessions = reader.sessionsForWeek(containing: selectedDate)
    }

    private func addBackfillSession(category: String, start: Date, end: Date, intention: String?) {
        let session = Session(
            category: category,
            startTime: start,
            endTime: end,
            appsUsed: [],
            intention: intention
        )
        calendarWriter.createEvent(for: session)
        var mutable = session
        mutable.endTime = end
        calendarWriter.finalizeEvent(for: mutable)
        Task { await loadWeekData() }
    }
}
```

- [ ] **Step 2: Wire CalendarTabView into MainWindowView**

Replace the calendar placeholder in `MainWindowView`:
```swift
case .calendar:
    if let engine = appState.sessionEngine {
        CalendarTabView(
            sessionEngine: engine,
            calendarReader: appState.calendarReader,
            calendarWriter: appState.calendarWriter,
            categories: Array((try? CategoryConfigLoader.loadOrCreateDefault())?.categories.keys.sorted() ?? [])
        )
    }
```

- [ ] **Step 3: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/CalendarTabView.swift TimeTracker/Views/Window/MainWindowView.swift
git commit -m "feat: add Calendar tab with week strip, vertical timeline, and backfill"
```

---

## Chunk 5: Stats Tab

### Task 18: Create StatsTabView

**Files:**
- Create: `TimeTracker/Views/Window/StatsTabView.swift`

- [ ] **Step 1: Write StatsTabView**

```swift
import SwiftUI

struct StatsTabView: View {
    let sessionEngine: SessionEngine
    let calendarReader: CalendarReader?

    @State private var selectedDate = Date()
    @State private var weekSessions: [Date: [Session]] = [:]
    @State private var showNotesOnly = false

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Navigation
                HStack {
                    Button(action: { moveWeek(-1) }) {
                        Image(systemName: "chevron.left")
                            .frame(width: 28, height: 28)
                            .background(Theme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(isCurrentWeek ? "Today" : weekLabel)
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    Button(action: { moveWeek(1) }) {
                        Image(systemName: "chevron.right")
                            .frame(width: 28, height: 28)
                            .background(Theme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                // Week strip
                WeekStripView(
                    selectedDate: selectedDate,
                    dailyTotals: dailyTotals,
                    onSelectDate: { selectedDate = $0 }
                )

                // Filter
                HStack {
                    Spacer()
                    Toggle("Show notes only", isOn: $showNotesOnly)
                        .toggleStyle(.switch)
                        .font(.system(size: 11))
                }

                // Category Distribution
                categoryDistributionCard

                // By Intention
                intentionCard
            }
            .padding(24)
        }
        .task { await loadWeekData() }
        .onChange(of: selectedDate) { await loadWeekData() }
    }

    // MARK: - Category Distribution

    @ViewBuilder
    private var categoryDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Text("Category Distribution")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Header
            HStack {
                Text("CATEGORY")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("RATIO")
                    .frame(width: 50, alignment: .trailing)
                Text("CHANGE")
                    .frame(width: 50, alignment: .trailing)
                Text("TIME")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)

            Divider()

            ForEach(categoryStats, id: \.category) { stat in
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryColors.color(for: stat.category))
                                .frame(width: 6, height: 6)
                            Text(stat.category)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%.0f%%", stat.ratio * 100))
                            .font(.system(size: 12))
                            .frame(width: 50, alignment: .trailing)

                        Text(stat.changeText)
                            .font(.system(size: 12))
                            .foregroundStyle(stat.changeColor)
                            .frame(width: 50, alignment: .trailing)

                        Text(formatDuration(stat.totalTime))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 60, alignment: .trailing)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(CategoryColors.color(for: stat.category))
                            .frame(width: geo.size.width * stat.ratio, height: 3)
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - By Intention

    @ViewBuilder
    private var intentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Text("By Intention")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Header
            HStack {
                Text("INTENTION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("RATIO")
                    .frame(width: 50, alignment: .trailing)
                Text("SESSIONS")
                    .frame(width: 60, alignment: .trailing)
                Text("TIME")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)

            Divider()

            ForEach(intentionStats, id: \.intention) { stat in
                VStack(spacing: 4) {
                    HStack {
                        Text(stat.intention)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(stat.isNoIntention ? Theme.textTertiary : Theme.textPrimary)
                            .italic(stat.isNoIntention)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%.0f%%", stat.ratio * 100))
                            .font(.system(size: 12))
                            .frame(width: 50, alignment: .trailing)

                        Text("\(stat.sessionCount)")
                            .font(.system(size: 12))
                            .frame(width: 60, alignment: .trailing)

                        Text(formatDuration(stat.totalTime))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 60, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(stat.isNoIntention ? Theme.trackFill : CategoryColors.accent)
                            .frame(width: geo.size.width * stat.ratio, height: 3)
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Data

    private var allSessions: [Session] {
        var sessions: [Session] = []
        let todayStart = calendar.startOfDay(for: Date())

        for (date, daySessions) in weekSessions {
            if date != todayStart {
                sessions.append(contentsOf: daySessions)
            }
        }

        // Add today's live data
        sessions.append(contentsOf: sessionEngine.todaySessions)
        if let current = sessionEngine.currentSession {
            sessions.append(current)
        }

        if showNotesOnly {
            sessions = sessions.filter { $0.intention != nil }
        }

        return sessions
    }

    private struct CategoryStat {
        let category: String
        let totalTime: TimeInterval
        let ratio: Double
        let changeText: String
        let changeColor: Color
    }

    private var categoryStats: [CategoryStat] {
        var totals: [String: TimeInterval] = [:]
        for session in allSessions {
            totals[session.category, default: 0] += session.duration
        }
        let grandTotal = max(1, totals.values.reduce(0, +))
        return totals
            .map { CategoryStat(
                category: $0.key,
                totalTime: $0.value,
                ratio: $0.value / grandTotal,
                changeText: "—",
                changeColor: Theme.textTertiary
            )}
            .sorted { $0.totalTime > $1.totalTime }
    }

    private struct IntentionStat: Identifiable {
        let intention: String
        let totalTime: TimeInterval
        let ratio: Double
        let sessionCount: Int
        let isNoIntention: Bool
        var id: String { intention }
    }

    private var intentionStats: [IntentionStat] {
        var grouped: [String: (time: TimeInterval, count: Int)] = [:]
        for session in allSessions {
            let key = session.intention ?? "(no intention)"
            grouped[key, default: (0, 0)].time += session.duration
            grouped[key, default: (0, 0)].count += 1
        }
        let grandTotal = max(1, grouped.values.reduce(0) { $0 + $1.time })
        return grouped
            .map { IntentionStat(
                intention: $0.key,
                totalTime: $0.value.time,
                ratio: $0.value.time / grandTotal,
                sessionCount: $0.value.count,
                isNoIntention: $0.key == "(no intention)"
            )}
            .sorted { $0.totalTime > $1.totalTime }
    }

    private var dailyTotals: [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for (date, sessions) in weekSessions {
            totals[date] = sessions.reduce(0) { $0 + $1.duration }
        }
        let todayStart = calendar.startOfDay(for: Date())
        var todayTotal: TimeInterval = sessionEngine.todaySessions.reduce(0) { $0 + $1.duration }
        if let current = sessionEngine.currentSession { todayTotal += current.duration }
        totals[todayStart] = todayTotal
        return totals
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: selectedDate)
    }

    private func moveWeek(_ direction: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadWeekData() async {
        guard let reader = calendarReader else { return }
        weekSessions = reader.sessionsForWeek(containing: selectedDate)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Wire StatsTabView into MainWindowView**

Replace the stats placeholder:
```swift
case .stats:
    if let engine = appState.sessionEngine {
        StatsTabView(
            sessionEngine: engine,
            calendarReader: appState.calendarReader
        )
    }
```

- [ ] **Step 3: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/StatsTabView.swift TimeTracker/Views/Window/MainWindowView.swift
git commit -m "feat: add Stats tab with category distribution and intention breakdown"
```

---

## Chunk 6: Settings Tab

### Task 19: Create SettingsTabView

**Files:**
- Create: `TimeTracker/Views/Window/SettingsTabView.swift`

- [ ] **Step 1: Write SettingsTabView**

This is a two-pane sidebar settings view. It reuses the category editing logic from the existing `SettingsView` but restructures into sidebar sections.

```swift
import SwiftUI
import ServiceManagement

enum SettingsSection: String, CaseIterable {
    case general = "General"
    case notification = "Notification"
    case calendar = "Calendar"
    case category = "Category"
    case window = "Window"
    case browserTracking = "Browser Tracking"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notification: return "bell"
        case .calendar: return "calendar"
        case .category: return "tag"
        case .window: return "macwindow"
        case .browserTracking: return "globe"
        }
    }
}

struct SettingsTabView: View {
    @State private var config: CategoryConfig
    @State private var selectedSection: SettingsSection = .general
    @State private var showingSaveConfirmation = false
    let onSave: (CategoryConfig) -> Void

    // General settings
    @AppStorage("showMenuBarText") private var showMenuBarText = true
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("goalCategory") private var goalCategory = "Coding"
    @AppStorage("goalHours") private var goalHours = 0.0

    // Category editing state
    @State private var selectedCategory: String?
    @State private var newCategoryName = ""
    @State private var newAppBundleId = ""
    @State private var newRelatedBundleId = ""
    @State private var newURLPattern = ""

    init(config: CategoryConfig, onSave: @escaping (CategoryConfig) -> Void) {
        _config = State(initialValue: config)
        self.onSave = onSave
    }

    var body: some View {
        HSplitView {
            // Sidebar
            List(selection: $selectedSection) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, maxWidth: 180)

            // Detail
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSection {
                    case .general: generalSection
                    case .notification: notificationSection
                    case .calendar: calendarSection
                    case .category: categorySection
                    case .window: windowSection
                    case .browserTracking: browserTrackingSection
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                if showingSaveConfirmation {
                    Text("Saved!")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                Spacer()
                Button("Save") {
                    onSave(config)
                    showingSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaveConfirmation = false
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .tint(CategoryColors.accent)
            }
            .padding(12)
            .background(.bar)
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        Text("General").font(.title2.weight(.semibold))
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
            }
            Section("Menu Bar") {
                Toggle("Show timer in menu bar", isOn: $showMenuBarText)
            }
            Section("Focus Goal") {
                Picker("Category", selection: $goalCategory) {
                    ForEach(Array(config.categories.keys.sorted()), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                HStack {
                    Text("Daily target")
                    Stepper(value: $goalHours, in: 0...12, step: 0.5) {
                        Text(goalHours > 0 ? String(format: "%.1fh", goalHours) : "Off")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notification

    @ViewBuilder
    private var notificationSection: some View {
        Text("Notification").font(.title2.weight(.semibold))
        Text("Notification settings coming soon.")
            .foregroundStyle(.secondary)
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarSection: some View {
        Text("Calendar").font(.title2.weight(.semibold))
        Text("Calendar integration settings coming soon.")
            .foregroundStyle(.secondary)
    }

    // MARK: - Category

    @ViewBuilder
    private var categorySection: some View {
        Text("Category").font(.title2.weight(.semibold))

        // Category list + add/remove
        VStack(alignment: .leading, spacing: 8) {
            ForEach(config.categories.keys.sorted(), id: \.self) { name in
                HStack {
                    Circle()
                        .fill(CategoryColors.color(for: name))
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.system(size: 13))
                    Spacer()
                    if selectedCategory == name {
                        Image(systemName: "checkmark")
                            .foregroundStyle(CategoryColors.accent)
                    }
                }
                .padding(8)
                .background(selectedCategory == name ? CategoryColors.accent.opacity(0.08) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture { selectedCategory = name }
            }

            HStack(spacing: 4) {
                TextField("New category", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCategory() }
                Button(action: addCategory) { Image(systemName: "plus") }
                    .disabled(newCategoryName.isEmpty)
                Button(action: removeSelectedCategory) { Image(systemName: "minus") }
                    .disabled(selectedCategory == nil)
            }
        }

        // Selected category detail
        if let name = selectedCategory, let rule = config.categories[name] {
            Divider()
            Text(name).font(.headline)

            GroupBox("Primary Apps") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rule.apps, id: \.self) { app in
                        HStack {
                            Text(app).font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(action: { removeApp(app, from: name) }) {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 4) {
                        TextField("Bundle ID", text: $newAppBundleId)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addApp(to: name) }
                        Button("Add") { addApp(to: name) }.disabled(newAppBundleId.isEmpty)
                    }
                }.padding(4)
            }

            GroupBox("Related Apps") {
                VStack(alignment: .leading, spacing: 4) {
                    if let related = rule.related, !related.isEmpty {
                        ForEach(related, id: \.self) { app in
                            HStack {
                                Text(app).font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: { removeRelated(app, from: name) }) {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("None").font(.caption).foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 4) {
                        TextField("Bundle ID", text: $newRelatedBundleId)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addRelated(to: name) }
                        Button("Add") { addRelated(to: name) }.disabled(newRelatedBundleId.isEmpty)
                    }
                }.padding(4)
            }

            GroupBox("URL Patterns") {
                VStack(alignment: .leading, spacing: 4) {
                    if let patterns = rule.urlPatterns, !patterns.isEmpty {
                        ForEach(patterns, id: \.self) { pattern in
                            HStack {
                                Text(pattern).font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: { removeURLPattern(pattern, from: name) }) {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("None — add URL patterns for browser categorization").font(.caption).foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 4) {
                        TextField("e.g. github.com", text: $newURLPattern)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addURLPattern(to: name) }
                        Button("Add") { addURLPattern(to: name) }.disabled(newURLPattern.isEmpty)
                    }
                }.padding(4)
            }
        }
    }

    // MARK: - Window

    @ViewBuilder
    private var windowSection: some View {
        Text("Window").font(.title2.weight(.semibold))
        Form {
            Section {
                let isEnabled = SMAppService.mainApp.status == .enabled
                Toggle("Launch at login", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {}
                    }
                ))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Browser Tracking

    @ViewBuilder
    private var browserTrackingSection: some View {
        Text("Browser Tracking").font(.title2.weight(.semibold))
        Text("Configure URL-to-category mappings in each category's settings under the Category section.")
            .foregroundStyle(.secondary)
            .font(.callout)
    }

    // MARK: - Category Actions

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, config.categories[name] == nil else { return }
        config.categories[name] = CategoryRule(apps: [], related: nil, urlPatterns: nil)
        selectedCategory = name
        newCategoryName = ""
    }

    private func removeSelectedCategory() {
        guard let name = selectedCategory else { return }
        config.categories.removeValue(forKey: name)
        selectedCategory = config.categories.keys.sorted().first
    }

    private func addApp(to category: String) {
        let id = newAppBundleId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        config.categories[category]?.apps.append(id)
        newAppBundleId = ""
    }

    private func removeApp(_ app: String, from category: String) {
        config.categories[category]?.apps.removeAll { $0 == app }
    }

    private func addRelated(to category: String) {
        let id = newRelatedBundleId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        if config.categories[category]?.related == nil { config.categories[category]?.related = [] }
        config.categories[category]?.related?.append(id)
        newRelatedBundleId = ""
    }

    private func removeRelated(_ app: String, from category: String) {
        config.categories[category]?.related?.removeAll { $0 == app }
        if config.categories[category]?.related?.isEmpty == true { config.categories[category]?.related = nil }
    }

    private func addURLPattern(to category: String) {
        let pattern = newURLPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        if config.categories[category]?.urlPatterns == nil { config.categories[category]?.urlPatterns = [] }
        config.categories[category]?.urlPatterns?.append(pattern)
        newURLPattern = ""
    }

    private func removeURLPattern(_ pattern: String, from category: String) {
        config.categories[category]?.urlPatterns?.removeAll { $0 == pattern }
        if config.categories[category]?.urlPatterns?.isEmpty == true { config.categories[category]?.urlPatterns = nil }
    }
}
```

- [ ] **Step 2: Wire SettingsTabView into MainWindowView**

Replace the settings placeholder:
```swift
case .settings:
    if let currentConfig = try? CategoryConfigLoader.loadOrCreateDefault() {
        SettingsTabView(config: currentConfig) { newConfig in
            appState.saveConfig(newConfig)
        }
    }
```

Add `saveConfig` to AppState (extract from existing `openSettings`):
```swift
func saveConfig(_ newConfig: CategoryConfig) {
    do {
        try CategoryConfigLoader.save(newConfig)
        let engine = SessionEngine(config: newConfig, calendarWriter: calendarWriter)
        self.sessionEngine = engine
        activityMonitor.onActivity = { [weak engine] record in
            engine?.process(record)
        }
        activityMonitor.onIdle = { [weak engine] in
            engine?.handleIdle(at: Date())
        }
    } catch {
        print("Failed to save config: \(error)")
    }
}
```

- [ ] **Step 3: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/SettingsTabView.swift TimeTracker/Views/Window/MainWindowView.swift TimeTracker/TimeTrackerApp.swift
git commit -m "feat: add Settings tab with two-pane sidebar layout"
```

---

## Chunk 7: Launch Popup

### Task 20: Create Sunrise Animation

**Files:**
- Create: `TimeTracker/Views/Window/SunriseAnimation.swift`

- [ ] **Step 1: Write SunriseAnimation**

```swift
import SwiftUI

struct SunriseAnimation: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Outer glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [CategoryColors.accent.opacity(0.2), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 50)
                .offset(y: 5)
                .opacity(animate ? 0.4 : 0)

            // Rising arc (half circle)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xe8955a), CategoryColors.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70, height: 70)
                .clipShape(
                    Rectangle()
                        .offset(y: -35)
                        .size(width: 70, height: 35)
                )
                .offset(y: animate ? 0 : 20)
                .opacity(animate ? 1 : 0.3)

            // Horizon line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, CategoryColors.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: animate ? 80 : 0, height: 1.5)
                .offset(y: 0)
        }
        .frame(width: 100, height: 60)
        .onAppear {
            withAnimation(.easeOut(duration: 2)) {
                animate = true
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/Window/SunriseAnimation.swift
git commit -m "feat: add SunriseAnimation view"
```

### Task 21: Create Launch Popup

**Files:**
- Create: `TimeTracker/Views/LaunchPopupView.swift`
- Create: `TimeTracker/Views/LaunchPopupController.swift`
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Write LaunchPopupView**

```swift
import SwiftUI

struct LaunchPopupView: View {
    let onStart: (String?) -> Void
    let onDismiss: () -> Void

    @State private var intention = ""

    var body: some View {
        VStack(spacing: 16) {
            SunriseAnimation()
                .padding(.top, 8)

            Text("Ready to focus?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("What are you working on?")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            TextField("Intention (optional)", text: $intention)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onStart(intention.isEmpty ? nil : intention)
                }

            Button(action: { onStart(intention.isEmpty ? nil : intention) }) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button("Not now", action: onDismiss)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 300)
    }
}
```

- [ ] **Step 2: Write LaunchPopupController**

```swift
import AppKit
import SwiftUI

@MainActor
final class LaunchPopupController {
    private var panel: NSPanel?

    func show(onStart: @escaping (String?) -> Void, onDismiss: @escaping () -> Void) {
        let view = LaunchPopupView(
            onStart: { [weak self] intention in
                onStart(intention)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 340),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "TimeTracker"
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
```

- [ ] **Step 3: Integrate into AppState**

Add to AppState:
```swift
var launchPopupController = LaunchPopupController()
```

At the end of `setup()`, show the launch popup (only on cold launch):
```swift
// Show launch popup on cold launch
launchPopupController.show(
    onStart: { [weak self] intention in
        self?.startTracking(intention: intention)
    },
    onDismiss: { }
)
```

- [ ] **Step 4: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Views/LaunchPopupView.swift TimeTracker/Views/LaunchPopupController.swift TimeTracker/TimeTrackerApp.swift
git commit -m "feat: add launch popup with sunrise animation"
```

---

## Chunk 8: Final Integration & Polish

### Task 22: Window Lifecycle — Dock Visibility

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Add window lifecycle handling**

In `MainWindowView`, add `.onAppear` and track window visibility:

Actually, the cleanest approach is to observe `NSWindow` notifications in `AppState`:

```swift
func setupWindowObservers() {
    NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let window = notification.object as? NSWindow,
              window.title == "TimeTracker" else { return }
        MainActor.assumeIsolated {
            NSApp.setActivationPolicy(.regular)
        }
    }

    NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: nil,
        queue: .main
    ) { _ in
        MainActor.assumeIsolated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let hasMainWindow = NSApp.windows.contains { $0.isVisible && $0.title == "TimeTracker" }
                if !hasMainWindow {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
```

Call `setupWindowObservers()` at the end of `setup()`.

- [ ] **Step 2: Build and test**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/TimeTrackerApp.swift
git commit -m "feat: toggle Dock visibility based on main window lifecycle"
```

### Task 23: Update Menu Bar Title for Start/Stop Model

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Update updateMenuBarTitle()**

```swift
private func updateMenuBarTitle() {
    guard showMenuBarText else {
        menuBarTitle = "⏱"
        return
    }
    guard let engine = sessionEngine else {
        menuBarTitle = "⏱"
        return
    }
    if !engine.isTracking {
        menuBarTitle = "⏱"
        return
    }
    guard let session = engine.currentSession else {
        menuBarTitle = "⏱ Tracking..."
        return
    }
    let duration = Date().timeIntervalSince(session.startTime)
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    menuBarTitle = "⏱ \(hours):\(String(format: "%02d", minutes)) \(session.category)"
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/bareloved/Github/timetracker && swift build 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/TimeTrackerApp.swift
git commit -m "feat: update menu bar title for start/stop tracking model"
```

### Task 24: Run Full Test Suite and Final Build

- [ ] **Step 1: Run all tests**

Run: `cd /Users/bareloved/Github/timetracker && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 2: Fix any test failures**

Update any test that creates `ActivityRecord` without `pageURL` or `Session` without the new fields. These should already be handled by default parameter values, but verify.

- [ ] **Step 3: Full release build**

Run: `cd /Users/bareloved/Github/timetracker && swift build -c release 2>&1 | tail -10`
Expected: Build succeeded

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: fix remaining test and build issues"
```
