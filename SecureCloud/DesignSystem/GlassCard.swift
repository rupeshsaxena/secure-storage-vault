import SwiftUI

// MARK: - GlassCard ViewModifier

struct GlassCard: ViewModifier {
    var radius: CGFloat = Tokens.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Tokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Tokens.Color.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - View extension

extension View {
    func glassCard(radius: CGFloat = Tokens.Radius.card) -> some View {
        modifier(GlassCard(radius: radius))
    }
}

// MARK: - ScreenBackground

struct ScreenBackground: View {
    enum Style { case vault, sync, settings, sheet, dark }
    let style: Style

    var body: some View {
        ZStack {
            switch style {
            case .vault:
                LinearGradient(
                    colors: [Color(hex: "F0F2F5"), Color(hex: "EAECF2")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(
                    RadialGradient(
                        colors: [Color(hex: "2F78C5").opacity(0.07), .clear],
                        center: UnitPoint(x: 0.3, y: 0),
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            case .sync:
                LinearGradient(
                    colors: [Color(hex: "F0F2F5"), Color(hex: "EBEEF2")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(
                    RadialGradient(
                        colors: [Color(hex: "2D8A52").opacity(0.06), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            case .settings:
                LinearGradient(
                    colors: [Color(hex: "F0F2F5"), Color(hex: "EBEDF2")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(
                    RadialGradient(
                        colors: [Color(hex: "2F78C5").opacity(0.06), .clear],
                        center: UnitPoint(x: 0.8, y: 0),
                        startRadius: 0,
                        endRadius: 180
                    )
                )

            case .sheet, .dark:
                LinearGradient(
                    colors: [Color(hex: "F0F2F5"), Color(hex: "ECEEF3")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}
