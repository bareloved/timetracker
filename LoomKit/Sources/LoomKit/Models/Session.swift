import Foundation

public struct Session: Identifiable, Codable {
    public let id: UUID
    public var category: String
    public let startTime: Date
    public var endTime: Date?
    public var appsUsed: [String]
    public var intention: String?
    public var trackingSpanId: UUID?
    public var eventIdentifier: String?
    public var distractions: [Distraction] = []
    public var source: String?

    public init(
        id: UUID = UUID(),
        category: String,
        startTime: Date,
        endTime: Date? = nil,
        appsUsed: [String],
        intention: String? = nil,
        trackingSpanId: UUID? = nil,
        eventIdentifier: String? = nil,
        distractions: [Distraction] = [],
        source: String? = nil
    ) {
        self.id = id
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.appsUsed = appsUsed
        self.intention = intention
        self.trackingSpanId = trackingSpanId
        self.eventIdentifier = eventIdentifier
        self.distractions = distractions
        self.source = source
    }

    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    public var primaryApp: String? {
        appsUsed.first
    }

    public var isActive: Bool {
        endTime == nil
    }

    public mutating func addApp(_ appName: String) {
        if !appsUsed.contains(appName) {
            appsUsed.append(appName)
        }
    }
}
