import Testing
import Foundation
@testable import TimeTracker

@Suite("Session Model")
struct SessionTests {

    @Test("Session duration calculates correctly")
    func sessionDuration() {
        let start = Date()
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            appsUsed: ["Xcode"]
        )
        #expect(session.duration == 3600)
    }

    @Test("Active session uses current time for duration")
    func activeSessionDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: nil,
            appsUsed: ["Xcode"]
        )
        #expect(session.duration >= 119 && session.duration <= 121)
    }

    @Test("Adding app to session")
    func addApp() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: ["Xcode"]
        )
        session.addApp("Terminal")
        #expect(session.appsUsed.contains("Terminal"))
        session.addApp("Xcode")
        #expect(session.appsUsed.count == 2)
    }

    @Test("Primary app is the first app added")
    func primaryApp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: ["Xcode", "Terminal"]
        )
        #expect(session.primaryApp == "Xcode")
    }
}
