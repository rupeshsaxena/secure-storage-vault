import CryptoKit
import Foundation

// MARK: - KeyVerificationServiceProtocol

protocol KeyVerificationServiceProtocol: Sendable {

    // ── QR Code Exchange ───────────────────────────────────────────────────

    /// Encode a `VaultIdentity` into a JSON blob suitable for a QR code.
    func qrCodeData(for identity: VaultIdentity) throws -> Data

    /// Decode a QR blob (scanned from another device) into a `VaultIdentity`.
    /// Throws `VaultIdentityError.invalidQRPayload` on malformed input.
    func identity(fromQRData data: Data) throws -> VaultIdentity

    // ── Contact Creation ───────────────────────────────────────────────────

    /// Build a `TrustedContact` from a scanned QR identity.
    func contact(
        fromQRIdentity identity: VaultIdentity,
        displayNameOverride: String?
    ) -> TrustedContact

    /// Build an `unverified` contact from a network-sourced identity
    /// (e.g. server directory).  Must be upgraded to QR/safety-number
    /// before files can be shared.
    func unverifiedContact(from identity: VaultIdentity) -> TrustedContact

    // ── Safety Code ────────────────────────────────────────────────────────

    /// Compute the 8-character safety code shown on both devices during a
    /// share operation.
    ///
    /// = uppercase hex of SHA-256(ephemeralPublicKeyData ‖ recipientPublicKeyData)
    ///   truncated to 4 bytes, grouped as "A1B2 C3D4".
    func safetyCode(
        ephemeralPublicKeyData: Data,
        recipientPublicKeyData: Data
    ) -> String

    // ── Grant Verification ─────────────────────────────────────────────────

    /// Verify that a `FEKBlock`'s ECDSA signature is valid.
    /// - Throws `SEEncryptionError.signatureVerificationFailed` on failure.
    func verifyGrant(block: FEKBlock, in header: EncryptedFileHeaderV2) throws

    // ── Fingerprints ───────────────────────────────────────────────────────

    /// 64-char hex fingerprint grouped as "A1B2 C3D4 …" (8 groups of 4).
    func fingerprintString(for identity: VaultIdentity) -> String

    /// Short 4-group safety number  "A1B2-C3D4-E5F6-7890".
    func shortFingerprint(for identity: VaultIdentity) -> String

    /// Cross-device safety number: XOR-fold of both parties' fingerprints
    /// into 4 bytes, shown on BOTH devices before exchanging a file.
    func crossFingerprint(
        myIdentity:       VaultIdentity,
        contactIdentity:  VaultIdentity
    ) -> String
}

// MARK: - KeyVerificationService

final class KeyVerificationService: KeyVerificationServiceProtocol, Sendable {

    // MARK: - QR Code Exchange

    func qrCodeData(for identity: VaultIdentity) throws -> Data {
        return try identity.qrPayload
    }

    func identity(fromQRData data: Data) throws -> VaultIdentity {
        return try VaultIdentity.fromQRPayload(data)
    }

    // MARK: - Contact Creation

    func contact(
        fromQRIdentity identity: VaultIdentity,
        displayNameOverride: String? = nil
    ) -> TrustedContact {
        return TrustedContact(
            id:                        UUID(),
            remoteUserId:              identity.userId,
            displayName:               displayNameOverride ?? identity.displayName,
            encryptionPublicKeyData:   identity.encryptionPublicKeyData,
            signingPublicKeyData:      identity.signingPublicKeyData,
            addedAt:                   Date(),
            verifiedAt:                Date(),
            verificationMethod:        .qrCodeScan
        )
    }

    func unverifiedContact(from identity: VaultIdentity) -> TrustedContact {
        return TrustedContact(
            id:                        UUID(),
            remoteUserId:              identity.userId,
            displayName:               identity.displayName,
            encryptionPublicKeyData:   identity.encryptionPublicKeyData,
            signingPublicKeyData:      identity.signingPublicKeyData,
            addedAt:                   Date(),
            verifiedAt:                nil,
            verificationMethod:        .unverified
        )
    }

    // MARK: - Safety Code

    func safetyCode(
        ephemeralPublicKeyData: Data,
        recipientPublicKeyData: Data
    ) -> String {
        var combined = ephemeralPublicKeyData
        combined.append(recipientPublicKeyData)
        let digest = SHA256.hash(data: combined)
        return formatHex(Data(digest.prefix(4)), separator: " ")
    }

    // MARK: - Grant Verification

    func verifyGrant(block: FEKBlock, in header: EncryptedFileHeaderV2) throws {
        let ownerSigningPubKey: P256.Signing.PublicKey
        do {
            ownerSigningPubKey = try P256.Signing.PublicKey(
                x963Representation: header.ownerSigningPublicKeyData
            )
        } catch {
            throw SEEncryptionError.signatureVerificationFailed
        }

        let payload   = block.grantPayload(fileId: header.fileId)
        let digest    = SHA256.hash(data: payload)

        let signature: P256.Signing.ECDSASignature
        do {
            signature = try P256.Signing.ECDSASignature(derRepresentation: block.signatureData)
        } catch {
            throw SEEncryptionError.signatureVerificationFailed
        }

        guard ownerSigningPubKey.isValidSignature(signature, for: Data(digest)) else {
            throw SEEncryptionError.signatureVerificationFailed
        }
    }

    // MARK: - Fingerprints

    func fingerprintString(for identity: VaultIdentity) -> String {
        let hex = identity.fingerprintData
            .map { String(format: "%02X", $0) }
            .joined()
        return groupHex(hex, groupSize: 4, separator: " ")
    }

    func shortFingerprint(for identity: VaultIdentity) -> String {
        let hex = identity.fingerprintData.prefix(8)
            .map { String(format: "%02X", $0) }
            .joined()
        return groupHex(hex, groupSize: 4, separator: "-")
    }

    func crossFingerprint(
        myIdentity:      VaultIdentity,
        contactIdentity: VaultIdentity
    ) -> String {
        // XOR-fold both 32-byte fingerprints → 4 bytes
        let mine    = Array(myIdentity.fingerprintData)
        let theirs  = Array(contactIdentity.fingerprintData)
        var folded  = [UInt8](repeating: 0, count: 4)
        for i in 0..<4 {
            // XOR 8 bytes at stride i*4 into one byte (fold 32→4)
            var acc: UInt8 = 0
            for j in 0..<8 {
                let idx = (i * 8 + j) % 32
                acc ^= mine[idx] ^ theirs[idx]
            }
            folded[i] = acc
        }
        return formatHex(Data(folded), separator: " ")
    }

    // MARK: - Private Helpers

    private func groupHex(_ hex: String, groupSize: Int, separator: String) -> String {
        stride(from: 0, to: hex.count, by: groupSize).map { i -> String in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end   = hex.index(start, offsetBy: min(groupSize, hex.count - i))
            return String(hex[start..<end])
        }.joined(separator: separator)
    }

    private func formatHex(_ data: Data, separator: String) -> String {
        let hex = data.map { String(format: "%02X", $0) }.joined()
        return groupHex(hex, groupSize: 4, separator: separator)
    }
}
