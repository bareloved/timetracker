import SwiftUI
import LoomKit

struct StartSessionSheet: View {
    let appState: MobileAppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String = "Coding"
    @State private var intention: String = ""
    @State private var showActiveWarning = false

    private var categories: [String] {
        appState.categoryConfig?.orderedCategoryNames ?? ["Other"]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            FlowLayout(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        Text(cat)
                                            .font(.subheadline)
                                            .fontWeight(selectedCategory == cat ? .semibold : .regular)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedCategory == cat
                                                    ? CategoryColors.color(for: cat).opacity(0.2)
                                                    : Theme.trackFill
                                            )
                                            .foregroundStyle(
                                                selectedCategory == cat
                                                    ? CategoryColors.color(for: cat)
                                                    : Theme.textSecondary
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        selectedCategory == cat
                                                            ? CategoryColors.color(for: cat)
                                                            : Theme.border,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Intention")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            TextField("What are you working on?", text: $intention)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            await appState.startSession(
                                category: selectedCategory,
                                intention: intention.isEmpty ? nil : intention
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .tint(CategoryColors.accent)
                }
            }
            .alert("Session Already Active", isPresented: $showActiveWarning) {
                Button("Stop & Start New") {
                    Task {
                        await appState.stopSession()
                        await appState.startSession(
                            category: selectedCategory,
                            intention: intention.isEmpty ? nil : intention
                        )
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let source = appState.syncEngine.activeSource == "mac" ? "Mac" : "iPhone"
                Text("A session is already running on \(source). Stop it and start a new one?")
            }
            .task {
                await appState.refreshActiveState()
                if appState.syncEngine.activeSessionID != nil {
                    showActiveWarning = true
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
