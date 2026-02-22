import Foundation

// MARK: - SyncRepository
//
// MVP stub — wire in your real p2p or cloud sync backend here.

final class SyncRepository: SyncRepositoryProtocol, Sendable {

    private let devicesStore = DevicesStore()

    func fetchLinkedDevices() async throws -> [SyncDevice] {
        await devicesStore.all()
    }

    func addDevice(_ device: SyncDevice, pairingCode: String) async throws {
        // Validate pairing code against backend; stub always succeeds
        await devicesStore.insert(device)
    }

    func removeDevice(id: UUID) async throws {
        await devicesStore.remove(id: id)
    }

    func fetchThisDevice() async throws -> SyncDevice {
        guard let this = await devicesStore.thisDevice() else {
            throw SyncError.noThisDevice
        }
        return this
    }

    func syncAll() async throws {
        // Stub: simulate a 2-second sync
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }

    func syncFile(id: UUID) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func cancelSync() async {
        // Cancel active tasks — implementation with structured concurrency task groups in v2
    }

    func fetchSyncStatus() async throws -> (synced: Int, pending: Int, total: Int) {
        (synced: 48, pending: 3, total: 51)
    }

    func observeSyncProgress() -> AsyncStream<Double> {
        AsyncStream { continuation in
            Task {
                for i in stride(from: 0.0, through: 1.0, by: 0.1) {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - DevicesStore (actor-isolated in-memory storage)

private actor DevicesStore {
    private var devices: [UUID: SyncDevice] = [:]

    func all() -> [SyncDevice] {
        Array(devices.values).sorted { $0.name < $1.name }
    }

    func thisDevice() -> SyncDevice? {
        devices.values.first(where: { $0.isThisDevice })
    }

    func insert(_ device: SyncDevice) {
        devices[device.id] = device
    }

    func remove(id: UUID) {
        devices.removeValue(forKey: id)
    }
}

// MARK: - SyncError

enum SyncError: LocalizedError {
    case noThisDevice
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .noThisDevice:          return "This device is not registered."
        case .syncFailed(let msg):   return "Sync failed: \(msg)"
        }
    }
}
