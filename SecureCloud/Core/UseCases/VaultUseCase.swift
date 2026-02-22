import Foundation

// MARK: - VaultUseCaseProtocol

protocol VaultUseCaseProtocol: Sendable {
    func loadFiles(in folderId: UUID?) async throws -> [VaultFile]
    func loadFolders(in parentId: UUID?) async throws -> [VaultFolder]
    func importFile(name: String, fileType: VaultFile.FileType, data: Data, password: String) async throws -> VaultFile
    func deleteFile(id: UUID) async throws
    func createFolder(name: String, parentId: UUID?) async throws -> VaultFolder
    func deleteFolder(id: UUID) async throws
    func search(query: String) async throws -> [VaultFile]
    func loadDecryptedData(for fileId: UUID, password: String) async throws -> Data
}

// MARK: - VaultUseCase

final class VaultUseCase: VaultUseCaseProtocol, Sendable {
    private let repository: VaultRepositoryProtocol
    private let encryption: EncryptionServiceProtocol

    init(repository: VaultRepositoryProtocol, encryption: EncryptionServiceProtocol) {
        self.repository = repository
        self.encryption = encryption
    }

    func loadFiles(in folderId: UUID? = nil) async throws -> [VaultFile] {
        try await repository.fetchFiles(in: folderId)
    }

    func loadFolders(in parentId: UUID? = nil) async throws -> [VaultFolder] {
        try await repository.fetchFolders(in: parentId)
    }

    func importFile(
        name: String,
        fileType: VaultFile.FileType,
        data: Data,
        password: String
    ) async throws -> VaultFile {
        let encryptedData = try encryption.encrypt(data: data, password: password)

        let file = VaultFile(
            name: name,
            fileType: fileType,
            sizeBytes: Int64(data.count),
            encryptionStandard: "AES-256-GCM",
            syncStatus: .localOnly
        )

        try await repository.addFile(file, encryptedData: encryptedData)
        return file
    }

    func deleteFile(id: UUID) async throws {
        try await repository.deleteFile(id: id)
    }

    func createFolder(name: String, parentId: UUID? = nil) async throws -> VaultFolder {
        let folder = VaultFolder(name: name, parentId: parentId)
        try await repository.createFolder(folder)
        return folder
    }

    func deleteFolder(id: UUID) async throws {
        try await repository.deleteFolder(id: id)
    }

    func search(query: String) async throws -> [VaultFile] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.search(query: query)
    }

    func loadDecryptedData(for fileId: UUID, password: String) async throws -> Data {
        let encryptedData = try await repository.loadEncryptedData(for: fileId)
        return try encryption.decrypt(data: encryptedData, password: password)
    }
}
