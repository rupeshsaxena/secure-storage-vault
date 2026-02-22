import SwiftUI

// MARK: - SyncBanner

struct SyncBanner: View {
    let state: AppState.VaultSyncState

    @State private var spinAngle: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.iconSm)
                        .fill(iconBg)
                        .frame(width: 28, height: 28)
                    iconView
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle)
                        .font(Tokens.Font.body(.semibold))
                        .foregroundStyle(statusColor)
                    Text(statusSubtitle)
                        .font(Tokens.Font.caption2())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("AES-256-GCM")
                        .font(Tokens.Font.caption2())
                        .foregroundStyle(Tokens.Color.textTertiary)
                }
            }

            // Progress bar (syncing state only)
            if case .syncing(let progress) = state {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Tokens.Color.textQuaternary)
                            .frame(height: 2)
                        Capsule()
                            .fill(Tokens.Color.accent)
                            .frame(width: geo.size.width * progress, height: 2)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 2)
                .padding(.top, 8)
            }
        }
        .padding(12)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(bannerBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var statusTitle: String {
        switch state {
        case .syncing:           return "Syncing"
        case .protected, .empty: return "Protected"
        }
    }

    private var statusColor: SwiftUI.Color {
        switch state {
        case .syncing:           return Tokens.Color.accent
        case .protected, .empty: return Tokens.Color.green
        }
    }

    private var statusSubtitle: String {
        switch state {
        case .syncing(let p):    return "Uploading… \(Int(p * 100))%"
        case .protected:         return "Vault encrypted · all files safe"
        case .empty:             return "No files yet"
        }
    }

    private var iconBg: SwiftUI.Color {
        switch state {
        case .syncing:           return Tokens.Color.accentDim
        case .protected, .empty: return Tokens.Color.greenDim
        }
    }

    private var bannerBorderColor: SwiftUI.Color {
        switch state {
        case .syncing:           return Tokens.Color.accent.opacity(0.15)
        case .protected, .empty: return Tokens.Color.green.opacity(0.16)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .syncing:
            Image(systemName: "arrow.clockwise") // SF: arrow.clockwise
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Tokens.Color.accent)
                .rotationEffect(.degrees(spinAngle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        spinAngle = 360
                    }
                }
        case .protected, .empty:
            Image(systemName: "checkmark.shield.fill") // SF: checkmark.shield.fill
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Color.green)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        SyncBanner(state: .syncing(progress: 0.6))
        SyncBanner(state: .protected)
        SyncBanner(state: .empty)
    }
    .padding()
    .background(Tokens.Color.background)
}
