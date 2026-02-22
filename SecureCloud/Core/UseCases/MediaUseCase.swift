import Foundation

// MARK: - MediaUseCaseProtocol

protocol MediaUseCaseProtocol: Sendable {
    /// Decrypt a media file's data into memory for playback — never touches disk as plaintext
    func decryptedMediaData(for fileId: UUID) async throws -> Data

    /// Fetch track metadata
    func fetchMediaItem(for fileId: UUID) async throws -> MediaItem

    /// Build a playback queue
    func buildQueue(from fileIds: [UUID]) async throws -> [MediaItem]
}

// MARK: - MediaUseCase

final class MediaUseCase: MediaUseCaseProtocol, Sendable {
    private let repository: MediaRepositoryProtocol

    init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }

    func decryptedMediaData(for fileId: UUID) async throws -> Data {
        try await repository.decryptedData(for: fileId)
    }

    func fetchMediaItem(for fileId: UUID) async throws -> MediaItem {
        try await repository.fetchMediaItem(for: fileId)
    }

    func buildQueue(from fileIds: [UUID]) async throws -> [MediaItem] {
        try await repository.buildQueue(from: fileIds)
    }
}
