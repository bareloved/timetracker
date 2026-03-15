import Foundation

struct Session: Identifiable {
    let id = UUID()
    let category: String
    let startTime: Date
    var endTime: Date?
    var appsUsed: [String]

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
