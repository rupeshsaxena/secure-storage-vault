import SwiftUI

// MARK: - ShareSheet (Screen 13)

struct ShareSheet: View {
    let file: VaultFile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ShareSheetViewModel
    @State private var activityItems: [Any] = []
    @State private var showActivity = false

    init(file: VaultFile) {
        self.file = file
        self._vm = StateObject(wrappedValue: ShareSheetViewModel(file: file))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                VStack(spacing: Tokens.Spacing.md) {

                    // Warning banner
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill") // SF: exclamationmark.triangle.fill
                            .foregroundStyle(Tokens.Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("File will be decrypted for sharing")
                                .font(Tokens.Font.body(.semibold))
                                .foregroundStyle(Tokens.Color.orange)
                            Text("The exported copy will not be encrypted.")
                                .font(Tokens.Font.caption2())
                                .foregroundStyle(Tokens.Color.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .glassCard()
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                            .stroke(Tokens.Color.orange.opacity(0.20), lineWidth: 1)
                    )

                    // File info card
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                                .fill(Tokens.Color.accentDim)
                                .frame(width: 44, height: 44)
                            Image(systemName: file.fileType.icon) // SF: varies
                                .font(.system(size: 18))
                                .foregroundStyle(Tokens.Color.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.name)
                                .font(Tokens.Font.body(.medium))
                                .foregroundStyle(Tokens.Color.textPrimary)
                            Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                                .font(Tokens.Font.caption2())
                                .foregroundStyle(Tokens.Color.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .glassCard()

                    // Export button
                    Button {
                        Task { await vm.prepareAndShare { items in
                            activityItems = items
                            showActivity = true
                        }}
                    } label: {
                        HStack(spacing: 10) {
                            if vm.isPreparing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "square.and.arrow.up") // SF: square.and.arrow.up
                                    .font(.system(size: 16))
                            }
                            Text(vm.isPreparing ? "Decrypting…" : "Export & Share")
                                .font(Tokens.Font.subheadline())
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Tokens.Color.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isPreparing)

                    Spacer()
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.top, 16)
            }
            .navigationTitle("Share File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            .sheet(isPresented: $showActivity, onDismiss: {
                Task { await vm.cleanupTemp() }
            }) {
                ActivityView(items: activityItems)
            }
        }
    }
}

// MARK: - ShareSheetViewModel

@MainActor
final class ShareSheetViewModel: ObservableObject {
    let file: VaultFile
    @Published var isPreparing: Bool = false
    @Published var errorMessage: String?

    private var tempURL: URL?
    private let useCase: ShareUseCaseProtocol

    init(
        file: VaultFile,
        useCase: ShareUseCaseProtocol = DependencyContainer.shared.shareUseCase
    ) {
        self.file = file
        self.useCase = useCase
    }

    func prepareAndShare(completion: ([Any]) -> Void) async {
        isPreparing = true
        do {
            let url = try await useCase.prepareForSharing(
                fileId: file.id,
                password: "vault-master-key"   // TODO: load from KeychainService
            )
            tempURL = url
            completion([url])
        } catch {
            errorMessage = error.localizedDescription
        }
        isPreparing = false
    }

    func cleanupTemp() async {
        if let url = tempURL {
            await useCase.cleanupAfterSharing(tempURL: url)
            tempURL = nil
        }
    }
}

// MARK: - ActivityView (UIKit bridge)

import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
