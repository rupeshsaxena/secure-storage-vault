import SwiftUI
import UIKit

// MARK: - ShareSheet (Screen 13)
//
// Two share modes:
//   • "Share Encrypted" — Secure Enclave path (SCV2): wraps FEK for a trusted
//     contact; the file stays encrypted end-to-end.
//   • "Export Decrypted" — Legacy path: decrypts the file to a temp URL and
//     opens the system share sheet.  A prominent warning is shown.

struct ShareSheet: View {
    let file: VaultFile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ShareSheetViewModel

    @State private var showContactShare = false
    @State private var showActivity     = false
    @State private var activityItems: [Any] = []

    init(file: VaultFile) {
        self.file = file
        self._vm = StateObject(wrappedValue: ShareSheetViewModel(file: file))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                ScrollView {
                    VStack(spacing: Tokens.Spacing.md) {

                        // ── File info ──────────────────────────────────────
                        fileCard

                        // ── SE encrypted share ─────────────────────────────
                        encryptedShareOption

                        // ── Divider ────────────────────────────────────────
                        HStack {
                            Rectangle()
                                .fill(Tokens.Color.border)
                                .frame(height: 1)
                            Text("OR")
                                .font(Tokens.Font.label())
                                .foregroundStyle(Tokens.Color.textTertiary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Tokens.Color.border)
                                .frame(height: 1)
                        }

                        // ── Legacy export ──────────────────────────────────
                        legacyExportSection

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, Tokens.Spacing.xl)
                }
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
            .sheet(isPresented: $showContactShare) {
                ContactShareView(file: file) {
                    showContactShare = false
                    dismiss()
                }
            }
            .sheet(isPresented: $showActivity, onDismiss: {
                Task { await vm.cleanupTemp() }
            }) {
                ActivityView(items: activityItems)
            }
        }
    }

    // MARK: - Sub-views

    private var fileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 44, height: 44)
                Image(systemName: file.fileType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Tokens.Color.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
            }
            Spacer()
            Image(systemName: "lock.fill")  // SF: lock.fill
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Color.green)
        }
        .padding(12)
        .glassCard()
    }

    private var encryptedShareOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")  // SF: lock.shield.fill
                    .foregroundStyle(Tokens.Color.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Encrypted (Recommended)")
                        .font(Tokens.Font.subheadline())
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text("File stays encrypted. Only the recipient's Secure Enclave can decrypt it.")
                        .font(Tokens.Font.caption1())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }

            Button {
                showContactShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")  // SF: person.badge.key.fill
                        .font(.system(size: 14))
                    Text("Choose Recipient")
                        .font(Tokens.Font.subheadline())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Color.green)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    private var legacyExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")  // SF: exclamationmark.triangle.fill
                    .foregroundStyle(Tokens.Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Decrypted")
                        .font(Tokens.Font.subheadline())
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text("The exported copy will NOT be encrypted.")
                        .font(Tokens.Font.caption1())
                        .foregroundStyle(Tokens.Color.orange)
                }
            }

            Button {
                Task {
                    await vm.prepareAndShare { items in
                        activityItems = items
                        showActivity = true
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if vm.isPreparing {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "square.and.arrow.up")  // SF: square.and.arrow.up
                            .font(.system(size: 14))
                    }
                    Text(vm.isPreparing ? "Decrypting…" : "Export & Share")
                        .font(Tokens.Font.subheadline())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Color.orange)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isPreparing)
        }
        .padding(14)
        .glassCard()
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
                fileId:   file.id,
                password: "vault-master-key"    // TODO: migrate to SE key when SCV1 deprecated
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

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
