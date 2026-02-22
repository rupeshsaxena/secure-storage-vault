import Foundation

// MARK: - SyncStatus

enum SyncStatus: String, Codable, CaseIterable, Sendable {
    case synced
    case pending
    case localOnly
    case syncing
    case failed

    var label: String {
        switch self {
        case .synced:    return "Synced"
        case .pending:   return "Pending upload"
        case .localOnly: return "Local only"
        case .syncing:   return "Syncing"
        case .failed:    return "Failed"
        }
    }

    var icon: String {  // SF Symbol
        switch self {
        case .synced:    return "checkmark.circle.fill"
        case .pending:   return "icloud.and.arrow.up"
        case .localOnly: return "externaldrive"
        case .syncing:   return "arrow.clockwise"
        case .failed:    return "exclamationmark.icloud"
        }
    }

    /// Token color key — resolved in Tokens.swift via StatusBadge
    var colorKey: String {
        switch self {
        case .synced:    return "green"
        case .pending:   return "orange"
        case .localOnly: return "secondary"
        case .syncing:   return "accent"
        case .failed:    return "red"
        }
    }
}
