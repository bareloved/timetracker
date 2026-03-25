import Foundation

public struct Distraction: Identifiable, Equatable, Codable {
    public let id: UUID
    public let appName: String
    public let bundleId: String
    public let url: String?
    public let startTime: Date
    public var duration: TimeInterval
    public var snoozed: Bool

    public init(
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
