import Foundation

// MARK: - SyncUseCaseProtocol

protocol SyncUseCaseProtocol: Sendable {
    func loadDevices() async throws -> [SyncDevice]
    func addDevice(pairingCode: String, name: String) async throws -> SyncDevice
    func removeDevice(id: UUID) async throws
    func syncAll() async throws
    func loadSyncCounts() async throws -> (synced: Int, pending: Int, total: Int)
    func observeSyncProgress() -> AsyncStream<Double>
}

// MARK: - SyncUseCase

final class SyncUseCase: SyncUseCaseProtocol, Sendable {
    private let repository: SyncRepositoryProtocol

    init(repository: SyncRepositoryProtocol) {
        self.repository = repository
    }

    func loadDevices() async throws -> [SyncDevice] {
        try await repository.fetchLinkedDevices()
    }

    func addDevice(pairingCode: String, name: String) async throws -> SyncDevice {
        let thisDevice = try await repository.fetchThisDevice()
        let newDevice = SyncDevice(
            name: name,
            model: "Unknown",
            platform: .iOS
        )
        try await repository.addDevice(newDevice, pairingCode: pairingCode)
        return newDevice
    }

    func removeDevice(id: UUID) async throws {
        try await repository.removeDevice(id: id)
    }

    func syncAll() async throws {
        try await repository.syncAll()
    }

    func loadSyncCounts() async throws -> (synced: Int, pending: Int, total: Int) {
        try await repository.fetchSyncStatus()
    }

    func observeSyncProgress() -> AsyncStream<Double> {
        repository.observeSyncProgress()
    }
}
