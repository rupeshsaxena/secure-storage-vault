import Foundation
import SwiftUI

// MARK: - DependencyContainer

final class DependencyContainer: Sendable {
    static let shared = DependencyContainer()

    // MARK: - Services

    lazy var encryptionService: EncryptionServiceProtocol = EncryptionService()
    lazy var keychainService: KeychainServiceProtocol = KeychainService()

    // MARK: - Repositories

    lazy var vaultRepository: VaultRepositoryProtocol = VaultRepository(
        encryption: encryptionService,
        keychain: keychainService
    )

    lazy var syncRepository: SyncRepositoryProtocol = SyncRepository()

    lazy var mediaRepository: MediaRepositoryProtocol = MediaRepository(
        encryption: encryptionService,
        vaultRepository: vaultRepository
    )

    // MARK: - Use Cases

    lazy var vaultUseCase: VaultUseCaseProtocol = VaultUseCase(
        repository: vaultRepository,
        encryption: encryptionService
    )

    lazy var syncUseCase: SyncUseCaseProtocol = SyncUseCase(
        repository: syncRepository
    )

    lazy var encryptionUseCase: EncryptionUseCaseProtocol = EncryptionUseCase(
        service: encryptionService
    )

    lazy var mediaUseCase: MediaUseCaseProtocol = MediaUseCase(
        repository: mediaRepository
    )

    lazy var shareUseCase: ShareUseCaseProtocol = ShareUseCase(
        vault: vaultRepository,
        encryption: encryptionService
    )

    private init() {}
}

// MARK: - SwiftUI Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
