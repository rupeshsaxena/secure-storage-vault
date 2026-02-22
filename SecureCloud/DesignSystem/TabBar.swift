import SwiftUI

// MARK: - AppTab

enum AppTab: Hashable {
    case vault
    case sync
    case settings
}

// MARK: - FloatingTabBar

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            TabItem(
                tab: .vault,
                icon: "lock",
                iconSelected: "lock.fill",
                label: "Vault",
                selection: $selection
            )
            TabItem(
                tab: .sync,
                icon: "arrow.clockwise",
                iconSelected: "arrow.clockwise",
                label: "Sync",
                selection: $selection
            )
            TabItem(
                tab: .settings,
                icon: "gearshape",
                iconSelected: "gearshape",
                label: "Settings",
                selection: $selection
            )
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.tabBar, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.tabBar, style: .continuous)
                        .stroke(Tokens.Color.borderMed, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.09), radius: 12, x: 0, y: 2)
        )
        .padding(.horizontal, 7)
        .padding(.bottom, 7)
    }
}

// MARK: - TabItem

private struct TabItem: View {
    let tab: AppTab
    let icon: String
    let iconSelected: String
    let label: String
    @Binding var selection: AppTab

    private var isOn: Bool { selection == tab }

    var body: some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isOn ? iconSelected : icon) // SF: per tab
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? Tokens.Color.accent : Tokens.Color.textTertiary)
                Text(label)
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(isOn ? Tokens.Color.accent : Tokens.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                isOn
                    ? RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Tokens.Color.accentDim)
                    : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

// MARK: - RootTabView

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: AppTab = .vault

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .vault:
                    NavigationStack {
                        VaultView()
                    }
                case .sync:
                    NavigationStack {
                        SyncView()
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selection)
        }
    }
}
