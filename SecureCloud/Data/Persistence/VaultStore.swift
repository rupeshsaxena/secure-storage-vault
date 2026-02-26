import Foundation

// MARK: - VaultStore
//
// In-memory store for MVP development. Replace the underlying storage
// with GRDB (see Package.swift) for production — the interface stays identical.

actor VaultStore {

    // MARK: - In-Memory State

    private var files: [UUID: VaultFile] = [:]
    private var folders: [UUID: VaultFolder] = [:]
    private var encryptedBlobs: [UUID: Data] = [:]   // fileId → encrypted bytes

    // MARK: - Files

    func fetchFiles(in folderId: UUID?) -> [VaultFile] {
        files.values.filter { $0.folderId == folderId }
            .sorted { $0.addedAt > $1.addedAt }
    }

    func fetchFile(id: UUID) throws -> VaultFile {
        guard let file = files[id] else { throw VaultStoreError.notFound }
        return file
    }

    func insertFile(_ file: VaultFile, encryptedData: Data) {
        files[file.id] = file
        encryptedBlobs[file.id] = encryptedData
    }

    func updateFile(_ file: VaultFile) throws {
        guard files[file.id] != nil else { throw VaultStoreError.notFound }
        files[file.id] = file
    }

    func deleteFile(id: UUID) {
        files.removeValue(forKey: id)
        encryptedBlobs.removeValue(forKey: id)
    }

    func search(query: String) -> [VaultFile] {
        files.values.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.name < $1.name }
    }

    func loadEncryptedData(for fileId: UUID) throws -> Data {
        guard let data = encryptedBlobs[fileId] else { throw VaultStoreError.notFound }
        return data
    }

    func saveEncryptedData(_ data: Data, for fileId: UUID) throws {
        guard files[fileId] != nil else { throw VaultStoreError.notFound }
        encryptedBlobs[fileId] = data
    }

    // MARK: - Folders

    func fetchFolders(in parentId: UUID?) -> [VaultFolder] {
        folders.values.filter { $0.parentId == parentId }
            .sorted { $0.name < $1.name }
    }

    func insertFolder(_ folder: VaultFolder) {
        folders[folder.id] = folder
    }

    func updateFolder(_ folder: VaultFolder) throws {
        guard folders[folder.id] != nil else { throw VaultStoreError.notFound }
        folders[folder.id] = folder
    }

    func deleteFolder(id: UUID) {
        folders.removeValue(forKey: id)
        // Cascade: unlink files in this folder
        for key in files.keys where files[key]?.folderId == id {
            files[key]?.folderId = nil
        }
    }

    // MARK: - Seed sample data (dev/preview only)

    func seedIfEmpty() {
        guard files.isEmpty && folders.isEmpty else { return }

        let sampleFolders = VaultFolder.samples
        for folder in sampleFolders {
            folders[folder.id] = folder
        }

        for file in VaultFile.samples {
            var mutableFile = file
            // Assign some files to the first folder
            if file.id == VaultFile.samples.first?.id {
                mutableFile.folderId = sampleFolders.first?.id
            }
            files[mutableFile.id] = mutableFile
            // Store dummy encrypted data blob for preview
            encryptedBlobs[mutableFile.id] = Data(count: 64)
        }
    }
}

// MARK: - VaultStoreError

enum VaultStoreError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested item was not found in the vault."
        }
    }
}
