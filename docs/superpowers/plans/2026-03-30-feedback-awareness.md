# Feedback & Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Loom's state visible at every level — menu bar reflects tracking state, in-app toasts confirm actions and surface errors, skeleton loaders replace misleading empty states, and macOS notifications alert on critical automatic events.

**Architecture:** A new `ToastManager` observable class manages the toast queue. Menu bar state is driven by a new enum on `AppState`. Skeleton loading is a reusable view gated by an `isLoading` flag on each tab. Notifications extend the existing `ReminderManager`. All wiring happens in `AppState` callbacks.

**Tech Stack:** SwiftUI, UserNotifications, @Observable, SF Symbols

---

### Task 1: ToastManager Service

**Files:**
- Create: `Loom/Services/ToastManager.swift`

- [ ] **Step 1: Create ToastManager with types and queue logic**

```swift
import Foundation
import SwiftUI

enum ToastType {
    case success
    case info
    case warning
    case error
}

struct Toast: Identifiable {
    let id = UUID()
    let type: ToastType
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?
}

@Observable
@MainActor
final class ToastManager {
    private(set) var visibleToasts: [Toast] = []
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    func show(_ type: ToastType, message: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        let toast = Toast(type: type, message: message, action: action, actionLabel: actionLabel)

        // Max 2 visible — remove oldest if at limit
        if visibleToasts.count >= 2 {
            let oldest = visibleToasts[0]
            dismiss(oldest.id)
        }

        visibleToasts.append(toast)

        // Auto-dismiss success and info after 3 seconds
        if type == .success || type == .info {
            let toastId = toast.id
            dismissTasks[toastId] = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                dismiss(toastId)
            }
        }
    }

    func dismiss(_ id: UUID) {
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
        visibleToasts.removeAll { $0.id == id }
    }
}
```

- [ ] **Step 2: Build and verify no errors**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Loom/Services/ToastManager.swift
git commit -m "feat: add ToastManager service for in-app feedback"
```

---

### Task 2: ToastOverlayView

**Files:**
- Create: `Loom/Views/ToastOverlayView.swift`

- [ ] **Step 1: Create the toast overlay view**

```swift
import SwiftUI

struct ToastOverlayView: View {
    let toastManager: ToastManager

    var body: some View {
        VStack(spacing: 6) {
            ForEach(toastManager.visibleToasts) { toast in
                ToastBanner(toast: toast, onDismiss: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        toastManager.dismiss(toast.id)
                    }
                })
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.25), value: toastManager.visibleToasts.map(\.id))
    }
}

private struct ToastBanner: View {
    let toast: Toast
    let onDismiss: () -> Void

    private var backgroundColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.18, green: 0.29, blue: 0.18)
        case .info: return Color(red: 0.18, green: 0.23, blue: 0.29)
        case .warning: return Color(red: 0.29, green: 0.23, blue: 0.18)
        case .error: return Color(red: 0.29, green: 0.18, blue: 0.18)
        }
    }

    private var borderColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.24, green: 0.42, blue: 0.24)
        case .info: return Color(red: 0.24, green: 0.35, blue: 0.49)
        case .warning: return Color(red: 0.49, green: 0.35, blue: 0.24)
        case .error: return Color(red: 0.49, green: 0.24, blue: 0.24)
        }
    }

    private var textColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.78, green: 0.90, blue: 0.79)
        case .info: return Color(red: 0.73, green: 0.87, blue: 0.98)
        case .warning: return Color(red: 1.0, green: 0.88, blue: 0.70)
        case .error: return Color(red: 1.0, green: 0.80, blue: 0.82)
        }
    }

    private var iconName: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(textColor)

            Text(toast.message)
                .font(.system(size: 12))
                .foregroundStyle(textColor)

            Spacer()

            if let action = toast.action, let label = toast.actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(textColor)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            if toast.type == .warning || toast.type == .error {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Loom/Views/ToastOverlayView.swift
git commit -m "feat: add ToastOverlayView banner component"
```

---

### Task 3: Wire ToastManager into MainWindowView

**Files:**
- Modify: `Loom/LoomApp.swift` (add `toastManager` property to `AppState`)
- Modify: `Loom/Views/Window/MainWindowView.swift` (add toast overlay)

- [ ] **Step 1: Add toastManager to AppState**

In `Loom/LoomApp.swift`, add the property to `AppState` after `var reminderManager: ReminderManager?`:

```swift
    var toastManager = ToastManager()
```

- [ ] **Step 2: Add toast overlay to MainWindowView**

In `Loom/Views/Window/MainWindowView.swift`, wrap the existing VStack body content with an overlay. Replace the body:

```swift
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
                            categories: appState.categoryConfig?.orderedCategoryNames ?? [],
                            onStart: { category, intention in
                                appState.startTracking(category: category, intention: intention)
                            },
                            onStop: { appState.stopTracking() },
                            focusGuard: appState.focusGuard
                        )
                    } else {
                        Text("Starting up...")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .sessions:
                    if let engine = appState.sessionEngine {
                        SessionsTabView(
                            sessionEngine: engine,
                            syncEngine: appState.syncEngine,
                            categories: appState.categoryConfig?.orderedCategoryNames ?? []
                        )
                    }
                case .calendar:
                    if let engine = appState.sessionEngine {
                        CalendarTabView(
                            sessionEngine: engine,
                            calendarReader: appState.calendarReader,
                            calendarWriter: appState.calendarWriter,
                            syncEngine: appState.syncEngine,
                            categories: (try? CategoryConfigLoader.loadOrCreateDefault())?.orderedCategoryNames ?? []
                        )
                    }
                case .stats:
                    if let engine = appState.sessionEngine {
                        StatsTabView(
                            sessionEngine: engine,
                            calendarReader: appState.calendarReader,
                            syncEngine: appState.syncEngine
                        )
                    }
                case .settings:
                    if let currentConfig = try? CategoryConfigLoader.loadOrCreateDefault() {
                        SettingsTabView(config: currentConfig, calendarWriter: appState.calendarWriter, appState: appState) { newConfig in
                            appState.saveConfig(newConfig)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Mini player bar
            if let engine = appState.sessionEngine {
                MiniPlayerBar(
                    sessionEngine: engine,
                    onStart: { appState.showSessionPicker() },
                    onStop: { appState.stopTracking() }
                )
            }

            Divider()

            // Bottom tab bar
            HStack(spacing: 0) {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .top) {
            ToastOverlayView(toastManager: appState.toastManager)
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Theme.background)
        .onAppear {
            appState.openWindowAction = openWindow
        }
    }
```

- [ ] **Step 3: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Loom/LoomApp.swift Loom/Views/Window/MainWindowView.swift
git commit -m "feat: wire ToastManager into AppState and MainWindowView"
```

---

### Task 4: Menu Bar State Enum

**Files:**
- Modify: `Loom/LoomApp.swift`

- [ ] **Step 1: Add MenuBarState enum and property to AppState**

In `Loom/LoomApp.swift`, add the enum before `class AppState`:

```swift
enum MenuBarState {
    case tracking
    case stoppedIdle
    case stoppedSleep
    case inactive
}
```

Add properties to `AppState` after `var menuBarIconSystemName`:

```swift
    var menuBarState: MenuBarState = .inactive
    var syncError: Bool = false
```

- [ ] **Step 2: Update updateMenuBarTitle() to use menuBarState**

Replace the `updateMenuBarTitle()` method in `AppState`:

```swift
    private func updateMenuBarTitle() {
        let icon = MenuBarIcon.named(menuBarIconName)

        // Icon fill based on state
        switch menuBarState {
        case .tracking:
            menuBarIconSystemName = icon.activeIcon
        case .stoppedIdle, .stoppedSleep, .inactive:
            menuBarIconSystemName = icon.idleIcon
        }

        // Text based on state
        switch menuBarState {
        case .tracking:
            if activityMonitor.isPaused {
                menuBarTitle = showMenuBarText ? "Paused" : ""
                return
            }
            guard showMenuBarText, let session = sessionEngine?.currentSession else {
                menuBarTitle = ""
                return
            }
            let duration = Date().timeIntervalSince(session.startTime)
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let timeStr = "\(hours):\(String(format: "%02d", minutes)) \(session.category)"
            menuBarTitle = syncError ? "\(timeStr) ⚠" : timeStr
        case .stoppedIdle:
            menuBarTitle = showMenuBarText ? "Stopped (idle)" : ""
        case .stoppedSleep:
            menuBarTitle = showMenuBarText ? "Stopped (sleep)" : ""
        case .inactive:
            menuBarTitle = ""
        }
    }
```

- [ ] **Step 3: Set menuBarState in startTracking and stopTracking**

In `startTracking`, add at the top of the method body:

```swift
        menuBarState = .tracking
        syncError = false
```

In `stopTracking`, add at the end of the method body (before the closing brace):

```swift
        menuBarState = .inactive
```

- [ ] **Step 4: Set menuBarState in onIdle callback**

In `setup()`, inside `activityMonitor.onIdle`, add after `guard_?.reset()`:

```swift
            self?.menuBarState = .stoppedIdle
```

- [ ] **Step 5: Set menuBarState in sleep wake handler**

In `setupSleepWakeHandlers`, inside the `if sleepDuration >= 300` block, add after `engine.handleIdle(at: slept)`:

```swift
                        self.menuBarState = .stoppedSleep
```

- [ ] **Step 6: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
git add Loom/LoomApp.swift
git commit -m "feat: add menu bar state enum reflecting tracking/idle/sleep/inactive"
```

---

### Task 5: SkeletonLoadingView Component

**Files:**
- Create: `Loom/Views/SkeletonLoadingView.swift`

- [ ] **Step 1: Create the skeleton loading view**

```swift
import SwiftUI

struct SkeletonLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.trackFill)
                    .frame(height: 60)
                    .opacity(isAnimating ? 0.6 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Loom/Views/SkeletonLoadingView.swift
git commit -m "feat: add SkeletonLoadingView component"
```

---

### Task 6: Add Skeleton Loading to SessionsTabView

**Files:**
- Modify: `Loom/Views/Window/SessionsTabView.swift`

- [ ] **Step 1: Add isLoading state**

Add after `@State private var editingSession: Session?`:

```swift
    @State private var isLoading = false
```

- [ ] **Step 2: Replace empty state / session list with loading-aware logic**

Replace the `// Session list or empty state` section (the `if selectedDaySessions.isEmpty` block through the end of the `ScrollView` closing brace) with:

```swift
            // Session list
            if isLoading {
                SkeletonLoadingView()
                Spacer()
            } else if selectedDaySessions.isEmpty {
                Spacer()
                Text("No sessions")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 8) {
                        ForEach(selectedDaySessions) { session in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedSessionId == session.id {
                                        expandedSessionId = nil
                                    } else {
                                        expandedSessionId = session.id
                                    }
                                }
                            }) {
                                SessionCardView(
                                    session: session,
                                    isExpanded: expandedSessionId == session.id,
                                    onEdit: { session in
                                        editingSession = session
                                    },
                                    onDelete: { _ in },
                                    onConfirmDelete: { session in
                                        deleteSession(session)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
```

- [ ] **Step 3: Update loadWeekSessions to set isLoading**

Replace the `loadWeekSessions` method:

```swift
    private func loadWeekSessions() {
        Task {
            guard let syncEngine else { weekSessions = [:]; return }
            isLoading = true
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? selectedDate
            let fetched = await syncEngine.fetchSessions(from: weekStart, to: weekEnd)
            var grouped: [Date: [Session]] = [:]
            for session in fetched {
                let dayStart = calendar.startOfDay(for: session.startTime)
                grouped[dayStart, default: []].append(session)
            }
            weekSessions = grouped
            isLoading = false
        }
    }
```

- [ ] **Step 4: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Loom/Views/Window/SessionsTabView.swift
git commit -m "feat: add skeleton loading state to SessionsTabView"
```

---

### Task 7: Add Skeleton Loading to CalendarTabView

**Files:**
- Modify: `Loom/Views/Window/CalendarTabView.swift`

- [ ] **Step 1: Add isLoading state**

Add after `@State private var editingSession: Session?`:

```swift
    @State private var isLoading = false
```

- [ ] **Step 2: Wrap the timeline content with loading check**

Replace the block starting from `// Full-day timeline bar` through the `VerticalTimelineView` closing paren (lines 122-141) with:

```swift
                if isLoading {
                    SkeletonLoadingView()
                    Spacer()
                } else {
                    // Full-day timeline bar
                    DayTimelineBar(
                        sessions: selectedDaySessions,
                        date: selectedDate,
                        isToday: calendar.isDateInToday(selectedDate),
                        visibleHourRange: visibleHourRange
                    )
                    .padding(.horizontal, 40)
                    .padding(.vertical, 6)

                    // Timeline
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
                }
```

- [ ] **Step 3: Update loadWeekSessions to set isLoading**

Replace the `loadWeekSessions` method:

```swift
    private func loadWeekSessions() {
        Task {
            guard let syncEngine else {
                weekSessions = [:]
                loadBackgroundEvents()
                return
            }
            isLoading = true
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? selectedDate
            let sessions = await syncEngine.fetchSessions(from: weekStart, to: weekEnd)
            var grouped: [Date: [Session]] = [:]
            for session in sessions {
                let dayStart = calendar.startOfDay(for: session.startTime)
                grouped[dayStart, default: []].append(session)
            }
            weekSessions = grouped
            isLoading = false
            loadBackgroundEvents()
        }
    }
```

- [ ] **Step 4: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Loom/Views/Window/CalendarTabView.swift
git commit -m "feat: add skeleton loading state to CalendarTabView"
```

---

### Task 8: Extend ReminderManager with All Notification Methods

**Files:**
- Modify: `Loom/Services/ReminderManager.swift`

- [ ] **Step 1: Add the 4 new notification methods**

Add after the existing `notifySessionStoppedDueToIdle` method:

```swift
    func notifySessionStoppedDueToSleep(category: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session stopped"
        content.body = "Your \(category) session was stopped — Mac went to sleep"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-sleep-stop-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send sleep stop notification: \(error)")
            }
        }
    }

    func notifyCalendarWriteFailed() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session not saved"
        content.body = "Couldn't save your session to calendar"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-cal-fail-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send calendar failure notification: \(error)")
            }
        }
    }

    func notifySyncFailed() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sync issue"
        content.body = "Couldn't sync your session — check your connection"
        content.categoryIdentifier = "SESSION_REMINDER"
        // Silent — no sound

        let request = UNNotificationRequest(
            identifier: "loom-sync-fail-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send sync failure notification: \(error)")
            }
        }
    }

    func notifyRemoteSessionStarted(category: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tracking from another device"
        content.body = "A \(category) session started from iPhone — now tracking on Mac"
        content.categoryIdentifier = "SESSION_REMINDER"
        // Silent — no sound

        let request = UNNotificationRequest(
            identifier: "loom-remote-start-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send remote session notification: \(error)")
            }
        }
    }
```

- [ ] **Step 2: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Loom/Services/ReminderManager.swift
git commit -m "feat: add sleep, calendar, sync, and remote session notifications"
```

---

### Task 9: Wire Notifications and Toasts into AppState

**Files:**
- Modify: `Loom/LoomApp.swift`

- [ ] **Step 1: Wire sleep stop notification**

In `setupSleepWakeHandlers`, inside the `if sleepDuration >= 300` block, add after the `self.menuBarState = .stoppedSleep` line added in Task 4:

```swift
                        let category = engine.currentSession?.category ?? "Unknown"
                        self.reminderManager?.notifySessionStoppedDueToSleep(category: category)
                        self.toastManager.show(.warning, message: "Session stopped — Mac went to sleep")
```

Note: capture `category` before `engine.handleIdle(at: slept)` since that clears `currentSession`. Move the category capture to before the `handleIdle` call:

The full block should read:

```swift
                    if sleepDuration >= 300 {
                        // Long sleep — end session and show idle return panel
                        let category = engine.currentSession?.category ?? "Unknown"
                        engine.handleIdle(at: slept)
                        self.menuBarState = .stoppedSleep
                        self.reminderManager?.notifySessionStoppedDueToSleep(category: category)
                        self.toastManager.show(.warning, message: "Session stopped — Mac went to sleep")
                        self.activityMonitor.markIdle()
                        self.activityMonitor.resume()
                    }
```

- [ ] **Step 2: Wire idle stop toast**

In `setup()`, inside `activityMonitor.onIdle`, add after `self?.menuBarState = .stoppedIdle`:

```swift
            self?.toastManager.show(.warning, message: "Session stopped due to inactivity")
```

- [ ] **Step 3: Wire session stop toast**

In `stopTracking()`, add at the end before `menuBarState = .inactive`:

```swift
        toastManager.show(.success, message: "Session saved")
```

- [ ] **Step 4: Wire remote session notification**

In `checkRemoteSession()`, inside the `if let remoteSession` block, add before `startTracking`:

```swift
                reminderManager?.notifyRemoteSessionStarted(category: remoteSession.category)
                toastManager.show(.info, message: "Tracking \(remoteSession.category) from another device")
```

- [ ] **Step 5: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Loom/LoomApp.swift
git commit -m "feat: wire notifications and toasts for idle, sleep, remote session"
```

---

### Task 10: Wire Calendar Write Failure and Sync Error Feedback

**Files:**
- Modify: `Loom/Services/CalendarWriter.swift`
- Modify: `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift`
- Modify: `Loom/LoomApp.swift`

- [ ] **Step 1: Add onWriteError callback to CalendarWriter**

In `CalendarWriter`, add a callback property after `@ObservationIgnored @AppStorage("timeRounding") var timeRounding`:

```swift
    var onWriteError: (() -> Void)?
```

- [ ] **Step 2: Fire the callback in catch blocks**

In `createEvent(for:)`, in the catch block (after `print("Failed to create event: \(error)")`), add:

```swift
            onWriteError?()
```

In `finalizeEvent(for:)`, in the catch block (after `print("Failed to finalize event: \(error)")`), add:

```swift
            onWriteError?()
```

- [ ] **Step 3: Add onSyncError callback to SyncEngine**

In `SyncEngine`, add a callback property after `private var heartbeatTimer: Timer?`:

```swift
    public var onSyncError: (() -> Void)?
```

- [ ] **Step 4: Fire onSyncError in key catch blocks**

In `publishSessionStart`, in the catch block, add after the print:

```swift
            onSyncError?()
```

In `publishSessionStop`, in the catch block, add after the print:

```swift
            onSyncError?()
```

In `publishSessionUpdate`, in the catch block, add after the print:

```swift
            onSyncError?()
```

- [ ] **Step 5: Wire callbacks in AppState.setup()**

In `setup()`, add after `let sync = SyncEngine(source: "mac")` and before `self.syncEngine = sync`:

```swift
        sync.onSyncError = { [weak self] in
            self?.syncError = true
            self?.reminderManager?.notifySyncFailed()
            self?.toastManager.show(.error, message: "Couldn't sync — check your connection", action: { [weak self] in
                self?.syncError = false
            }, actionLabel: "Dismiss")
        }
```

Add after `let engine = SessionEngine(calendarWriter: calendarWriter, syncEngine: sync)` and before `self.sessionEngine = engine`:

```swift
        calendarWriter.onWriteError = { [weak self] in
            self?.reminderManager?.notifyCalendarWriteFailed()
            self?.toastManager.show(.error, message: "Session couldn't be saved to calendar")
        }
```

- [ ] **Step 6: Clear syncError on successful sync**

In `checkRemoteSession()`, add after `await syncEngine.fetchActiveState()`:

```swift
        // Clear sync error on successful fetch
        syncError = false
```

- [ ] **Step 7: Build and verify**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
git add Loom/Services/CalendarWriter.swift LoomKit/Sources/LoomKit/Sync/SyncEngine.swift Loom/LoomApp.swift
git commit -m "feat: wire calendar write failure and sync error feedback"
```

---

### Task 11: Build, Run, and Smoke Test

**Files:** None (verification only)

- [ ] **Step 1: Full build**

Run: `swift build -c release 2>&1 | tail -10`
Expected: `Build complete!` with no new errors

- [ ] **Step 2: Run the app**

Run: `./run.sh`
Expected: App launches in menu bar

- [ ] **Step 3: Smoke test checklist**

Verify manually:
1. Start a session → menu bar shows filled icon + timer text
2. Stop a session → menu bar shows outline icon, no text + "Session saved" toast appears in main window
3. Open main window → Sessions tab shows skeleton loading briefly before sessions appear
4. Calendar tab shows skeleton loading briefly before timeline appears

- [ ] **Step 4: Commit any fixes if needed**

```bash
git add -A
git commit -m "fix: address smoke test issues"
```

(Skip this step if no fixes needed.)
