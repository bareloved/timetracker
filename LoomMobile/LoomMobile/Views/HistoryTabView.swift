import SwiftUI
import LoomKit

struct HistoryTabView: View {
    let appState: MobileAppState

    @State private var selectedDate: Date = Date()
    @State private var sessions: [Session] = []
    @State private var isLoading = false

    private let calendar = Calendar.current

    // The week containing the selected date (Mon-Sun)
    private var weekDates: [Date] {
        let weekday = calendar.component(.weekday, from: selectedDate)
        // weekday: 1=Sun, 2=Mon ... 7=Sat  -> offset to make Monday first
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: calendar.startOfDay(for: selectedDate)) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                if !sessions.isEmpty {
                    dailySummaryBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                Divider()
                    .overlay(Theme.border)

                sessionList
            }
            .background(Theme.background)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadSessions()
        }
        .onChange(of: selectedDate) {
            Task { await loadSessions() }
        }
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(dayAbbreviation(for: date))
                            .font(.caption2)
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.callout)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundStyle(isSelected ? .white : (isToday ? CategoryColors.accent : Theme.textPrimary))
                            .frame(width: 34, height: 34)
                            .background {
                                if isSelected {
                                    Circle().fill(CategoryColors.accent)
                                } else if isToday {
                                    Circle().stroke(CategoryColors.accent, lineWidth: 1.5)
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Daily Summary Bar

    private var dailySummaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Colored segment bar
            GeometryReader { geometry in
                HStack(spacing: 1.5) {
                    ForEach(categoryDurations, id: \.category) { item in
                        let fraction = totalDuration > 0 ? item.duration / totalDuration : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(CategoryColors.color(for: item.category))
                            .frame(width: max(4, geometry.size.width * fraction))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(formattedDuration(totalDuration))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var categoryDurations: [(category: String, duration: TimeInterval)] {
        var map: [String: TimeInterval] = [:]
        for session in sessions {
            map[session.category, default: 0] += session.duration
        }
        return map.map { (category: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
    }

    // MARK: - Session List

    private var sessionList: some View {
        Group {
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Theme.textTertiary)
                Spacer()
            } else if sessions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textQuaternary)
                    Text("No sessions")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                sessionRow(session)
                            }

                            Divider()
                                .overlay(Theme.border)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 12) {
            // Category color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(CategoryColors.color(for: session.category))
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)

                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDuration(session.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)

                Text(timeRange(for: session))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.textQuaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func timeRange(for session: Session) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: session.startTime)
        let end = session.endTime.map { formatter.string(from: $0) } ?? "now"
        return "\(start) - \(end)"
    }

    private func loadSessions() async {
        isLoading = true
        sessions = await appState.fetchSessions(for: selectedDate)
        isLoading = false
    }
}
