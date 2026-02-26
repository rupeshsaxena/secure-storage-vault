import SwiftUI
import UniformTypeIdentifiers

// MARK: - AddFileSheet (Screen 07)

struct AddFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddFileViewModel()
    @State private var showFilePicker = false
    
    private var allowedFileTypes: [UTType] {
        var types: [UTType] = [.pdf, .image, .audio, .video, .text, .plainText, .data, .content, .item]
        
        // Add Office document types
        if let doc = UTType(filenameExtension: "doc") { types.append(doc) }
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        if let xls = UTType(filenameExtension: "xls") { types.append(xls) }
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        if let ppt = UTType(filenameExtension: "ppt") { types.append(ppt) }
        if let pptx = UTType(filenameExtension: "pptx") { types.append(pptx) }
        
        return types
    }

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
                                Text("Encrypting with Secure Enclave…")
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
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(allowedTypes: allowedFileTypes) { result in
                    switch result {
                    case .success(let url):
                        vm.selectedFileURL = url
                    case .failure(let error):
                        vm.errorMessage = "Failed to select file: \(error.localizedDescription)"
                    }
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
    /// Indicates whether the last import used the SE (SCV2) path.
    @Published var usedSecureEnclave: Bool = false

    private let useCase: VaultUseCaseProtocol
    private let container = DependencyContainer.shared

    init(useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.useCase = useCase
    }

    func importFile() async {
        guard let url = selectedFileURL else { return }

        isEncrypting = true
        encryptionProgress = 0
        errorMessage = nil
        usedSecureEnclave = false

        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext  = url.pathExtension.lowercased()
            let fileType = fileTypeFromExtension(ext)

            encryptionProgress = 0.3

            // ── Prefer SCV2 Secure Enclave path ───────────────────────────
            if container.seService.hasIdentity,
               let keyPair = try? container.seService.loadKeyPair() {

                let contentType  = contentTypeFromExtension(ext)
                let encryptedData = try container.seEncryptionService.encryptFile(
                    data:        data,
                    keyPair:     keyPair,
                    filename:    url.lastPathComponent,
                    contentType: contentType
                )

                encryptionProgress = 0.8

                let file = VaultFile(
                    name:      url.lastPathComponent,
                    fileType:  fileType,
                    sizeBytes: Int64(data.count),
                    folderId:  nil
                )
                try await container.vaultRepository.addFile(file, encryptedData: encryptedData)
                usedSecureEnclave = true

            } else {
                // ── Fallback: SCV1 legacy password-based path ─────────────
                encryptionProgress = 0.5
                _ = try await useCase.importFile(
                    name:     url.lastPathComponent,
                    fileType: fileType,
                    data:     data,
                    password: "vault-master-key"    // SCV1 fallback (no SE identity)
                )
            }

            encryptionProgress = 1.0
        } catch {
            errorMessage = error.localizedDescription
        }

        isEncrypting = false
    }

    // MARK: - UTType helper

    private func contentTypeFromExtension(_ ext: String) -> String {
        switch ext {
        case "pdf":              return "com.adobe.pdf"
        case "jpg", "jpeg":      return "public.jpeg"
        case "png":              return "public.png"
        case "heic":             return "public.heic"
        case "mp3":              return "public.mp3"
        case "m4a":              return "com.apple.m4a-audio"
        case "wav":              return "com.microsoft.waveform-audio"
        case "mp4":              return "public.mpeg-4"
        case "mov":              return "com.apple.quicktime-movie"
        case "docx":             return "org.openxmlformats.wordprocessingml.document"
        case "doc":              return "com.microsoft.word.doc"
        case "xlsx":             return "org.openxmlformats.spreadsheetml.sheet"
        case "xls":              return "com.microsoft.excel.xls"
        case "pptx":             return "org.openxmlformats.presentationml.presentation"
        case "ppt":              return "com.microsoft.powerpoint.ppt"
        case "zip":              return "public.zip-archive"
        default:                 return "public.data"
        }
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

// MARK: - DocumentPicker

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let completion: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<URL, Error>) -> Void
        
        init(completion: @escaping (Result<URL, Error>) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                completion(.failure(NSError(domain: "DocumentPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])))
                return
            }
            completion(.success(url))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(.failure(NSError(domain: "DocumentPicker", code: -2, userInfo: [NSLocalizedDescriptionKey: "Selection cancelled"])))
        }
    }
}

// MARK: - Preview

#Preview {
    AddFileSheet()
}
