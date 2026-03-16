import SwiftUI

struct LaunchPopupView: View {
    let onStart: (String?) -> Void
    let onDismiss: () -> Void

    @State private var intention = ""

    var body: some View {
        VStack(spacing: 14) {
            SunriseAnimation()
                .padding(.top, 4)

            Text("Ready to focus?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("What are you working on?")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)

            TextField("Intention (optional)", text: $intention)
                .textFieldStyle(.roundedBorder)
                .onSubmit { startSession() }

            Button(action: startSession) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button("Not now") {
                onDismiss()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: 300)
        .background(Theme.background)
    }

    private func startSession() {
        onStart(intention.isEmpty ? nil : intention)
    }
}
