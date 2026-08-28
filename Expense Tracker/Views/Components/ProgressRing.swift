import SwiftUI

struct ProgressRing<Content: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var size: CGFloat = 140
    var isOverBudget: Bool = false
    @ViewBuilder var content: () -> Content

    private var clampedProgress: Double {
        min(max(progress, 0), 1.0)
    }

    private var ringColor: Color {
        if isOverBudget { return .appWarning }
        if progress > 0.85 { return .orange }
        return .appAccent
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color.secondary.opacity(0.15),
                    lineWidth: lineWidth
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // Center content
            content()
        }
        .frame(width: size, height: size)
    }
}
