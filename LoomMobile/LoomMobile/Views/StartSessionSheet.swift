import SwiftUI
import LoomKit

struct StartSessionSheet: View {
    let appState: MobileAppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String?
    @State private var intention: String = ""
    @State private var showActiveAlert = false
    @State private var isStarting = false

    private var categories: [String] {
        appState.categoryConfig?.orderedCategoryNames ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Category picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CATEGORY")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(Theme.textTertiary)

                        FlowLayout(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                categoryChip(category)
                            }
                        }
                    }

                    // Intention field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTENTION")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(Theme.textTertiary)

                        TextField("What do you want to focus on?", text: $intention)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }

                    // Start button
                    Button {
                        startSession()
                    } label: {
                        if isStarting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Start Session")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .background(
                        selectedCategory != nil ? CategoryColors.accent : Theme.textQuaternary,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .disabled(selectedCategory == nil || isStarting)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Theme.background)
            .navigationTitle("Start Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .alert("Session Already Active", isPresented: $showActiveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("There is already an active session. Stop it before starting a new one.")
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        let color = CategoryColors.color(for: category)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        } label: {
            Text(category)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? color : Theme.backgroundSecondary,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func startSession() {
        guard let category = selectedCategory else { return }
        isStarting = true

        Task {
            // Check for existing active session
            await appState.syncEngine.fetchActiveState()
            if appState.syncEngine.activeSessionID != nil && appState.currentSession == nil {
                isStarting = false
                showActiveAlert = true
                return
            }

            await appState.startSession(
                category: category,
                intention: intention.isEmpty ? nil : intention
            )
            isStarting = false
            dismiss()
        }
    }
}

// MARK: - FlowLayout

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
