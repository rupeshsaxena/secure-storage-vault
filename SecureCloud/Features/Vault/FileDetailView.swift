import SwiftUI

// MARK: - FileDetailView (Screen 11)

struct FileDetailView: View {
    let file: VaultFile
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: FileDetailViewModel
    @State private var showShareSheet = false

    init(file: VaultFile) {
        self.file = file
        self._vm = StateObject(wrappedValue: FileDetailViewModel(file: file))
    }

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            ScrollView {
                VStack(spacing: Tokens.Spacing.md) {

                    // File preview card
                    previewCard

                    // Metadata card
                    metadataCard

                    // Actions card
                    actionsCard
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up") // SF: square.and.arrow.up
                        .iconButton()
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(file: file)
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 64, height: 64)
                Image(systemName: file.fileType.icon) // SF: varies
                    .font(.system(size: 28))
                    .foregroundStyle(Tokens.Color.accent)
            }

            VStack(spacing: 4) {
                Text(file.name)
                    .font(Tokens.Font.headline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            StatusBadge(status: file.syncStatus)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(spacing: 0) {
            metaRow(label: "Encryption", value: file.encryptionStandard)
            Divider().padding(.horizontal, 12)
            metaRow(label: "Type", value: file.fileType.rawValue.uppercased())
            Divider().padding(.horizontal, 12)
            metaRow(label: "Added", value: file.addedAt.formatted(date: .abbreviated, time: .shortened))
            Divider().padding(.horizontal, 12)
            metaRow(label: "Modified", value: file.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            if file.isLocked {
                Divider().padding(.horizontal, 12)
                metaRow(
                    label: "Access",
                    value: "Locked",
                    valueColor: Tokens.Color.orange
                )
            }
        }
        .glassCard()
    }

    private func metaRow(
        label: String,
        value: String,
        valueColor: SwiftUI.Color = Tokens.Color.textSecondary
    ) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textTertiary)
            Spacer()
            Text(value)
                .font(Tokens.Font.body(.medium))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 0) {
            actionButton(
                icon: "square.and.arrow.up",    // SF: square.and.arrow.up
                label: "Export / Share",
                color: Tokens.Color.accent
            ) {
                showShareSheet = true
            }

            Divider().padding(.horizontal, 12)

            actionButton(
                icon: "trash",                   // SF: trash
                label: "Delete File",
                color: Tokens.Color.red
            ) {
                Task { await vm.delete() }
            }
        }
        .glassCard()
    }

    private func actionButton(
        icon: String,
        label: String,
        color: SwiftUI.Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
    }
}

// MARK: - FileDetailViewModel

@MainActor
final class FileDetailViewModel: ObservableObject {
    let file: VaultFile
    @Published var isDeleted = false

    private let useCase: VaultUseCaseProtocol

    init(file: VaultFile, useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.file = file
        self.useCase = useCase
    }

    func delete() async {
        try? await useCase.deleteFile(id: file.id)
        isDeleted = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FileDetailView(file: VaultFile.samples[0])
            .environmentObject(AppState())
    }
}
