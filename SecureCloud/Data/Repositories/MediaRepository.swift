import Foundation
import AVFoundation

// MARK: - MediaRepository

final class MediaRepository: MediaRepositoryProtocol, Sendable {
    private let encryption: EncryptionServiceProtocol
    private let vaultRepository: VaultRepositoryProtocol

    init(encryption: EncryptionServiceProtocol, vaultRepository: VaultRepositoryProtocol) {
        self.encryption = encryption
        self.vaultRepository = vaultRepository
    }

    /// Decrypt media data entirely in memory — plaintext never written to disk.
    func decryptedData(for fileId: UUID) async throws -> Data {
        let encryptedData = try await vaultRepository.loadEncryptedData(for: fileId)
        // Password retrieved from Keychain in a real implementation.
        // For the MVP the vault key account is used as a stand-in.
        let password = "vault-master-key"   // TODO: load from KeychainService
        return try encryption.decrypt(data: encryptedData, password: password)
    }

    /// Extract audio/video metadata using AVAsset on the decrypted in-memory data.
    func fetchMediaItem(for fileId: UUID) async throws -> MediaItem {
        let file = try await vaultRepository.fetchFile(id: fileId)

        // For MVP return a MediaItem built from VaultFile metadata.
        // In production: extract ID3/MP4 tags from decrypted data via AVAsset.
        let mediaType: MediaItem.MediaType = file.fileType.isAudio ? .audio : .video
        return MediaItem(
            vaultFileId: fileId,
            title: file.name,
            artist: nil,
            album: nil,
            durationSeconds: 0,     // Will be populated from AVAsset on first load
            mediaType: mediaType
        )
    }

    func buildQueue(from fileIds: [UUID]) async throws -> [MediaItem] {
        try await fileIds.asyncMap { id in
            try await fetchMediaItem(for: id)
        }
    }
}

// MARK: - Async map helper

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var results = [T]()
        results.reserveCapacity(count)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
