import SwiftUI

// MARK: - SyncView (Screen 04)

struct SyncView: View {
    @StateObject private var vm = SyncViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenBackground(style: .sync)

            ScrollView {
                VStack(spacing: Tokens.Spacing.md) {

                    // Sync status card
                    syncStatusCard

                    // Stats row
                    statsRow

                    // Linked devices section
                    SectionHeader(title: "Linked Devices") {
                        Button {
                            vm.showAddDevice = true
                        } label: {
                            Image(systemName: "plus") // SF: plus
                                .iconButtonAccent()
                        }
                    }

                    if vm.devices.isEmpty {
                        noDevicesPlaceholder
                    } else {
                        VStack(spacing: 4) {
                            ForEach(vm.devices) { device in
                                DeviceRow(device: device, isThis: device.id == vm.thisDeviceId)
                                    .swipeActions(edge: .trailing) {
                                        if device.id != vm.thisDeviceId {
                                            Button(role: .destructive) {
                                                Task { await vm.removeDevice(id: device.id) }
                                            } label: {
                                                Label("Remove", systemImage: "trash") // SF: trash
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $vm.showAddDevice) {
            AddDeviceSheet()
        }
        .task { await vm.load() }
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(vm.isSyncing ? Tokens.Color.accentDim : Tokens.Color.greenDim)
                        .frame(width: 48, height: 48)
                    Image(systemName: vm.isSyncing ? "arrow.clockwise" : "checkmark.circle.fill") // SF: varies
                        .font(.system(size: 20))
                        .foregroundStyle(vm.isSyncing ? Tokens.Color.accent : Tokens.Color.green)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.isSyncing ? "Syncing…" : "Up to date")
                        .font(Tokens.Font.headline())
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text(vm.isSyncing ? "Uploading files securely" : "All files are encrypted and synced")
                        .font(Tokens.Font.caption1())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }

                Spacer()

                Button {
                    Task { await vm.syncNow() }
                } label: {
                    Text(vm.isSyncing ? "Syncing" : "Sync Now")
                        .font(Tokens.Font.caption1(.medium))
                        .foregroundStyle(vm.isSyncing ? Tokens.Color.textTertiary : Tokens.Color.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(vm.isSyncing ? Tokens.Color.textQuaternary : Tokens.Color.accentDim)
                        )
                }
                .buttonStyle(.plain)
                .disabled(vm.isSyncing)
            }

            if vm.isSyncing {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tokens.Color.textQuaternary).frame(height: 3)
                        Capsule().fill(Tokens.Color.accent)
                            .frame(width: geo.size.width * vm.syncProgress, height: 3)
                            .animation(.easeInOut(duration: 0.3), value: vm.syncProgress)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCell(value: "\(vm.syncedCount)", label: "Synced", color: Tokens.Color.green)
            statCell(value: "\(vm.pendingCount)", label: "Pending", color: Tokens.Color.orange)
            statCell(value: "\(vm.totalCount)", label: "Total", color: Tokens.Color.accent)
        }
    }

    private func statCell(value: String, label: String, color: SwiftUI.Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Tokens.Font.title())
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption2())
                .foregroundStyle(Tokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
    }

    // MARK: - No Devices Placeholder

    private var noDevicesPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.badge.plus") // SF: iphone.badge.plus
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Color.textTertiary)
            Text("No linked devices")
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textSecondary)
            Button("Link a Device") { vm.showAddDevice = true }
                .font(Tokens.Font.body(.medium))
                .foregroundStyle(Tokens.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - DeviceRow

struct DeviceRow: View {
    let device: SyncDevice
    let isThis: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.iconSm)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 36, height: 36)
                Image(systemName: device.platform.icon) // SF: iphone / laptopcomputer / ipad
                    .font(.system(size: 16))
                    .foregroundStyle(Tokens.Color.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(Tokens.Font.body(.medium))
                        .foregroundStyle(Tokens.Color.textPrimary)
                    if isThis {
                        Text("This device")
                            .font(Tokens.Font.caption2())
                            .foregroundStyle(Tokens.Color.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Tokens.Color.accentDim))
                    }
                }
                Text("Last seen \(device.lastSeen.formatted(.relative(presentation: .named)))")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(device.syncedFileCount) synced")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                if device.pendingFileCount > 0 {
                    Text("\(device.pendingFileCount) pending")
                        .font(Tokens.Font.caption2(.medium))
                        .foregroundStyle(Tokens.Color.orange)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .glassCard(radius: Tokens.Radius.cardSm)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SyncView()
            .environmentObject(AppState())
    }
}
