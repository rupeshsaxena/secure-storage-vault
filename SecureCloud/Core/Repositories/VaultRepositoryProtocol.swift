import Foundation

// MARK: - VaultRepositoryProtocol

protocol VaultRepositoryProtocol: Sendable {
    // MARK: Files
    func fetchFiles(in folderId: UUID?) async throws -> [VaultFile]
    func fetchFile(id: UUID) async throws -> VaultFile
    func addFile(_ file: VaultFile, encryptedData: Data) async throws
    func updateFile(_ file: VaultFile) async throws
    func deleteFile(id: UUID) async throws
    func moveFile(id: UUID, toFolder folderId: UUID?) async throws
    func search(query: String) async throws -> [VaultFile]

    // MARK: Folders
    func fetchFolders(in parentId: UUID?) async throws -> [VaultFolder]
    func createFolder(_ folder: VaultFolder) async throws
    func updateFolder(_ folder: VaultFolder) async throws
    func deleteFolder(id: UUID) async throws

    // MARK: Encrypted data access
    func loadEncryptedData(for fileId: UUID) async throws -> Data
}
