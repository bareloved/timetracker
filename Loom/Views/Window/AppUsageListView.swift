import SwiftUI

struct AppUsageListView: View {
    let appsUsed: [AppUsage]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(appsUsed) { appUsage in
                HStack {
                    // App name — 10px regular, Theme.textSecondary
                    Text(appUsage.appName)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    // Duration — 10px semibold, Theme.textTertiary, e.g. "45m"
                    Text(formatDuration(appUsage.duration))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return "\(max(1, minutes))m"  // show at least "1m" for very short durations
        } else if remainingMinutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}
