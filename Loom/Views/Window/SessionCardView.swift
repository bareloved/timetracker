import SwiftUI

struct SessionCardView: View {
    let session: Session
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Left color strip — 3px wide, category color, leading-edge radius only
            Rectangle()
                .fill(CategoryColors.color(for: session.category))
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 10,
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            // Card content
            VStack(alignment: .leading, spacing: 4) {
                // Top line: [live dot] category name ... duration (right-aligned)
                HStack(spacing: 4) {
                    // Live dot — 4px circle, accent, in-progress only
                    if session.isActive {
                        Circle()
                            .fill(CategoryColors.accent)
                            .frame(width: 4, height: 4)
                            .accessibilityLabel("In progress")
                    }

                    // Category name — 13px semibold, Theme.textPrimary
                    Text(session.category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    // Duration — 13px semibold, Theme.textPrimary, e.g. "45m"
                    Text(formatDuration(session.duration))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                // Middle: intention — 13px regular, Theme.textSecondary
                // If nil, show "No intention" in Theme.textQuaternary
                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("No intention")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textQuaternary)
                }

                // Bottom: time range — 10px regular, Theme.textQuaternary, e.g. "09:15 – 10:00"
                Text(formatTimeRange(start: session.startTime, end: session.endTime))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textQuaternary)

                // Expanded detail
                if isExpanded && !session.appsUsed.isEmpty {
                    Divider()
                        .foregroundStyle(Theme.border)
                        .padding(.top, 6)

                    AppUsageListView(appsUsed: session.appsUsed)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    // Duration formatting — "45m", "1h 12m", "2h"
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if remainingMinutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    // Time range formatting — "09:15 – 10:00" or "09:15 – ongoing"
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func formatTimeRange(start: Date, end: Date?) -> String {
        let startStr = Self.timeFormatter.string(from: start)
        let endStr = end.map { Self.timeFormatter.string(from: $0) } ?? "ongoing"
        return "\(startStr) \u{2013} \(endStr)"  // en-dash
    }
}
