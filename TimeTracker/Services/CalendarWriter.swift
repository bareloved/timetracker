import Foundation

@Observable
final class CalendarWriter {
    func createEvent(for session: Session) {}
    func updateCurrentEvent(session: Session) {}
    func finalizeEvent(for session: Session) {}
}
