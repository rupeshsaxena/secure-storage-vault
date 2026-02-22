import Foundation

// MARK: - EncryptionUseCaseProtocol

protocol EncryptionUseCaseProtocol: Sendable {
    func encrypt(data: Data, password: String) throws -> Data
    func decrypt(data: Data, password: String) throws -> Data
    func validatePassword(_ password: String) -> Bool
}

// MARK: - EncryptionUseCase

final class EncryptionUseCase: EncryptionUseCaseProtocol, Sendable {
    private let service: EncryptionServiceProtocol

    init(service: EncryptionServiceProtocol) {
        self.service = service
    }

    func encrypt(data: Data, password: String) throws -> Data {
        try service.encrypt(data: data, password: password)
    }

    func decrypt(data: Data, password: String) throws -> Data {
        try service.decrypt(data: data, password: password)
    }

    func validatePassword(_ password: String) -> Bool {
        password.count >= 8
    }
}
