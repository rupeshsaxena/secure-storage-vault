import Foundation

// MARK: - MediaItem

struct MediaItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var vaultFileId: UUID       // References underlying VaultFile
    var title: String
    var artist: String?
    var album: String?
    var durationSeconds: Double
    var artworkData: Data?      // Embedded thumbnail, decrypted in memory
    var mediaType: MediaType

    init(
        id: UUID = UUID(),
        vaultFileId: UUID,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        durationSeconds: Double = 0,
        artworkData: Data? = nil,
        mediaType: MediaType
    ) {
        self.id = id
        self.vaultFileId = vaultFileId
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.artworkData = artworkData
        self.mediaType = mediaType
    }
}

// MARK: - MediaType

extension MediaItem {
    enum MediaType: String, Codable, Sendable {
        case audio
        case video

        var icon: String {  // SF Symbol
            switch self {
            case .audio: return "waveform"
            case .video: return "video.fill"
            }
        }
    }
}

// MARK: - Duration formatting

extension MediaItem {
    var formattedDuration: String {
        let totalSeconds = Int(durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Sample data

extension MediaItem {
    static let audioSamples: [MediaItem] = [
        MediaItem(
            vaultFileId: UUID(),
            title: "Podcast Episode 42",
            artist: "TechTalks",
            album: "TechTalks Season 3",
            durationSeconds: 2888,
            mediaType: .audio
        ),
        MediaItem(
            vaultFileId: UUID(),
            title: "Meeting Recording",
            artist: nil,
            album: nil,
            durationSeconds: 3600,
            mediaType: .audio
        ),
    ]
}
