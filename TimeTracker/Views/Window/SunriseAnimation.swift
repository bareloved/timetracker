import SwiftUI

struct SunriseAnimation: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Outer glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [CategoryColors.accent.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 60)
                .opacity(animate ? 1 : 0)

            // Half circle (sun)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xe8955a), CategoryColors.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 30)
                .clipShape(
                    Rectangle()
                        .offset(y: -15)
                        .size(width: 30, height: 15)
                )
                .offset(y: animate ? 0 : 20)

            // Horizon line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, CategoryColors.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: animate ? 80 : 0, height: 1.5)
                .offset(y: 15)
        }
        .frame(width: 100, height: 60)
        .onAppear {
            withAnimation(.easeOut(duration: 2)) {
                animate = true
            }
        }
    }
}
