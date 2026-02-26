import CryptoKit
import Foundation

// MARK: - VaultIdentity
//
// Represents a user's cryptographic identity: two P-256 public keys
// (one for ECDH key-agreement, one for ECDSA signing) plus a derived
// fingerprint used for out-of-band MITM verification.
//
// The matching *private* keys live exclusively inside the Secure Enclave
// and are managed by SecureEnclaveService.

struct VaultIdentity: Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    let userId: UUID

    /// P-256 public key for ECDH (x9.63 uncompressed, 65 bytes).
    let encryptionPublicKeyData: Data

    /// P-256 public key for ECDSA signing (x9.63 uncompressed, 65 bytes).
    let signingPublicKeyData: Data

    let createdAt: Date
    let displayName: String

    // MARK: - Derived (transient)

    /// SHA-256 of both public keys — used for fingerprint comparison.
    var fingerprintData: Data {
        var combined = encryptionPublicKeyData
        combined.append(signingPublicKeyData)
        return Data(SHA256.hash(data: combined))
    }

    /// Hex fingerprint grouped in 8 blocks of 4 — used for visual/verbal OOB verification.
    /// e.g. "A1B2 C3D4 E5F6 7890 AABB CCDD EEFF 0011"
    var fingerprintString: String {
        let hex = fingerprintData.map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { i -> String in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: min(4, hex.count - i))
            return String(hex[start..<end])
        }.joined(separator: " ")
    }

    /// Short 4-block safety code for quick cross-device comparison during a share operation.
    /// e.g. "A1B2-C3D4-E5F6-7890"
    var shortFingerprint: String {
        let hex = fingerprintData.prefix(8).map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { i -> String in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: min(4, hex.count - i))
            return String(hex[start..<end])
        }.joined(separator: "-")
    }

    // MARK: - Public Key Accessors

    var encryptionPublicKey: P256.KeyAgreement.PublicKey {
        get throws { try P256.KeyAgreement.PublicKey(x963Representation: encryptionPublicKeyData) }
    }

    var signingPublicKey: P256.Signing.PublicKey {
        get throws { try P256.Signing.PublicKey(x963Representation: signingPublicKeyData) }
    }

    // MARK: - QR / Shareable Payload

    /// JSON blob suitable for encoding into a QR code for OOB key exchange.
    var qrPayload: Data {
        get throws {
            let payload = QRPayload(
                userId: userId.uuidString,
                encPK: encryptionPublicKeyData.base64EncodedString(),
                signPK: signingPublicKeyData.base64EncodedString(),
                displayName: displayName
            )
            return try JSONEncoder().encode(payload)
        }
    }

    static func fromQRPayload(_ data: Data) throws -> VaultIdentity {
        let payload = try JSONDecoder().decode(QRPayload.self, from: data)
        guard let userId = UUID(uuidString: payload.userId),
              let encKeyData = Data(base64Encoded: payload.encPK),
              let signKeyData = Data(base64Encoded: payload.signPK)
        else { throw VaultIdentityError.invalidQRPayload }

        // Validate the keys are valid P-256 points before storing
        _ = try P256.KeyAgreement.PublicKey(x963Representation: encKeyData)
        _ = try P256.Signing.PublicKey(x963Representation: signKeyData)

        return VaultIdentity(
            userId: userId,
            encryptionPublicKeyData: encKeyData,
            signingPublicKeyData: signKeyData,
            createdAt: Date(),
            displayName: payload.displayName
        )
    }

    private struct QRPayload: Codable {
        let userId: String
        let encPK: String
        let signPK: String
        let displayName: String
    }
}

// MARK: - VaultIdentityError

enum VaultIdentityError: LocalizedError {
    case invalidQRPayload
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .invalidQRPayload: return "The QR code does not contain a valid SecureCloud identity."
        case .invalidPublicKey: return "The public key data is not a valid P-256 key."
        }
    }
}
