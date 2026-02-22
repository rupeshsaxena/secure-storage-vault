import Foundation
import SwiftUI

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Security Settings
    @Published var biometricEnabled: Bool = true
    @Published var autoLockDelay: AutoLockDelay = .immediately
    @Published var screenshotBlockEnabled: Bool = true

    // MARK: - Sync Settings
    @Published var wifiOnlySync: Bool = true
    @Published var autoSyncEnabled: Bool = true
    @Published var backgroundSyncEnabled: Bool = false

    // MARK: - App Info
    let appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    // MARK: - AutoLockDelay

    enum AutoLockDelay: String, CaseIterable, Identifiable {
        case immediately = "Immediately"
        case oneMinute   = "1 Minute"
        case fiveMinutes = "5 Minutes"
        case tenMinutes  = "10 Minutes"
        case never       = "Never"

        var id: String { rawValue }
    }

    // MARK: - Actions

    func lockVault(appState: AppState) {
        appState.lockVault()
    }

    func exportEncryptedBackup() async {
        // Implementation: build encrypted .scvault bundle
    }

    func clearLocalCache() async {
        // Implementation: wipe non-synced temp files
    }
}
