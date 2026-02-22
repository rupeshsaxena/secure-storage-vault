import Foundation

// MARK: - MetadataStore
//
// Persists lightweight file metadata (name, type, sync status, folder assignments)
// independently from the encrypted blob store.
//
// MVP: JSON file on disk inside the app's Application Support directory.
// v2:  Swap for GRDB SQLite — the actor interface doesn't change.

actor MetadataStore {

    // MARK: - Storage

    private let fileURL: URL
    private var cache: [UUID: FileMetadata] = [:]

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaultDir = dir.appendingPathComponent("SecureCloud", isDirectory: true)
        try? FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        self.fileURL = vaultDir.appendingPathComponent("metadata.json")
        loadFromDisk()
    }

    // MARK: - CRUD

    func all() -> [FileMetadata] {
        Array(cache.values).sorted { $0.addedAt > $1.addedAt }
    }

    func fetch(id: UUID) -> FileMetadata? {
        cache[id]
    }

    func insert(_ metadata: FileMetadata) {
        cache[metadata.id] = metadata
        saveToDisk()
    }

    func update(_ metadata: FileMetadata) {
        cache[metadata.id] = metadata
        saveToDisk()
    }

    func delete(id: UUID) {
        cache.removeValue(forKey: id)
        saveToDisk()
    }

    func search(query: String) -> [FileMetadata] {
        cache.values.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([UUID: FileMetadata].self, from: data)
        else { return }
        cache = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - FileMetadata

struct FileMetadata: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var fileType: VaultFile.FileType
    var sizeBytes: Int64
    var syncStatus: SyncStatus
    var isLocked: Bool
    var folderId: UUID?
    var addedAt: Date
    var modifiedAt: Date
    var encryptionStandard: String

    init(from file: VaultFile) {
        self.id = file.id
        self.name = file.name
        self.fileType = file.fileType
        self.sizeBytes = file.sizeBytes
        self.syncStatus = file.syncStatus
        self.isLocked = file.isLocked
        self.folderId = file.folderId
        self.addedAt = file.addedAt
        self.modifiedAt = file.modifiedAt
        self.encryptionStandard = file.encryptionStandard
    }

    func toVaultFile() -> VaultFile {
        VaultFile(
            id: id,
            name: name,
            fileType: fileType,
            sizeBytes: sizeBytes,
            encryptionStandard: encryptionStandard,
            syncStatus: syncStatus,
            isLocked: isLocked,
            folderId: folderId,
            addedAt: addedAt,
            modifiedAt: modifiedAt
        )
    }
}
