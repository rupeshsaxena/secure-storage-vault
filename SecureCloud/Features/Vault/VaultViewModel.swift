import Foundation
import SwiftUI

// MARK: - VaultViewModel

@MainActor
final class VaultViewModel: ObservableObject {

    // MARK: - Published State

    @Published var files: [VaultFile] = []
    @Published var folders: [VaultFolder] = []
    @Published var syncState: AppState.VaultSyncState = .protected
    @Published var searchText: String = ""
    @Published var activeFilter: FileFilter = .all
    @Published var showSortSheet: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Filtered Files

    var filteredFiles: [VaultFile] {
        files.filter { file in
            let matchesSearch = searchText.isEmpty ||
                file.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = activeFilter == .all ||
                file.fileType.filterCategory == activeFilter
            return matchesSearch && matchesFilter
        }
    }

    // MARK: - Dependencies

    private let useCase: VaultUseCaseProtocol

    init(useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.useCase = useCase
    }

    // MARK: - Load

    func load(folderId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            async let filesTask = useCase.loadFiles(in: folderId)
            async let foldersTask = useCase.loadFolders(in: folderId)
            let (fetchedFiles, fetchedFolders) = try await (filesTask, foldersTask)
            files = fetchedFiles
            folders = fetchedFolders
            syncState = files.isEmpty && folders.isEmpty ? .empty : .protected
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Search

    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            await load()
            return
        }
        do {
            files = try await useCase.search(query: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteFile(id: UUID) async {
        do {
            try await useCase.deleteFile(id: id)
            files.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFolder(id: UUID) async {
        do {
            try await useCase.deleteFolder(id: id)
            folders.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
