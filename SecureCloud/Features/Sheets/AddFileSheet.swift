import SwiftUI
import UniformTypeIdentifiers

// MARK: - AddFileSheet (Screen 07)

struct AddFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddFileViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                ScrollView {
                    VStack(spacing: Tokens.Spacing.md) {

                        // Drop zone / pick zone
                        Button {
                            showFilePicker = true
                        } label: {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Tokens.Color.accentDim)
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "plus.circle.fill") // SF: plus.circle.fill
                                        .font(.system(size: 28))
                                        .foregroundStyle(Tokens.Color.accent)
                                }
                                VStack(spacing: 4) {
                                    Text("Choose File")
                                        .font(Tokens.Font.subheadline())
                                        .foregroundStyle(Tokens.Color.textPrimary)
                                    Text("PDF, images, audio, video, docs")
                                        .font(Tokens.Font.caption2())
                                        .foregroundStyle(Tokens.Color.textTertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .glassCard()
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                    )
                                    .foregroundStyle(Tokens.Color.accent.opacity(0.3))
                            )
                        }
                        .buttonStyle(.plain)

                        // Selected file info
                        if let selectedFile = vm.selectedFileURL {
                            selectedFileCard(url: selectedFile)
                        }

                        // Progress
                        if vm.isEncrypting {
                            VStack(spacing: 8) {
                                ProgressView(value: vm.encryptionProgress)
                                    .tint(Tokens.Color.accent)
                                Text("Encrypting with AES-256-GCM…")
                                    .font(Tokens.Font.caption1())
                                    .foregroundStyle(Tokens.Color.textSecondary)
                            }
                            .padding()
                            .glassCard()
                        }

                        // Error
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(Tokens.Font.caption1())
                                .foregroundStyle(Tokens.Color.red)
                                .padding()
                                .glassCard()
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Add File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            await vm.importFile()
                            if vm.errorMessage == nil { dismiss() }
                        }
                    }
                    .font(Tokens.Font.body(.semibold))
                    .foregroundStyle(
                        vm.selectedFileURL == nil ? Tokens.Color.textTertiary : Tokens.Color.accent
                    )
                    .disabled(vm.selectedFileURL == nil || vm.isEncrypting)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    vm.selectedFileURL = urls.first
                case .failure:
                    vm.errorMessage = "Failed to access the selected file."
                }
            }
        }
    }

    private func selectedFileCard(url: URL) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.iconSm)
                    .fill(Tokens.Color.greenDim)
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.fill") // SF: doc.fill
                    .font(.system(size: 16))
                    .foregroundStyle(Tokens.Color.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(Tokens.Font.body(.medium))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                Text("Ready to encrypt")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.green)
            }

            Spacer()

            Button {
                vm.selectedFileURL = nil
            } label: {
                Image(systemName: "xmark.circle.fill") // SF: xmark.circle.fill
                    .font(.system(size: 16))
                    .foregroundStyle(Tokens.Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassCard(radius: Tokens.Radius.cardSm)
    }
}

// MARK: - AddFileViewModel

@MainActor
final class AddFileViewModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var isEncrypting: Bool = false
    @Published var encryptionProgress: Double = 0
    @Published var errorMessage: String?

    private let useCase: VaultUseCaseProtocol

    init(useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.useCase = useCase
    }

    func importFile() async {
        guard let url = selectedFileURL else { return }

        isEncrypting = true
        encryptionProgress = 0
        errorMessage = nil

        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let fileType = fileTypeFromExtension(ext)

            encryptionProgress = 0.5

            _ = try await useCase.importFile(
                name: url.lastPathComponent,
                fileType: fileType,
                data: data,
                password: "vault-master-key"    // TODO: load from KeychainService
            )

            encryptionProgress = 1.0
        } catch {
            errorMessage = error.localizedDescription
        }

        isEncrypting = false
    }

    private func fileTypeFromExtension(_ ext: String) -> VaultFile.FileType {
        switch ext {
        case "pdf":                         return .pdf
        case "jpg", "jpeg", "png", "heic": return .image
        case "pptx", "ppt":               return .pptx
        case "xlsx", "xls":               return .xlsx
        case "zip":                         return .zip
        case "mp3":                         return .mp3
        case "m4a":                         return .m4a
        case "wav":                         return .wav
        case "mp4":                         return .mp4
        case "mov":                         return .mov
        case "docx", "doc":               return .docx
        default:                            return .generic
        }
    }
}

// MARK: - Preview

#Preview {
    AddFileSheet()
}
