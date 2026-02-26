import Foundation
import SwiftUI

// MARK: - DependencyContainer

final class DependencyContainer: @unchecked Sendable {
    static let shared = DependencyContainer()

    // MARK: - Legacy Services (SCV1 password-based)

    lazy var encryptionService: EncryptionServiceProtocol = EncryptionService()
    lazy var keychainService: KeychainServiceProtocol = KeychainService()

    // MARK: - Secure Enclave Services (SCV2)

    lazy var seService: SecureEnclaveServiceProtocol = SecureEnclaveService(
        keychain: keychainService
    )

    lazy var seEncryptionService: SecureEnclaveEncryptionServiceProtocol =
        SecureEnclaveEncryptionService()

    lazy var keyVerificationService: KeyVerificationServiceProtocol =
        KeyVerificationService()

    // MARK: - Trusted Contacts Persistence

    lazy var trustedContactsStore = TrustedContactsStore()

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
