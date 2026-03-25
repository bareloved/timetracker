import SwiftUI
import LoomKit

struct NowTabView: View {
    let appState: MobileAppState
    @State private var showStartSheet = false

    private var activeSession: Session? {
        appState.currentSession ?? appState.remoteSession
    }

    private var isRemote: Bool {
        appState.currentSession == nil && appState.remoteSession != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = activeSession {
                    activeSessionCard(session)
                } else {
                    idleView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Now")
            .refreshable {
                await appState.refreshActiveState()
            }
            .sheet(isPresented: $showStartSheet) {
                StartSessionSheet(appState: appState)
            }
        }
    }

    // MARK: - Active Session

    private func activeSessionCard(_ session: Session) -> some View {
        VStack(spacing: 24) {
            // Source label
            if isRemote {
                HStack(spacing: 6) {
                    Image(systemName: "laptopcomputer")
                        .font(.caption)
                    Text("FROM MAC")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 8)
            }

            // Category pill
            Text(session.category)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(CategoryColors.color(for: session.category), in: Capsule())

            // Timer
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(session.startTime)
                Text(formatDuration(elapsed))
                    .font(.system(size: 48, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            // Intention
            if let intention = session.intention, !intention.isEmpty {
                VStack(spacing: 4) {
                    Text("INTENTION")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Theme.textTertiary)
                    Text(intention)
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Apps used
            if !session.appsUsed.isEmpty {
                VStack(spacing: 8) {
                    Text("APPS USED")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Theme.textTertiary)

                    FlowLayout(spacing: 8) {
                        ForEach(session.appsUsed, id: \.self) { app in
                            Text(app)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.backgroundSecondary, in: Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
            }

            // Stale warning
            if isRemote && appState.syncEngine.isStale {
                staleWarning
            }

            // Stop button
            Button {
                Task { await appState.stopSession() }
            } label: {
                Text("Stop Session")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(24)
    }

    // MARK: - Stale Warning

    private var staleWarning: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Session may be stale")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("No heartbeat received recently. The Mac app may have quit unexpectedly.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                Task { await appState.stopSession() }
            } label: {
                Text("Force Stop")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "circle.dashed")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Theme.textQuaternary)

            Text("No active session")
                .font(.title3)
                .foregroundStyle(Theme.textTertiary)

            Button {
                showStartSheet = true
            } label: {
                Text("Start Session")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(24)
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
