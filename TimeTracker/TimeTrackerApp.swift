import SwiftUI

@main
struct TimeTrackerApp: App {
    var body: some Scene {
        MenuBarExtra("TimeTracker", systemImage: "clock.badge.checkmark") {
            Text("TimeTracker is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
