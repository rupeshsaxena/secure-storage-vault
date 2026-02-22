import Foundation

// MARK: - SyncViewModel

@MainActor
final class SyncViewModel: ObservableObject {

    @Published var devices: [SyncDevice] = []
    @Published var syncedCount: Int = 0
    @Published var pendingCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0
    @Published var showAddDevice: Bool = false
    @Published var thisDeviceId: UUID?
    @Published var errorMessage: String?

    private let useCase: SyncUseCaseProtocol

    init(useCase: SyncUseCaseProtocol = DependencyContainer.shared.syncUseCase) {
        self.useCase = useCase
    }

    // MARK: - Load

    func load() async {
        do {
            devices = try await useCase.loadDevices()
            let counts = try await useCase.loadSyncCounts()
            syncedCount = counts.synced
            pendingCount = counts.pending
            totalCount = counts.total
            thisDeviceId = devices.first(where: { $0.isThisDevice })?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sync

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncProgress = 0

        // Observe progress stream
        let stream = useCase.observeSyncProgress()
        for await progress in stream {
            syncProgress = progress
        }

        do {
            try await useCase.syncAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncing = false
        syncProgress = 1.0
        await load()
    }

    // MARK: - Devices

    func removeDevice(id: UUID) async {
        do {
            try await useCase.removeDevice(id: id)
            devices.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
