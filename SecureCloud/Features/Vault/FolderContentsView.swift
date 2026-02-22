import SwiftUI

// MARK: - FolderContentsView (Screen 12)

struct FolderContentsView: View {
    let folder: VaultFolder
    @StateObject private var vm: FolderContentsViewModel
    @State private var showAddFile = false

    init(folder: VaultFolder) {
        self.folder = folder
        self._vm = StateObject(wrappedValue: FolderContentsViewModel(folder: folder))
    }

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            Group {
                if vm.files.isEmpty && !vm.isLoading {
                    folderEmptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.files) { file in
                                NavigationLink(value: file) {
                                    FileRowView(file: file)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteFile(id: file.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash") // SF: trash
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Tokens.Spacing.lg)
                        .padding(.top, 12)
                        .padding(.bottom, 90)
                    }
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddFile = true
                } label: {
                    Image(systemName: "plus") // SF: plus
                        .iconButtonAccent()
                }
            }
        }
        .sheet(isPresented: $showAddFile) { AddFileSheet() }
        .navigationDestination(for: VaultFile.self) { file in
            if file.fileType.isAudio {
                AudioPlayerView(file: file)
            } else if file.fileType.isVideo {
                VideoPlayerView(file: file)
            } else {
                FileDetailView(file: file)
            }
        }
        .task { await vm.load() }
    }

    private var folderEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder") // SF: folder
                .font(.system(size: 48))
                .foregroundStyle(Tokens.Color.textTertiary)
            Text("No files in this folder")
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textSecondary)
            Button("Add File") { showAddFile = true }
                .font(Tokens.Font.body(.medium))
                .foregroundStyle(Tokens.Color.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FolderContentsViewModel

@MainActor
final class FolderContentsViewModel: ObservableObject {
    let folder: VaultFolder
    @Published var files: [VaultFile] = []
    @Published var isLoading = false

    private let useCase: VaultUseCaseProtocol

    init(
        folder: VaultFolder,
        useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase
    ) {
        self.folder = folder
        self.useCase = useCase
    }

    func load() async {
        isLoading = true
        files = (try? await useCase.loadFiles(in: folder.id)) ?? []
        isLoading = false
    }

    func deleteFile(id: UUID) async {
        try? await useCase.deleteFile(id: id)
        files.removeAll { $0.id == id }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FolderContentsView(folder: VaultFolder.samples[0])
            .environmentObject(AppState())
    }
}
