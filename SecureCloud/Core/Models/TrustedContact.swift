import Foundation

// MARK: - TrustedContact
//
// A contact whose public keys have been verified out-of-band (via QR scan or
// verbal safety-number comparison). Stored locally on device.
//
// SECURITY NOTE: Only add contacts via a verified OOB channel.
// Never blindly import a public key from an unverified network source.

struct TrustedContact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID                        // local contact ID (not the remote userId)
    let remoteUserId: UUID              // the contact's VaultIdentity.userId
    var displayName: String

    /// P-256 x9.63 public key for ECDH encryption.
    let encryptionPublicKeyData: Data

    /// P-256 x9.63 public key for ECDSA signature verification.
    let signingPublicKeyData: Data

    let addedAt: Date
    var verifiedAt: Date?
    var verificationMethod: VerificationMethod

    // MARK: - Verification Method

    enum VerificationMethod: String, Codable, Sendable {
        case qrCodeScan    = "qr_scan"      // Scanned QR code directly from their device
        case safetyNumber  = "safety_num"   // Verbally compared fingerprint groups
        case unverified    = "unverified"   // Imported from a server/network (trust on first use)

        var icon: String {  // SF Symbol
            switch self {
            case .qrCodeScan:   return "qrcode.viewfinder"
            case .safetyNumber: return "checkmark.shield.fill"
            case .unverified:   return "exclamationmark.triangle"
            }
        }

        var label: String {
            switch self {
            case .qrCodeScan:   return "QR Code Verified"
            case .safetyNumber: return "Safety Number Verified"
            case .unverified:   return "Not Verified"
            }
        }

        var isVerified: Bool {
            self == .qrCodeScan || self == .safetyNumber
        }
    }

    // MARK: - Convenience

    /// SHA-256 fingerprint of both public keys for display.
    var fingerprint: String {
        let identity = VaultIdentity(
            userId: remoteUserId,
            encryptionPublicKeyData: encryptionPublicKeyData,
            signingPublicKeyData: signingPublicKeyData,
            createdAt: addedAt,
            displayName: displayName
        )
        return identity.fingerprintString
    }

    var shortFingerprint: String {
        let identity = VaultIdentity(
            userId: remoteUserId,
            encryptionPublicKeyData: encryptionPublicKeyData,
            signingPublicKeyData: signingPublicKeyData,
            createdAt: addedAt,
            displayName: displayName
        )
        return identity.shortFingerprint
    }

    var asVaultIdentity: VaultIdentity {
        VaultIdentity(
            userId: remoteUserId,
            encryptionPublicKeyData: encryptionPublicKeyData,
            signingPublicKeyData: signingPublicKeyData,
            createdAt: addedAt,
            displayName: displayName
        )
    }
}
