import SwiftUI

struct FocusPopupView: View {
    let appName: String
    let elapsed: TimeInterval
    let snoozeMinutes: Int
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(CategoryColors.accent)
                .padding(.top, 4)

            // Title
            Text("Losing focus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            // Detail
            VStack(spacing: 4) {
                Text("You've been on **\(appName)**")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("for \(formattedElapsed)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)

            // Buttons
            VStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("Back to Work")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: onSnooze) {
                    Text("Snooze (\(snoozeMinutes) min)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private var formattedElapsed: String {
        let seconds = Int(elapsed)
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes) minutes"
        }
        return "\(seconds) seconds"
    }
}
