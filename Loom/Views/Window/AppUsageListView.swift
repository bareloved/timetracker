import SwiftUI

struct AppUsageListView: View {
    let appsUsed: [AppUsage]

    private var hasAnyDuration: Bool {
        appsUsed.contains { $0.duration > 0 }
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(appsUsed) { appUsage in
                HStack {
                    Text(appUsage.appName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    // Only show duration if this session has real duration data
                    if hasAnyDuration {
                        Text(formatDuration(appUsage.duration))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes == 0 { return "< 1m" }
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
}
