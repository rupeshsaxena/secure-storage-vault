import Foundation
import Security

// MARK: - KeychainServiceProtocol

protocol KeychainServiceProtocol: Sendable {
    func saveVaultKey(_ key: Data, account: String) throws
    func loadVaultKey(account: String) throws -> Data
    func deleteVaultKey(account: String) throws
    func vaultKeyExists(account: String) -> Bool
}

// MARK: - KeychainService

final class KeychainService: KeychainServiceProtocol, Sendable {
    private let service = "com.securecloud.vault"

    func saveVaultKey(_ key: Data, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecValueData:       key,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Remove any existing entry first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func loadVaultKey(account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }
        return data
    }

    func deleteVaultKey(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func vaultKeyExists(account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }
}

// MARK: - KeychainError

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let code):   return "Keychain save failed (OSStatus \(code))."
        case .deleteFailed(let code): return "Keychain delete failed (OSStatus \(code))."
        case .notFound:               return "Keychain item not found."
        }
    }
}

// MARK: - Well-known Keychain account keys

extension KeychainService {
    enum AccountKey {
        static let masterVaultKey = "master-vault-key"
        static let biometricSeed  = "biometric-seed"
    }
}
