import SwiftUI
import LoomKit

struct SessionDetailView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Category + Intention
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.category)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(CategoryColors.color(for: session.category))

                    if let intention = session.intention, !intention.isEmpty {
                        Text(intention)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Duration + Time Range
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)

                    Text(formattedDuration(session.duration))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)

                    Text("·")
                        .foregroundStyle(Theme.textQuaternary)

                    Text(timeRange)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }

                // Apps Used
                if !session.appsUsed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Apps Used")

                        FlowLayout(spacing: 8) {
                            ForEach(session.appsUsed, id: \.self) { app in
                                Text(app)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.trackFill, in: Capsule())
                            }
                        }
                    }
                }

                // Distractions
                if !session.distractions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Distractions")

                        VStack(spacing: 0) {
                            ForEach(session.distractions) { distraction in
                                distractionRow(distraction)

                                if distraction.id != session.distractions.last?.id {
                                    Divider()
                                        .overlay(Theme.border)
                                }
                            }
                        }
                        .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .tracking(1)
            .foregroundStyle(Theme.textTertiary)
    }

    private func distractionRow(_ distraction: Distraction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(distraction.appName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)

                if let url = distraction.url, !url.isEmpty {
                    Text(url)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if distraction.snoozed {
                Image(systemName: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.textQuaternary)
            }

            Text(formattedDuration(distraction.duration))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: session.startTime)
        let end = session.endTime.map { formatter.string(from: $0) } ?? "now"
        return "\(start) - \(end)"
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
