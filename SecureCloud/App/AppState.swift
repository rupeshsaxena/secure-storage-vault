import SwiftUI

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published

    @Published var isVaultLocked: Bool = true
    @Published var activeTab: AppTab = .vault
    @Published var vaultSyncState: VaultSyncState = .protected

    // MARK: - VaultSyncState

    enum VaultSyncState: Equatable {
        case syncing(progress: Double)
        case protected
        case empty

        static func == (lhs: VaultSyncState, rhs: VaultSyncState) -> Bool {
            switch (lhs, rhs) {
            case (.protected, .protected): return true
            case (.empty, .empty):         return true
            case (.syncing(let l), .syncing(let r)): return l == r
            default: return false
            }
        }
    }

    // MARK: - Actions

    func unlockVault() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVaultLocked = false
        }
    }

    func lockVault() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isVaultLocked = true
        }
    }

    func beginSync(progress: Double) {
        vaultSyncState = .syncing(progress: progress)
    }

    func finishSync() {
        vaultSyncState = .protected
    }

    func markEmpty() {
        vaultSyncState = .empty
    }
}
