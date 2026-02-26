import XCTest
@testable import SecureCloud

// MARK: - SyncEngineTests

final class SyncEngineTests: XCTestCase {

    private var syncRepository: MockSyncRepository!
    private var vaultRepository: MockVaultRepository!
    private var sut: SyncUseCase!

    override func setUp() async throws {
        try await super.setUp()
        syncRepository = MockSyncRepository()
        vaultRepository = MockVaultRepository()
        sut = SyncUseCase(repository: syncRepository)
    }

    // MARK: - Load Devices

    func test_loadDevices_returnsAllDevices() async throws {
        syncRepository.stubbedDevices = SyncDevice.samples

        let devices = try await sut.loadDevices()

        XCTAssertEqual(devices.count, SyncDevice.samples.count)
    }

    // MARK: - Sync Counts

    func test_loadSyncCounts_returnsExpectedCounts() async throws {
        syncRepository.stubbedCounts = (synced: 10, pending: 2, total: 12)

        let counts = try await sut.loadSyncCounts()

        XCTAssertEqual(counts.synced, 10)
        XCTAssertEqual(counts.pending, 2)
        XCTAssertEqual(counts.total, 12)
    }

    // MARK: - Sync All

    func test_syncAll_callsRepositorySyncAll() async throws {
        try await sut.syncAll()
        XCTAssertTrue(syncRepository.syncAllCalled)
    }

    // MARK: - Remove Device

    func test_removeDevice_delegatesToRepository() async throws {
        let device = SyncDevice.samples[0]
        syncRepository.stubbedDevices = [device]

        try await sut.removeDevice(id: device.id)

        XCTAssertEqual(syncRepository.removedDeviceId, device.id)
    }
}

// MARK: - MockSyncRepository

final class MockSyncRepository: SyncRepositoryProtocol, Sendable {
    var stubbedDevices: [SyncDevice] = []
    var stubbedCounts: (synced: Int, pending: Int, total: Int) = (0, 0, 0)
    var syncAllCalled = false
    var removedDeviceId: UUID?

    func fetchLinkedDevices() async throws -> [SyncDevice] { stubbedDevices }
    func addDevice(_ device: SyncDevice, pairingCode: String) async throws {}
    func removeDevice(id: UUID) async throws { removedDeviceId = id }
    func fetchThisDevice() async throws -> SyncDevice {
        stubbedDevices.first(where: { $0.isThisDevice }) ?? SyncDevice.samples[0]
    }
    func syncAll() async throws { syncAllCalled = true }
    func syncFile(id: UUID) async throws {}
    func cancelSync() async {}
    func fetchSyncStatus() async throws -> (synced: Int, pending: Int, total: Int) { stubbedCounts }
    func observeSyncProgress() -> AsyncStream<Double> {
        AsyncStream { continuation in continuation.finish() }
    }
}

// MARK: - MockVaultRepository

final class MockVaultRepository: VaultRepositoryProtocol, Sendable {
    func fetchFiles(in folderId: UUID?) async throws -> [VaultFile] { [] }
    func fetchFile(id: UUID) async throws -> VaultFile { throw VaultStoreError.notFound }
    func addFile(_ file: VaultFile, encryptedData: Data) async throws {}
    func updateFile(_ file: VaultFile) async throws {}
    func deleteFile(id: UUID) async throws {}
    func moveFile(id: UUID, toFolder folderId: UUID?) async throws {}
    func search(query: String) async throws -> [VaultFile] { [] }
    func fetchFolders(in parentId: UUID?) async throws -> [VaultFolder] { [] }
    func createFolder(_ folder: VaultFolder) async throws {}
    func updateFolder(_ folder: VaultFolder) async throws {}
    func deleteFolder(id: UUID) async throws {}
    func loadEncryptedData(for fileId: UUID) async throws -> Data { Data() }
    func saveEncryptedData(_ data: Data, for fileId: UUID) async throws {}
}
