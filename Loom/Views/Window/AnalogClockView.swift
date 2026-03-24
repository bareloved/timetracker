import SwiftUI

struct AnalogClockView: View {
    let progress: Double
    let accentColor: Color
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth: CGFloat = size * 0.06

            ZStack {
                // Track ring
                Circle()
                    .stroke(Theme.border, lineWidth: lineWidth)

                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        accentColor.opacity(isActive ? 1 : 0.3),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center dot
                Circle()
                    .fill(isActive ? accentColor : Theme.textQuaternary)
                    .frame(width: size * 0.08, height: size * 0.08)

                // Tick marks
                ForEach(0..<12, id: \.self) { i in
                    let angle = Angle.degrees(Double(i) * 30)
                    let isPrimary = i % 3 == 0
                    Rectangle()
                        .fill(Theme.textTertiary.opacity(isPrimary ? 1 : 0.5))
                        .frame(width: isPrimary ? 2 : 1, height: isPrimary ? size * 0.08 : size * 0.05)
                        .offset(y: -(size / 2 - lineWidth - (isPrimary ? size * 0.06 : size * 0.05)))
                        .rotationEffect(angle)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
