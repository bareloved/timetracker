import AppKit
import ApplicationServices

@Observable
@MainActor
final class ActivityMonitor {

    private(set) var latestActivity: ActivityRecord?
    private var timer: Timer?
    private(set) var isPaused = false

    var onActivity: ((ActivityRecord) -> Void)?
    var onIdle: (() -> Void)?
    var onIdleReturn: ((TimeInterval) -> Void)?
    private var idleStartTime: Date?
    private var isIdleDetected = false

    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 5.0) {
        self.pollInterval = pollInterval
    }

    func start() {
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        start()
    }

    private func poll() {
        if IdleDetector.isIdle() {
            if !isIdleDetected {
                isIdleDetected = true
                idleStartTime = Date()
                isPaused = true
                latestActivity = nil
                onIdle?()
            }
            return
        }

        // Returning from idle
        if isIdleDetected {
            isIdleDetected = false
            isPaused = false
            if let start = idleStartTime {
                let idleDuration = Date().timeIntervalSince(start)
                idleStartTime = nil
                onIdleReturn?(idleDuration)
            }
        }

        if isPaused {
            // Manual pause — don't poll
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let appName = frontApp.localizedName else {
            return
        }

        let windowTitle = Self.windowTitle(for: frontApp)

        var pageURL: String? = nil
        if BrowserTracker.isBrowser(bundleId: bundleId) {
            pageURL = BrowserTracker.activeTabURL(for: frontApp)
        }

        let record = ActivityRecord(
            bundleId: bundleId,
            appName: appName,
            windowTitle: windowTitle,
            pageURL: pageURL,
            timestamp: Date()
        )
        latestActivity = record
        onActivity?(record)
    }

    private static func windowTitle(for app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success, let titleStr = title as? String, !titleStr.isEmpty else { return nil }

        return titleStr
    }
}
