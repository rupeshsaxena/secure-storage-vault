import SwiftUI

// MARK: - SettingsView (Screens 05 · Security, 06 · Sync & About)

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            ScreenBackground(style: .settings)

            ScrollView {
                VStack(spacing: Tokens.Spacing.md) {

                    // MARK: Security Section
                    settingsSection(header: "Security") {
                        ToggleRow(
                            icon: "faceid",                         // SF: faceid
                            iconBg: Tokens.Color.accentDim,
                            iconFg: Tokens.Color.accent,
                            title: "Face ID / Touch ID",
                            subtitle: "Unlock with biometrics",
                            isOn: $vm.biometricEnabled
                        )
                        Divider().padding(.horizontal, 12)
                        ToggleRow(
                            icon: "camera.metering.none",           // SF: camera.metering.none
                            iconBg: Tokens.Color.redDim,
                            iconFg: Tokens.Color.red,
                            title: "Block Screenshots",
                            subtitle: "Prevent screen capture in vault",
                            isOn: $vm.screenshotBlockEnabled
                        )
                        Divider().padding(.horizontal, 12)
                        autoLockRow
                    }

                    // MARK: Sync Section
                    settingsSection(header: "Sync") {
                        ToggleRow(
                            icon: "wifi",                           // SF: wifi
                            iconBg: Tokens.Color.greenDim,
                            iconFg: Tokens.Color.green,
                            title: "Wi-Fi Only",
                            subtitle: "Don't sync on cellular",
                            isOn: $vm.wifiOnlySync
                        )
                        Divider().padding(.horizontal, 12)
                        ToggleRow(
                            icon: "arrow.clockwise",               // SF: arrow.clockwise
                            iconBg: Tokens.Color.accentDim,
                            iconFg: Tokens.Color.accent,
                            title: "Auto Sync",
                            subtitle: "Sync when files change",
                            isOn: $vm.autoSyncEnabled
                        )
                        Divider().padding(.horizontal, 12)
                        ToggleRow(
                            icon: "clock.arrow.circlepath",        // SF: clock.arrow.circlepath
                            iconBg: Tokens.Color.accentDim,
                            iconFg: Tokens.Color.accent,
                            title: "Background Sync",
                            subtitle: "Sync while app is in background",
                            isOn: $vm.backgroundSyncEnabled
                        )
                    }

                    // MARK: Vault Actions
                    settingsSection(header: "Vault") {
                        Button {
                            Task { await vm.exportEncryptedBackup() }
                        } label: {
                            settingsActionRow(
                                icon: "arrow.down.doc.fill",        // SF: arrow.down.doc.fill
                                label: "Export Encrypted Backup",
                                color: Tokens.Color.accent
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.horizontal, 12)

                        Button {
                            Task { await vm.clearLocalCache() }
                        } label: {
                            settingsActionRow(
                                icon: "trash",                      // SF: trash
                                label: "Clear Local Cache",
                                color: Tokens.Color.orange
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.horizontal, 12)

                        Button {
                            vm.lockVault(appState: appState)
                        } label: {
                            settingsActionRow(
                                icon: "lock.fill",                  // SF: lock.fill
                                label: "Lock Vault Now",
                                color: Tokens.Color.red
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: About
                    settingsSection(header: "About") {
                        infoRow(label: "Version", value: vm.appVersion)
                        Divider().padding(.horizontal, 12)
                        infoRow(label: "Build", value: vm.buildNumber)
                        Divider().padding(.horizontal, 12)
                        infoRow(label: "Encryption", value: "AES-256-GCM")
                        Divider().padding(.horizontal, 12)
                        infoRow(label: "Key Derivation", value: "PBKDF2-SHA256")
                    }
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Auto-Lock Row

    private var autoLockRow: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.iconSm)
                    .fill(Tokens.Color.orange.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: "timer") // SF: timer
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Color.orange)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-Lock")
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("Lock vault after inactivity")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
            }

            Spacer()

            Picker("", selection: $vm.autoLockDelay) {
                ForEach(SettingsViewModel.AutoLockDelay.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .font(Tokens.Font.caption1())
            .foregroundStyle(Tokens.Color.accent)
        }
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func settingsSection<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: header)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .glassCard()
        }
    }

    private func settingsActionRow(icon: String, label: String, color: SwiftUI.Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon) // SF: supplied
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(Tokens.Font.body())
                .foregroundStyle(color)
            Spacer()
            Image(systemName: "chevron.right") // SF: chevron.right
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Color.textQuaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textTertiary)
            Spacer()
            Text(value)
                .font(Tokens.Font.body(.medium))
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
