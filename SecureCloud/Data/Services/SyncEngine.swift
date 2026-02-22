import Foundation
import BackgroundTasks

// MARK: - SyncEngine
//
// Coordinates background sync using BGProcessingTask.
// Registered in SecureCloudApp.onAppear and executed by the OS scheduler.

final class SyncEngine: Sendable {

    static let taskIdentifier = "com.securecloud.vault.sync"

    private let syncRepository: SyncRepositoryProtocol
    private let vaultRepository: VaultRepositoryProtocol

    init(syncRepository: SyncRepositoryProtocol, vaultRepository: VaultRepositoryProtocol) {
        self.syncRepository = syncRepository
        self.vaultRepository = vaultRepository
    }

    // MARK: - Register

    /// Call once at app launch to register the background task handler.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task {
                await self.handleBackgroundSync(task: processingTask)
            }
        }
    }

    // MARK: - Schedule

    /// Schedule the next background sync (call after each foreground sync completes).
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15 min minimum
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handle

    private func handleBackgroundSync(task: BGProcessingTask) async {
        // Set expiration handler
        task.expirationHandler = {
            Task { await self.syncRepository.cancelSync() }
        }

        do {
            try await syncRepository.syncAll()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }

        scheduleBackgroundSync()
    }
}
