import Foundation

// MARK: - VaultRepository

final class VaultRepository: VaultRepositoryProtocol, Sendable {
    private let store: VaultStore
    private let encryption: EncryptionServiceProtocol
    private let keychain: KeychainServiceProtocol

    init(encryption: EncryptionServiceProtocol, keychain: KeychainServiceProtocol) {
        self.store = VaultStore()
        self.encryption = encryption
        self.keychain = keychain
    }

    // MARK: - Files

    func fetchFiles(in folderId: UUID?) async throws -> [VaultFile] {
        await store.fetchFiles(in: folderId)
    }

    func fetchFile(id: UUID) async throws -> VaultFile {
        try await store.fetchFile(id: id)
    }

    func addFile(_ file: VaultFile, encryptedData: Data) async throws {
        await store.insertFile(file, encryptedData: encryptedData)
    }

    func updateFile(_ file: VaultFile) async throws {
        try await store.updateFile(file)
    }

    func deleteFile(id: UUID) async throws {
        await store.deleteFile(id: id)
    }

    func moveFile(id: UUID, toFolder folderId: UUID?) async throws {
        var file = try await store.fetchFile(id: id)
        file.folderId = folderId
        try await store.updateFile(file)
    }

    func search(query: String) async throws -> [VaultFile] {
        await store.search(query: query)
    }

    // MARK: - Folders

    func fetchFolders(in parentId: UUID?) async throws -> [VaultFolder] {
        await store.fetchFolders(in: parentId)
    }

    func createFolder(_ folder: VaultFolder) async throws {
        await store.insertFolder(folder)
    }

    func updateFolder(_ folder: VaultFolder) async throws {
        try await store.updateFolder(folder)
    }

    func deleteFolder(id: UUID) async throws {
        await store.deleteFolder(id: id)
    }

    // MARK: - Encrypted data

    func loadEncryptedData(for fileId: UUID) async throws -> Data {
        try await store.loadEncryptedData(for: fileId)
    }
}
