import Foundation

// MARK: - VaultFile

struct VaultFile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var fileType: FileType
    var sizeBytes: Int64
    var encryptionStandard: String      // "AES-256-GCM"
    var syncStatus: SyncStatus
    var isLocked: Bool
    var folderId: UUID?
    var addedAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fileType: FileType,
        sizeBytes: Int64,
        encryptionStandard: String = "AES-256-GCM",
        syncStatus: SyncStatus = .localOnly,
        isLocked: Bool = false,
        folderId: UUID? = nil,
        addedAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.sizeBytes = sizeBytes
        self.encryptionStandard = encryptionStandard
        self.syncStatus = syncStatus
        self.isLocked = isLocked
        self.folderId = folderId
        self.addedAt = addedAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - FileType

extension VaultFile {
    enum FileType: String, Codable, CaseIterable, Sendable {
        case pdf, image, pptx, xlsx, zip, mp3, m4a, wav, mp4, mov, docx, generic

        var icon: String {  // SF Symbol name
            switch self {
            case .pdf, .docx, .pptx, .xlsx, .generic:
                return "doc.fill"
            case .image:
                return "photo"
            case .zip:
                return "doc.zipper"
            case .mp3, .m4a, .wav:
                return "waveform"
            case .mp4, .mov:
                return "video.fill"
            }
        }

        var filterCategory: FileFilter {
            switch self {
            case .mp3, .m4a, .wav:          return .audio
            case .mp4, .mov:                return .video
            case .image:                    return .images
            case .pdf, .docx, .pptx, .xlsx, .zip, .generic: return .documents
            }
        }

        var isAudio: Bool { filterCategory == .audio }
        var isVideo: Bool { filterCategory == .video }
    }
}

// MARK: - FileFilter

enum FileFilter: String, CaseIterable, Identifiable, Sendable {
    case all       = "All"
    case documents = "Documents"
    case images    = "Images"
    case audio     = "Audio"
    case video     = "Video"

    var id: String { rawValue }
}

// MARK: - Sample data (for development / previews)

extension VaultFile {
    static let samples: [VaultFile] = [
        VaultFile(
            name: "Q4 Report.pdf",
            fileType: .pdf,
            sizeBytes: 2_400_000,
            syncStatus: .synced
        ),
        VaultFile(
            name: "Presentation.pptx",
            fileType: .pptx,
            sizeBytes: 8_100_000,
            syncStatus: .pending
        ),
        VaultFile(
            name: "Cover Photo.jpg",
            fileType: .image,
            sizeBytes: 3_200_000,
            syncStatus: .synced
        ),
        VaultFile(
            name: "Podcast Episode 42.mp3",
            fileType: .mp3,
            sizeBytes: 45_000_000,
            syncStatus: .localOnly
        ),
        VaultFile(
            name: "Demo Reel.mp4",
            fileType: .mp4,
            sizeBytes: 120_000_000,
            syncStatus: .syncing
        ),
        VaultFile(
            name: "Backup.zip",
            fileType: .zip,
            sizeBytes: 512_000,
            syncStatus: .failed,
            isLocked: true
        ),
    ]
}
