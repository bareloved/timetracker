# Focus Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an anti-interruption system that detects off-category app usage during tracked sessions and shows a focus reminder popup after a configurable threshold.

**Architecture:** New `FocusGuard` service evaluates each `ActivityRecord` against the current session's category. When the user drifts to an off-category app for longer than the threshold, a borderless `NSPanel` popup nudges them back. Distractions are logged and shown in the Today tab.

**Tech Stack:** SwiftUI, AppKit (NSPanel), `@Observable`, `@AppStorage`

**Spec:** `docs/superpowers/specs/2026-03-19-focus-guard-design.md`

---

### Task 1: Distraction Model

**Files:**
- Create: `TimeTracker/Models/Distraction.swift`

- [ ] **Step 1: Create the Distraction model**

```swift
import Foundation

struct Distraction: Identifiable, Equatable {
    let id: UUID
    let appName: String
    let bundleId: String
    let url: String?
    let startTime: Date
    var duration: TimeInterval
    var snoozed: Bool

    init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        url: String? = nil,
        startTime: Date,
        duration: TimeInterval = 0,
        snoozed: Bool = false
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.url = url
        self.startTime = startTime
        self.duration = duration
        self.snoozed = snoozed
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Models/Distraction.swift
git commit -m "feat(focus-guard): add Distraction model"
```

---

### Task 2: FocusGuard Service + Popup View + Controller

**Files:**
- Create: `TimeTracker/Services/FocusGuard.swift`
- Create: `TimeTracker/Views/FocusPopupView.swift`
- Create: `TimeTracker/Views/FocusPopupController.swift`

- [ ] **Step 1: Create FocusPopupView**

A borderless SwiftUI view matching the design system — warm/matte/earthy with terracotta accent. No title bar, no traffic lights.

```swift
import SwiftUI

struct FocusPopupView: View {
    let appName: String
    let elapsed: TimeInterval
    let snoozeMinutes: Int
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(CategoryColors.accent)
                .padding(.top, 4)

            // Title
            Text("Losing focus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            // Detail
            VStack(spacing: 4) {
                Text("You've been on **\(appName)**")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("for \(formattedElapsed)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)

            // Buttons
            VStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("Back to Work")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: onSnooze) {
                    Text("Snooze (\(snoozeMinutes) min)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private var formattedElapsed: String {
        let seconds = Int(elapsed)
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes) minutes"
        }
        return "\(seconds) seconds"
    }
}
```

- [ ] **Step 2: Create FocusPopupController**

Uses the same borderless NSPanel pattern as `LaunchPopupController` — transparent background, `.regularMaterial` rounded rect, floating level.

```swift
import SwiftUI
import AppKit

@MainActor
final class FocusPopupController {
    private var panel: NSPanel?

    func show(
        appName: String,
        elapsed: TimeInterval,
        snoozeMinutes: Int,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        let view = FocusPopupView(
            appName: appName,
            elapsed: elapsed,
            snoozeMinutes: snoozeMinutes,
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            },
            onSnooze: { [weak self] in
                onSnooze()
                self?.dismiss()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 240),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView:
            view
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
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

- [ ] **Step 3: Create the FocusGuard service**

```swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class FocusGuard {

    private(set) var offCategoryStart: Date?
    private(set) var offCategoryAppName: String?
    private(set) var offCategoryBundleId: String?
    private(set) var offCategoryURL: String?
    private(set) var snoozedUntil: Date?
    private(set) var distractions: [Distraction] = []
    private(set) var isPopupShowing = false
    /// Whether a distraction was logged for the current drift episode
    private var distractionLoggedForCurrentDrift = false

    @ObservationIgnored @AppStorage("focusGuardEnabled") var isEnabled = true
    @ObservationIgnored @AppStorage("focusThreshold") var focusThreshold: Double = 30
    @ObservationIgnored @AppStorage("snoozeDuration") var snoozeDuration: Double = 300

    private weak var sessionEngine: SessionEngine?
    private var categoryConfig: CategoryConfig?
    private var popupController: FocusPopupController?

    init(sessionEngine: SessionEngine?, categoryConfig: CategoryConfig?) {
        self.sessionEngine = sessionEngine
        self.categoryConfig = categoryConfig
    }

    func updateConfig(_ config: CategoryConfig?) {
        self.categoryConfig = config
    }

    // MARK: - Core Evaluation

    func evaluate(_ record: ActivityRecord) {
        guard isEnabled,
              let engine = sessionEngine,
              engine.isTracking,
              let session = engine.currentSession,
              let config = categoryConfig else {
            return
        }

        // Check snooze
        if let snoozedUntil, Date() < snoozedUntil {
            return
        } else if snoozedUntil != nil {
            self.snoozedUntil = nil
        }

        // Exempt Loom's own bundle ID
        if record.bundleId == Bundle.main.bundleIdentifier {
            resetDrift()
            return
        }

        // For browser apps, wait for the second callback with URL data
        if BrowserTracker.isBrowser(bundleId: record.bundleId) && record.pageURL == nil {
            return
        }

        let resolved = config.resolve(
            bundleId: record.bundleId,
            currentCategory: session.category,
            pageURL: record.pageURL
        )

        if resolved == session.category {
            resetDrift()
        } else {
            handleOffCategory(record: record)
        }
    }

    // MARK: - Off-Category Handling

    private func handleOffCategory(record: ActivityRecord) {
        if offCategoryStart == nil {
            offCategoryStart = Date()
            offCategoryAppName = record.appName
            offCategoryBundleId = record.bundleId
            offCategoryURL = record.pageURL
            distractionLoggedForCurrentDrift = false
        }

        guard let start = offCategoryStart else { return }
        let elapsed = Date().timeIntervalSince(start)

        if elapsed >= focusThreshold && !isPopupShowing {
            logDistraction(snoozed: false)
            showPopup(appName: offCategoryAppName ?? record.appName, elapsed: elapsed)
        }
    }

    private func resetDrift() {
        // Only update duration if a distraction was logged for this drift episode
        if distractionLoggedForCurrentDrift, let lastIndex = distractions.indices.last {
            distractions[lastIndex].duration = Date().timeIntervalSince(distractions[lastIndex].startTime)
        }
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        if isPopupShowing {
            dismissPopup()
        }
    }

    private func logDistraction(snoozed: Bool) {
        let distraction = Distraction(
            appName: offCategoryAppName ?? "Unknown",
            bundleId: offCategoryBundleId ?? "",
            url: offCategoryURL,
            startTime: offCategoryStart ?? Date(),
            duration: 0,
            snoozed: snoozed
        )
        distractions.append(distraction)
        distractionLoggedForCurrentDrift = true
    }

    // MARK: - Popup

    private func showPopup(appName: String, elapsed: TimeInterval) {
        isPopupShowing = true
        let controller = FocusPopupController()
        let snoozeMinutes = Int(snoozeDuration / 60)
        controller.show(
            appName: appName,
            elapsed: elapsed,
            snoozeMinutes: snoozeMinutes,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSnooze: { [weak self] in
                self?.handleSnooze()
            }
        )
        self.popupController = controller
    }

    func dismissPopup() {
        popupController?.dismiss()
        popupController = nil
        isPopupShowing = false
    }

    private func handleDismiss() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        isPopupShowing = false
        popupController = nil
    }

    private func handleSnooze() {
        snoozedUntil = Date().addingTimeInterval(snoozeDuration)
        if let lastIndex = distractions.indices.last {
            distractions[lastIndex].snoozed = true
        }
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        isPopupShowing = false
        popupController = nil
    }

    // MARK: - Reset

    func reset() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        snoozedUntil = nil
        distractions = []
        distractionLoggedForCurrentDrift = false
        dismissPopup()
    }

    func resetDriftTimer() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        if isPopupShowing {
            dismissPopup()
        }
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Services/FocusGuard.swift TimeTracker/Views/FocusPopupView.swift TimeTracker/Views/FocusPopupController.swift
git commit -m "feat(focus-guard): add FocusGuard service with popup view and controller"
```

---

### Task 3: Wire FocusGuard into AppState

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Add FocusGuard property to AppState**

After line 66 (`var launchPopupController = LaunchPopupController()`), add:

```swift
var focusGuard: FocusGuard?
```

- [ ] **Step 2: Initialize FocusGuard in setup()**

After the line `self.sessionEngine = engine` (line 100), add:

```swift
let guard_ = FocusGuard(sessionEngine: engine, categoryConfig: config)
self.focusGuard = guard_
```

- [ ] **Step 3: Wire evaluate into onActivity callback**

Change the existing `activityMonitor.onActivity` callback (line 102-104) from:

```swift
activityMonitor.onActivity = { [weak engine] record in
    engine?.process(record)
}
```

To:

```swift
activityMonitor.onActivity = { [weak engine, weak guard_] record in
    engine?.process(record)
    guard_?.evaluate(record)
}
```

- [ ] **Step 4: Wire FocusGuard reset into start/stop tracking**

In `startTracking()` (around line 150), add `focusGuard?.reset()` before the existing code:

```swift
func startTracking(category: String, intention: String? = nil) {
    focusGuard?.reset()
    sessionEngine?.startSession(category: category, intention: intention)
    activityMonitor.start()
}
```

In `stopTracking()` (around line 166), add `focusGuard?.reset()`:

```swift
func stopTracking() {
    focusGuard?.reset()
    sessionEngine?.stopSession()
    activityMonitor.stop()
}
```

- [ ] **Step 5: Wire FocusGuard reset into idle handler**

In the `activityMonitor.onIdle` callback (line 105-107), add focus guard reset:

```swift
activityMonitor.onIdle = { [weak engine, weak guard_] in
    engine?.handleIdle(at: Date())
    guard_?.reset()
}
```

- [ ] **Step 6: Wire sleep/wake to FocusGuard**

In `setupSleepWakeHandlers()`, in the `didWakeNotification` handler (around line 207-216), add focus guard drift timer reset:

```swift
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated {
        guard let self, self.sessionEngine?.isTracking == true else { return }
        self.focusGuard?.resetDriftTimer()
        self.activityMonitor.resume()
    }
}
```

Note: `setupSleepWakeHandlers` currently takes `engine: SessionEngine` as a parameter. You'll need to also pass `focusGuard` or capture it via `self`. The cleanest approach is to capture `[weak self]` and access `self.focusGuard` (which is already done in the wake handler — just add the `resetDriftTimer` call).

- [ ] **Step 7: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 8: Commit**

```bash
git add TimeTracker/TimeTrackerApp.swift
git commit -m "feat(focus-guard): wire FocusGuard into AppState"
```

---

### Task 4: Handle Category Change Mid-Session

**Files:**
- Modify: `TimeTracker/Views/Window/TodayTabView.swift`

The spec requires that when the user changes the session category mid-session, the focus guard dismisses any showing popup and resets the drift timer. The `TodayTabView` calls `sessionEngine.updateCategory(cat)` — we need to also call `focusGuard?.resetDriftTimer()` there.

- [ ] **Step 1: Add focusGuard parameter to TodayTabView** (will be used in Task 5 too)

Add a new parameter to `TodayTabView` (after `let onStop: () -> Void`):

```swift
let focusGuard: FocusGuard?
```

- [ ] **Step 2: Wire resetDriftTimer on category change**

In the `activeView` function's category picker Menu (around line 129), change the button action from:

```swift
Button(action: { sessionEngine.updateCategory(cat) }) {
```

To:

```swift
Button(action: {
    sessionEngine.updateCategory(cat)
    focusGuard?.resetDriftTimer()
}) {
```

- [ ] **Step 3: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Will fail because MainWindowView doesn't pass `focusGuard` yet — that's expected at this stage.

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/TodayTabView.swift
git commit -m "feat(focus-guard): reset drift timer on category change"
```

---

### Task 5: Settings UI

**Files:**
- Modify: `TimeTracker/Views/Window/SettingsTabView.swift`

- [ ] **Step 1: Add focusGuard case to SettingsSection enum**

In the `SettingsSection` enum (line 5-11), add `focusGuard` after `general`:

```swift
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case focusGuard = "Focus Guard"
    case notification = "Notification"
    case calendar = "Calendar"
    case category = "Category"
    case window = "Window"
    case browser = "Browser Tracking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .focusGuard: return "eye.trianglebadge.exclamationmark"
        case .notification: return "bell"
        case .calendar: return "calendar"
        case .category: return "tag"
        case .window: return "macwindow"
        case .browser: return "globe"
        }
    }
}
```

- [ ] **Step 2: Add @AppStorage properties for focus guard settings**

Add these after the existing `@AppStorage` properties in `SettingsTabView` (around line 41):

```swift
@AppStorage("focusGuardEnabled") private var focusGuardEnabled = true
@AppStorage("focusThreshold") private var focusThreshold: Double = 30
@AppStorage("snoozeDuration") private var snoozeDuration: Double = 300
```

- [ ] **Step 3: Add focus guard section to the switch in body**

In the `switch selectedSection` block (around line 107), add the `focusGuard` case:

```swift
case .focusGuard:
    focusGuardSection
```

- [ ] **Step 4: Create the focusGuardSection view**

Add this computed property after the `generalSection`:

```swift
// MARK: - Focus Guard

@ViewBuilder
private var focusGuardSection: some View {
    Text("Focus Guard")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(Theme.textPrimary)

    settingsCard("Focus Guard") {
        VStack(spacing: 10) {
            HStack {
                Text("Enabled")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: $focusGuardEnabled)
                    .toggleStyle(.switch)
                    .tint(CategoryColors.accent)
                    .labelsHidden()
            }

            if focusGuardEnabled {
                Divider()

                HStack {
                    Text("Distraction threshold")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(focusThreshold))s")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                    Slider(value: $focusThreshold, in: 15...120, step: 5)
                        .frame(width: 140)
                        .tint(CategoryColors.accent)
                }

                Divider()

                HStack {
                    Text("Snooze duration")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: $snoozeDuration) {
                        Text("2 min").tag(120.0)
                        Text("5 min").tag(300.0)
                        Text("10 min").tag(600.0)
                        Text("20 min").tag(1200.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 240)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add TimeTracker/Views/Window/SettingsTabView.swift
git commit -m "feat(focus-guard): add Focus Guard settings section"
```

---

### Task 6: Distraction Count in Today Tab + Wire MainWindowView

**Files:**
- Modify: `TimeTracker/Views/Window/TodayTabView.swift`
- Modify: `TimeTracker/Views/Window/MainWindowView.swift`

- [ ] **Step 1: Show distraction count in activeView**

In the `activeView` function, after the time range pill `HStack` (around line 218) and before the `Spacer()`, add:

```swift
// Distraction count
if let guard_ = focusGuard, !guard_.distractions.isEmpty {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 10))
        Text("\(guard_.distractions.count) distraction\(guard_.distractions.count == 1 ? "" : "s")")
            .font(.system(size: 11))
    }
    .foregroundStyle(Theme.textTertiary)
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(Theme.backgroundSecondary, in: Capsule())
}
```

- [ ] **Step 2: Update MainWindowView to pass focusGuard**

In `MainWindowView.swift`, update the `TodayTabView` initialization (around line 33) to pass `focusGuard`:

```swift
TodayTabView(
    sessionEngine: engine,
    isTracking: engine.isTracking,
    categories: Array((appState.categoryConfig?.categories.keys.sorted()) ?? []),
    onStart: { category, intention in
        appState.startTracking(category: category, intention: intention)
    },
    onStop: { appState.stopTracking() },
    focusGuard: appState.focusGuard
)
```

- [ ] **Step 3: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/Window/TodayTabView.swift TimeTracker/Views/Window/MainWindowView.swift
git commit -m "feat(focus-guard): show distraction count in Today tab"
```

---

### Task 7: Build + Smoke Test

- [ ] **Step 1: Full build**

Run: `swift build -c release 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 2: Run tests**

Run: `swift test 2>&1 | tail -20`
Expected: All existing tests pass

- [ ] **Step 3: Smoke test the app**

Run: `./run.sh`

Manual verification checklist:
1. Open Settings → confirm "Focus Guard" section appears with toggle, threshold slider, snooze picker
2. Start a session (e.g., "Coding")
3. Switch to an off-category app (e.g., Safari with no matching URL pattern)
4. Wait 30 seconds → confirm popup appears with "Losing focus" message
5. Click "Back to Work" → confirm popup dismisses
6. Drift again → wait 30s → popup appears again
7. Click "Snooze (5 min)" → confirm popup dismisses and doesn't reappear for 5 min
8. In Today tab → confirm distraction count shows

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix(focus-guard): address smoke test issues"
```
