import Foundation

// MARK: - MediaRepositoryProtocol

protocol MediaRepositoryProtocol: Sendable {
    /// Decrypt media file to in-memory Data — never written to disk as plaintext
    func decryptedData(for fileId: UUID) async throws -> Data

    /// Fetch metadata (title, artist, duration) for a media file
    func fetchMediaItem(for fileId: UUID) async throws -> MediaItem

    /// Build an ordered playback queue from the given file IDs
    func buildQueue(from fileIds: [UUID]) async throws -> [MediaItem]
}
