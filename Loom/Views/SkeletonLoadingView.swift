import SwiftUI

struct SkeletonLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.trackFill)
                    .frame(height: 60)
                    .opacity(isAnimating ? 0.6 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
