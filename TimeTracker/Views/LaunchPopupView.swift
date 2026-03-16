import SwiftUI

struct LaunchPopupView: View {
    let onStart: (String?) -> Void
    let onDismiss: () -> Void

    @State private var intention = ""

    var body: some View {
        VStack(spacing: 16) {
            SunriseAnimation()

            Text("Ready to focus?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("What are you working on?")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)

            TextField("Intention (optional)", text: $intention)
                .textFieldStyle(.roundedBorder)
                .onSubmit { startSession() }

            Button(action: startSession) {
                Text("START SESSION")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button("Not now") {
                onDismiss()
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 300)
    }

    private func startSession() {
        onStart(intention.isEmpty ? nil : intention)
    }
}
