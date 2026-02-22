import SwiftUI

// MARK: - ToggleRow

struct ToggleRow: View {
    let icon: String          // SF Symbol name
    let iconBg: SwiftUI.Color
    let iconFg: SwiftUI.Color
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    init(
        icon: String,
        iconBg: SwiftUI.Color = Tokens.Color.accentDim,
        iconFg: SwiftUI.Color = Tokens.Color.accent,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.iconBg = iconBg
        self.iconFg = iconFg
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 9) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.iconSm)
                    .fill(iconBg)
                    .frame(width: 26, height: 26)
                Image(systemName: icon) // SF: supplied by caller
                    .font(.system(size: 13))
                    .foregroundStyle(iconFg)
            }

            // Labels
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Font.caption2())
                        .foregroundStyle(Tokens.Color.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(VaultToggleStyle())
                .labelsHidden()
        }
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
    }
}

// MARK: - VaultToggleStyle

struct VaultToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            Capsule()
                .fill(configuration.isOn ? Tokens.Color.green : Tokens.Color.textQuaternary)
                .frame(width: 34, height: 19)
                .overlay(
                    Capsule()
                        .stroke(
                            configuration.isOn ? Color.clear : Tokens.Color.borderMed,
                            lineWidth: 1
                        )
                )

            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                .padding(2.5)
        }
        .animation(.spring(response: 0.2), value: configuration.isOn)
        .onTapGesture { configuration.isOn.toggle() }
    }
}

// MARK: - Preview

#Preview {
    @State var on1 = true
    @State var on2 = false

    return VStack(spacing: 0) {
        ToggleRow(
            icon: "faceid",
            iconBg: Tokens.Color.accentDim,
            iconFg: Tokens.Color.accent,
            title: "Face ID",
            subtitle: "Unlock with biometrics",
            isOn: $on1
        )
        Divider().padding(.horizontal, 12)
        ToggleRow(
            icon: "wifi",
            iconBg: Tokens.Color.greenDim,
            iconFg: Tokens.Color.green,
            title: "Sync on Wi-Fi only",
            isOn: $on2
        )
    }
    .glassCard()
    .padding()
    .background(Tokens.Color.background)
}
