import Foundation

// MARK: - SyncDevice

struct SyncDevice: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var model: String           // e.g. "iPhone 15 Pro"
    var platform: Platform
    var lastSeen: Date
    var isThisDevice: Bool
    var syncedFileCount: Int
    var pendingFileCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        model: String,
        platform: Platform,
        lastSeen: Date = Date(),
        isThisDevice: Bool = false,
        syncedFileCount: Int = 0,
        pendingFileCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.platform = platform
        self.lastSeen = lastSeen
        self.isThisDevice = isThisDevice
        self.syncedFileCount = syncedFileCount
        self.pendingFileCount = pendingFileCount
    }
}

// MARK: - Platform

extension SyncDevice {
    enum Platform: String, Codable, Sendable {
        case iOS
        case macOS
        case iPadOS

        var icon: String {  // SF Symbol
            switch self {
            case .iOS:    return "iphone"
            case .macOS:  return "laptopcomputer"
            case .iPadOS: return "ipad"
            }
        }
    }
}

// MARK: - Sample data

extension SyncDevice {
    static let samples: [SyncDevice] = [
        SyncDevice(
            name: "Rupesh's iPhone",
            model: "iPhone 15 Pro",
            platform: .iOS,
            lastSeen: Date(),
            isThisDevice: true,
            syncedFileCount: 48,
            pendingFileCount: 0
        ),
        SyncDevice(
            name: "MacBook Pro",
            model: "MacBook Pro 14\"",
            platform: .macOS,
            lastSeen: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            isThisDevice: false,
            syncedFileCount: 48,
            pendingFileCount: 3
        ),
    ]
}
