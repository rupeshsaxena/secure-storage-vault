import Foundation

// MARK: - SyncRepositoryProtocol

protocol SyncRepositoryProtocol: Sendable {
    // MARK: Devices
    func fetchLinkedDevices() async throws -> [SyncDevice]
    func addDevice(_ device: SyncDevice, pairingCode: String) async throws
    func removeDevice(id: UUID) async throws
    func fetchThisDevice() async throws -> SyncDevice

    // MARK: Sync operations
    func syncAll() async throws
    func syncFile(id: UUID) async throws
    func cancelSync() async

    // MARK: Sync status
    func fetchSyncStatus() async throws -> (synced: Int, pending: Int, total: Int)
    func observeSyncProgress() -> AsyncStream<Double>
}
