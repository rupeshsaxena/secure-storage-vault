import Foundation

// MARK: - VaultFolder

struct VaultFolder: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var fileCount: Int
    var syncStatus: SyncStatus
    var parentId: UUID?
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fileCount: Int = 0,
        syncStatus: SyncStatus = .localOnly,
        parentId: UUID? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileCount = fileCount
        self.syncStatus = syncStatus
        self.parentId = parentId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Sample data

extension VaultFolder {
    static let samples: [VaultFolder] = [
        VaultFolder(name: "Work Documents", fileCount: 12, syncStatus: .synced),
        VaultFolder(name: "Personal",       fileCount: 5,  syncStatus: .pending),
        VaultFolder(name: "Media Archive",  fileCount: 30, syncStatus: .localOnly),
    ]
}
