import SwiftUI

struct VerticalTimelineView: View {
    let sessions: [Session]
    let isToday: Bool
    var backgroundEvents: [CalendarEvent] = []

    private let hourHeight: CGFloat = 60
    private let labelWidth: CGFloat = 40

    @State private var currentTime = Date()

    private var displayHours: ClosedRange<Int> {
        let cal = Calendar.current
        var allStartHours = sessions.map { cal.component(.hour, from: $0.startTime) }
        var allEndHours = sessions.compactMap { $0.endTime }.map { cal.component(.hour, from: $0) }
        allStartHours += backgroundEvents.map { cal.component(.hour, from: $0.startDate) }
        allEndHours += backgroundEvents.map { cal.component(.hour, from: $0.endDate) }

        guard !allStartHours.isEmpty else {
            let currentHour = cal.component(.hour, from: Date())
            return (isToday ? max(currentHour - 1, 0) : 8)...((isToday ? currentHour + 1 : 18))
        }
        let firstHour = allStartHours.min() ?? 8
        let lastHour: Int
        if isToday {
            lastHour = max(cal.component(.hour, from: currentTime), allEndHours.max() ?? 0)
        } else {
            lastHour = allEndHours.max() ?? 18
        }
        return firstHour...max(firstHour, min(lastHour + 1, 23))
    }

    private var dayStart: Date {
        let cal = Calendar.current
        if let first = sessions.first {
            return cal.startOfDay(for: first.startTime)
        }
        return cal.startOfDay(for: Date())
    }

    private func yOffset(for date: Date) -> CGFloat {
        let interval = date.timeIntervalSince(dayStart)
        let hours = interval / 3600
        return CGFloat(hours - Double(displayHours.lowerBound)) * hourHeight
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    // Hour labels and grid lines
                    ForEach(Array(displayHours), id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(String(format: "%d:00", hour))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: labelWidth, alignment: .trailing)

                            Rectangle()
                                .fill(Theme.border)
                                .frame(height: 0.5)
                        }
                        .offset(y: CGFloat(hour - displayHours.lowerBound) * hourHeight)
                        .id(hour)
                    }

                    // Background calendar events (faded, behind sessions)
                    ForEach(backgroundEvents) { event in
                        let top = yOffset(for: event.startDate)
                        let height = max(CGFloat(event.endDate.timeIntervalSince(event.startDate) / 3600) * hourHeight, 20)

                        calendarEventBlock(event: event, height: height)
                            .offset(x: labelWidth + 8, y: top)
                    }

                    // Session blocks
                    ForEach(sessions) { session in
                        let top = yOffset(for: session.startTime)
                        let end = session.endTime ?? currentTime
                        let height = max(CGFloat(end.timeIntervalSince(session.startTime) / 3600) * hourHeight, 20)

                        sessionBlock(session: session, height: height)
                            .offset(x: labelWidth + 8, y: top)
                    }

                    // Current time indicator
                    if isToday {
                        let y = yOffset(for: currentTime)
                        HStack(spacing: 4) {
                            Spacer().frame(width: labelWidth - 4)
                            Text(timeFormatter.string(from: currentTime))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(CategoryColors.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(CategoryColors.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))

                            Rectangle()
                                .fill(CategoryColors.accent)
                                .frame(height: 1.5)
                        }
                        .offset(y: y - 6)
                    }
                }
                .frame(
                    width: nil,
                    height: CGFloat(displayHours.count) * hourHeight,
                    alignment: .topLeading
                )
                .padding(.trailing, 16)
            }
            .onAppear {
                if isToday {
                    let currentHour = Calendar.current.component(.hour, from: currentTime)
                    proxy.scrollTo(max(currentHour - 1, displayHours.lowerBound), anchor: .top)
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                if isToday { currentTime = Date() }
            }
        }
    }

    @ViewBuilder
    private func sessionBlock(session: Session, height: CGFloat) -> some View {
        let color = CategoryColors.color(for: session.category)
        VStack(alignment: .leading, spacing: 2) {
            Text(session.category)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)

            Text(timeRange(session))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func calendarEventBlock(event: CalendarEvent, height: CGFloat) -> some View {
        let color = Color(nsColor: event.color)
        Text(event.title)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(color.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func timeRange(_ session: Session) -> String {
        let start = timeFormatter.string(from: session.startTime)
        let end = timeFormatter.string(from: session.endTime ?? currentTime)
        return "\(start) - \(end)"
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
}
