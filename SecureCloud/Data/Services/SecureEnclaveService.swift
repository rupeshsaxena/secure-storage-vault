import CryptoKit
import Foundation

// MARK: - VaultEncryptionKey
//
// Abstracts over a Secure Enclave P-256 key-agreement key (real device)
// or a software P-256 key (Simulator / SE unavailable).
// Private material is always opaque — only the public key can be read.

enum VaultEncryptionKey: @unchecked Sendable {
    case secureEnclave(SecureEnclave.P256.KeyAgreement.PrivateKey)
    case software(P256.KeyAgreement.PrivateKey)

    // MARK: Public Key

    var publicKey: P256.KeyAgreement.PublicKey {
        switch self {
        case .secureEnclave(let k): return k.publicKey
        case .software(let k):      return k.publicKey
        }
    }

    var publicKeyData: Data { publicKey.x963Representation }

    // MARK: Persistence
    //
    // SE keys: `.dataRepresentation` is an opaque blob tied to this device's SE.
    // Software keys: `.rawRepresentation` is the 32-byte scalar.

    var persistedData: Data {
        switch self {
        case .secureEnclave(let k): return k.dataRepresentation
        case .software(let k):      return k.rawRepresentation
        }
    }

    var isHardwareBacked: Bool {
        if case .secureEnclave = self { return true }
        return false
    }

    // MARK: ECDH

    func sharedSecretFromKeyAgreement(
        with publicKey: P256.KeyAgreement.PublicKey
    ) throws -> SharedSecret {
        switch self {
        case .secureEnclave(let k): return try k.sharedSecretFromKeyAgreement(with: publicKey)
        case .software(let k):      return try k.sharedSecretFromKeyAgreement(with: publicKey)
        }
    }
}

// MARK: - VaultSigningKey
//
// Abstracts over a Secure Enclave P-256 signing key (real device)
// or a software P-256 signing key (Simulator / SE unavailable).

enum VaultSigningKey: @unchecked Sendable {
    case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
    case software(P256.Signing.PrivateKey)

    // MARK: Public Key

    var publicKey: P256.Signing.PublicKey {
        switch self {
        case .secureEnclave(let k): return k.publicKey
        case .software(let k):      return k.publicKey
        }
    }

    var publicKeyData: Data { publicKey.x963Representation }

    // MARK: Persistence

    var persistedData: Data {
        switch self {
        case .secureEnclave(let k): return k.dataRepresentation
        case .software(let k):      return k.rawRepresentation
        }
    }

    var isHardwareBacked: Bool {
        if case .secureEnclave = self { return true }
        return false
    }

    // MARK: ECDSA Signing
    //
    // Both SE and software variants hash data with SHA-256 before signing.

    func signature(for data: Data) throws -> P256.Signing.ECDSASignature {
        switch self {
        case .secureEnclave(let k): return try k.signature(for: data)
        case .software(let k):      return try k.signature(for: data)
        }
    }
}

// MARK: - VaultKeyPair
//
// The full cryptographic identity of a device user — two private keys plus
// the owning userId.  Only ever held in memory; never serialised to disk.

struct VaultKeyPair: Sendable {
    let userId: UUID
    let encryptionKey: VaultEncryptionKey
    let signingKey: VaultSigningKey

    var encryptionPublicKeyData: Data { encryptionKey.publicKeyData }
    var signingPublicKeyData:    Data { signingKey.publicKeyData    }

    var isHardwareBacked: Bool { encryptionKey.isHardwareBacked }
}

// MARK: - SecureEnclaveServiceProtocol

protocol SecureEnclaveServiceProtocol: Sendable {
    /// Generate a new identity (two P-256 key pairs) and persist it.
    /// Throws `SEEncryptionError.identityNotFound` if keys cannot be stored.
    func generateIdentity(displayName: String) throws -> VaultIdentity

    /// Return the persisted `VaultIdentity` (public keys + metadata only).
    func loadIdentity() throws -> VaultIdentity

    /// Reconstruct the full `VaultKeyPair` from Keychain + SE.
    func loadKeyPair() throws -> VaultKeyPair

    /// Update the display name stored with the identity.
    func updateDisplayName(_ name: String) throws

    /// `true` iff an identity exists on this device.
    var hasIdentity: Bool { get }

    /// Permanently wipe both private keys and the identity metadata.
    /// ⚠️ Irreversible — any files encrypted for this identity become unreadable.
    func deleteIdentity() throws
}

// MARK: - SecureEnclaveService

final class SecureEnclaveService: SecureEnclaveServiceProtocol, Sendable {

    // ── Keychain account labels ────────────────────────────────────────────
    // Versioned so a future format change can coexist with old data.

    private enum Account {
        static let encPrivKey   = "sc-se-enc-privkey-v2"
        static let signPrivKey  = "sc-se-sign-privkey-v2"
        static let identityMeta = "sc-identity-meta-v2"
    }

    // ── Dependencies ───────────────────────────────────────────────────────

    private let keychain: KeychainServiceProtocol

    init(keychain: KeychainServiceProtocol = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - hasIdentity

    var hasIdentity: Bool {
        keychain.vaultKeyExists(account: Account.identityMeta)
    }

    // MARK: - generateIdentity

    func generateIdentity(displayName: String) throws -> VaultIdentity {
        let useSE = SecureEnclave.isAvailable

        // ── 1. Encryption key pair ─────────────────────────────────────────

        let encKey: VaultEncryptionKey
        if useSE {
            encKey = .secureEnclave(
                try SecureEnclave.P256.KeyAgreement.PrivateKey()
            )
        } else {
            print("⚠️ [SecureEnclaveService] SE unavailable — using software P-256 enc key (Simulator)")
            encKey = .software(P256.KeyAgreement.PrivateKey())
        }

        // ── 2. Signing key pair ────────────────────────────────────────────

        let signKey: VaultSigningKey
        if useSE {
            signKey = .secureEnclave(
                try SecureEnclave.P256.Signing.PrivateKey()
            )
        } else {
            signKey = .software(P256.Signing.PrivateKey())
        }

        // ── 3. Persist private keys to Keychain ───────────────────────────

        try keychain.saveVaultKey(encKey.persistedData,  account: Account.encPrivKey)
        try keychain.saveVaultKey(signKey.persistedData, account: Account.signPrivKey)

        // ── 4. Build + persist VaultIdentity (public data only) ───────────

        let identity = VaultIdentity(
            userId: UUID(),
            encryptionPublicKeyData: encKey.publicKeyData,
            signingPublicKeyData: signKey.publicKeyData,
            createdAt: Date(),
            displayName: displayName
        )
        try persistIdentity(identity)

        return identity
    }

    // MARK: - loadIdentity

    func loadIdentity() throws -> VaultIdentity {
        let raw = try keychain.loadVaultKey(account: Account.identityMeta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        do {
            return try decoder.decode(VaultIdentity.self, from: raw)
        } catch {
            throw SEEncryptionError.identityNotFound
        }
    }

    // MARK: - loadKeyPair

    func loadKeyPair() throws -> VaultKeyPair {
        let identity = try loadIdentity()

        let encPrivData  = try keychain.loadVaultKey(account: Account.encPrivKey)
        let signPrivData = try keychain.loadVaultKey(account: Account.signPrivKey)

        let encKey:  VaultEncryptionKey
        let signKey: VaultSigningKey

        if SecureEnclave.isAvailable {
            // Try restoring as SE keys; fall back to software if the stored
            // data was created on a Simulator (raw scalar, not SE blob).
            if let seEnc  = try? SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: encPrivData),
               let seSign = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: signPrivData) {
                encKey  = .secureEnclave(seEnc)
                signKey = .secureEnclave(seSign)
            } else {
                // Stored data is a software key scalar — handle gracefully
                encKey  = try .software(P256.KeyAgreement.PrivateKey(rawRepresentation: encPrivData))
                signKey = try .software(P256.Signing.PrivateKey(rawRepresentation: signPrivData))
                print("⚠️ [SecureEnclaveService] SE available but stored keys are software — identity may need migration")
            }
        } else {
            // Simulator: keys were stored as raw 32-byte scalars
            encKey  = try .software(P256.KeyAgreement.PrivateKey(rawRepresentation: encPrivData))
            signKey = try .software(P256.Signing.PrivateKey(rawRepresentation: signPrivData))
        }

        return VaultKeyPair(
            userId: identity.userId,
            encryptionKey: encKey,
            signingKey: signKey
        )
    }

    // MARK: - updateDisplayName

    func updateDisplayName(_ name: String) throws {
        var identity = try loadIdentity()
        // VaultIdentity has a `let displayName` — re-create with updated name
        let updated = VaultIdentity(
            userId: identity.userId,
            encryptionPublicKeyData: identity.encryptionPublicKeyData,
            signingPublicKeyData: identity.signingPublicKeyData,
            createdAt: identity.createdAt,
            displayName: name
        )
        try persistIdentity(updated)
        _ = identity   // suppress unused warning
    }

    // MARK: - deleteIdentity

    func deleteIdentity() throws {
        // Best-effort deletion: delete all, accumulate errors
        var errors: [Error] = []

        let accounts = [Account.encPrivKey, Account.signPrivKey, Account.identityMeta]
        for account in accounts {
            do { try keychain.deleteVaultKey(account: account) }
            catch KeychainError.notFound { /* already gone — fine */ }
            catch { errors.append(error) }
        }

        if let first = errors.first { throw first }
    }

    // MARK: - Private Helpers

    private func persistIdentity(_ identity: VaultIdentity) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        let data = try encoder.encode(identity)
        try keychain.saveVaultKey(data, account: Account.identityMeta)
    }
}

// MARK: - KeychainService AccountKey Extension

extension KeychainService.AccountKey {
    static let seEncPrivKey   = "sc-se-enc-privkey-v2"
    static let seSignPrivKey  = "sc-se-sign-privkey-v2"
    static let seIdentityMeta = "sc-identity-meta-v2"
}
