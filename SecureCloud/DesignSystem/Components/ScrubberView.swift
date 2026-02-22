import SwiftUI

// MARK: - ScrubberView

struct ScrubberView: View {
    @Binding var progress: Double           // 0.0 – 1.0
    let currentTime: String                 // e.g. "18:24"
    let remainingTime: String               // e.g. "-30:08"
    var accentColor: SwiftUI.Color = Tokens.Color.accent
    var onScrub: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.black.opacity(0.10))
                        .frame(height: 3)

                    // Filled portion
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(0, geo.size.width * progress), height: 3)

                    // Thumb
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: accentColor.opacity(0.4), radius: 3)
                        .offset(x: max(0, geo.size.width * progress - 5))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = max(0, min(1, value.location.x / geo.size.width))
                            progress = p
                            onScrub?(p)
                        }
                )
            }
            .frame(height: 10)

            // Time labels
            HStack {
                Text(currentTime)
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                    .monospacedDigit()
                Spacer()
                Text(remainingTime)
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @State var progress = 0.35
    return ScrubberView(
        progress: $progress,
        currentTime: "12:24",
        remainingTime: "-35:36"
    )
    .padding()
    .background(Tokens.Color.background)
}
