import Foundation

// MARK: - ShareUseCaseProtocol

protocol ShareUseCaseProtocol: Sendable {
    /// Decrypt a file to a temporary location for sharing, then clean up after share completes.
    /// The plaintext is written to a temp URL valid only for the duration of the share sheet.
    func prepareForSharing(fileId: UUID, password: String) async throws -> URL

    /// Removes the temporary plaintext file. Must be called after share sheet dismisses.
    func cleanupAfterSharing(tempURL: URL) async
}

// MARK: - ShareUseCase

final class ShareUseCase: ShareUseCaseProtocol, Sendable {
    private let vault: VaultRepositoryProtocol
    private let encryption: EncryptionServiceProtocol

    init(vault: VaultRepositoryProtocol, encryption: EncryptionServiceProtocol) {
        self.vault = vault
        self.encryption = encryption
    }

    func prepareForSharing(fileId: UUID, password: String) async throws -> URL {
        let encryptedData = try await vault.loadEncryptedData(for: fileId)
        let plaintextData = try encryption.decrypt(data: encryptedData, password: password)
        let file = try await vault.fetchFile(id: fileId)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureCloudShare", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempURL = tempDir.appendingPathComponent(file.name)
        try plaintextData.write(to: tempURL, options: .atomic)
        return tempURL
    }

    func cleanupAfterSharing(tempURL: URL) async {
        try? FileManager.default.removeItem(at: tempURL)

        // Also wipe the entire temp share directory
        let tempDir = tempURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: tempDir)
    }
}
