import CryptoKit
import Foundation

// MARK: - SecureEnclaveEncryptionServiceProtocol

protocol SecureEnclaveEncryptionServiceProtocol: Sendable {

    /// Encrypt `data` for the owner.  Returns the full SCV2 binary file blob.
    func encryptFile(
        data:        Data,
        keyPair:     VaultKeyPair,
        filename:    String,
        contentType: String
    ) throws -> Data

    /// Decrypt an SCV2 file.  Works for both the owner block and any
    /// recipient block whose public key matches `keyPair`.
    func decryptFile(
        encryptedData: Data,
        keyPair:       VaultKeyPair
    ) throws -> (plaintext: Data, header: EncryptedFileHeaderV2)

    /// Add a recipient block to an already-encrypted SCV2 file.
    /// The file is NOT re-encrypted — only the FEK is re-wrapped under
    /// the recipient's public key.
    ///
    /// - Parameters:
    ///   - encryptedData:    Existing SCV2 file blob.
    ///   - recipientContact: Verified `TrustedContact` to share with.
    ///   - ownerKeyPair:     Owner's full key pair (needed to decrypt FEK & sign grant).
    /// - Returns: Updated SCV2 file blob with the new `FEKBlock` appended.
    /// - Throws: `SEEncryptionError.contactNotVerified` if the contact has not been
    ///           verified via QR code or safety number.
    func addRecipient(
        to encryptedData:    Data,
        recipientContact:    TrustedContact,
        ownerKeyPair:        VaultKeyPair
    ) throws -> (updatedFile: Data, safetyCode: String)

    /// Remove a recipient's FEKBlock from an SCV2 file (revoke access).
    /// The FEK is NOT rotated — all remaining FEKBlocks keep the same FEK.
    /// For full revocation, re-encrypt the file with a new FEK.
    func removeRecipient(
        from encryptedData:        Data,
        recipientPublicKeyData:    Data,
        ownerKeyPair:              VaultKeyPair
    ) throws -> Data
}

// MARK: - SecureEnclaveEncryptionService

final class SecureEnclaveEncryptionService: SecureEnclaveEncryptionServiceProtocol, Sendable {

    // ── Constants ──────────────────────────────────────────────────────────

    /// Maximum age (seconds) for a recipient block before it is considered stale.
    /// Blocks older than this are rejected on decryption as potential replay attacks.
    private static let maxGrantAge: TimeInterval = 60 * 60 * 24 * 365  // 1 year

    // MARK: - encryptFile

    func encryptFile(
        data:        Data,
        keyPair:     VaultKeyPair,
        filename:    String,
        contentType: String
    ) throws -> Data {
        let fileId = UUID()

        // ── 1. Generate a random 32-byte File Encryption Key (FEK) ─────────

        let fek = SymmetricKey(size: .bits256)
        let fekData = fek.withUnsafeBytes { Data($0) }

        // ── 2. Encrypt file body with FEK ──────────────────────────────────

        let sealedBody = try AES.GCM.seal(data, using: fek).combined!

        // ── 3. Build owner FEKBlock ────────────────────────────────────────

        let ownerBlock = try buildFEKBlock(
            blockType:         .owner,
            fekData:           fekData,
            holderPublicKey:   keyPair.encryptionKey.publicKey,
            holderPublicKeyData: keyPair.encryptionPublicKeyData,
            signingKey:        keyPair.signingKey,
            fileId:            fileId,
            timestamp:         0   // owner blocks use 0
        )

        // ── 4. Assemble header ─────────────────────────────────────────────

        let header = EncryptedFileHeaderV2(
            fileId:                       fileId,
            filename:                     filename,
            contentType:                  contentType,
            originalSize:                 UInt64(data.count),
            ownerEncryptionPublicKeyData: keyPair.encryptionPublicKeyData,
            ownerSigningPublicKeyData:    keyPair.signingPublicKeyData,
            fekBlocks:                    [ownerBlock]
        )

        // ── 5. Build binary file ───────────────────────────────────────────

        return try header.buildFile(sealedBody: sealedBody)
    }

    // MARK: - decryptFile

    func decryptFile(
        encryptedData: Data,
        keyPair:       VaultKeyPair
    ) throws -> (plaintext: Data, header: EncryptedFileHeaderV2) {
        let (header, sealedBody) = try EncryptedFileHeaderV2.parse(fileData: encryptedData)

        // ── 1. Find the FEKBlock for this key pair ─────────────────────────

        let myPubKeyData = keyPair.encryptionPublicKeyData
        let isOwner = (myPubKeyData == header.ownerEncryptionPublicKeyData)

        let block: FEKBlock
        if isOwner {
            block = try header.ownerBlock()
        } else {
            block = try header.recipientBlock(for: myPubKeyData)
        }

        // ── 2. Verify the grant signature ──────────────────────────────────
        //
        // The signature covers the grantPayload binding fileId + holder key
        // + ephemeral key + salt + wrappedFEK + timestamp.
        // This prevents MITM substitution of the recipient's public key.

        try verifyGrantSignature(block: block, header: header)

        // ── 3. Replay-attack guard (recipient blocks only) ─────────────────

        if block.blockType == .recipient {
            try checkTimestamp(block.timestamp)
        }

        // ── 4. ECDH → HKDF → unwrap FEK ──────────────────────────────────

        let fekData = try unwrapFEK(block: block, myEncKey: keyPair.encryptionKey)

        // ── 5. Decrypt file body ───────────────────────────────────────────

        let fek = SymmetricKey(data: fekData)
        let sealedBox = try AES.GCM.SealedBox(combined: sealedBody)
        let plaintext = try AES.GCM.open(sealedBox, using: fek)

        return (plaintext, header)
    }

    // MARK: - addRecipient

    func addRecipient(
        to encryptedData:    Data,
        recipientContact:    TrustedContact,
        ownerKeyPair:        VaultKeyPair
    ) throws -> (updatedFile: Data, safetyCode: String) {
        // ── Safety: only add verified contacts ────────────────────────────

        guard recipientContact.verificationMethod.isVerified else {
            throw SEEncryptionError.contactNotVerified
        }

        // ── 1. Parse file + decrypt FEK ────────────────────────────────────

        var (header, sealedBody) = try EncryptedFileHeaderV2.parse(fileData: encryptedData)

        let ownerBlock = try header.ownerBlock()
        try verifyGrantSignature(block: ownerBlock, header: header)

        let fekData = try unwrapFEK(block: ownerBlock, myEncKey: ownerKeyPair.encryptionKey)

        // ── 2. Validate recipient's public key ─────────────────────────────

        let recipientEncPubKey = try P256.KeyAgreement.PublicKey(
            x963Representation: recipientContact.encryptionPublicKeyData
        )

        // ── 3. Build recipient FEKBlock ────────────────────────────────────

        let timestamp = UInt64(Date().timeIntervalSince1970)

        let recipientBlock = try buildFEKBlock(
            blockType:            .recipient,
            fekData:              fekData,
            holderPublicKey:      recipientEncPubKey,
            holderPublicKeyData:  recipientContact.encryptionPublicKeyData,
            signingKey:           ownerKeyPair.signingKey,
            fileId:               header.fileId,
            timestamp:            timestamp
        )

        // ── 4. Compute safety code (shown to both parties for OOB check) ───

        let safetyCode = computeSafetyCode(
            ephemeralPublicKeyData: recipientBlock.ephemeralPublicKeyData,
            recipientPublicKeyData: recipientContact.encryptionPublicKeyData
        )

        // ── 5. Append block + rebuild file ─────────────────────────────────

        header.fekBlocks.append(recipientBlock)
        let updatedFile = try header.buildFile(sealedBody: sealedBody)

        return (updatedFile, safetyCode)
    }

    // MARK: - removeRecipient

    func removeRecipient(
        from encryptedData:     Data,
        recipientPublicKeyData: Data,
        ownerKeyPair:           VaultKeyPair
    ) throws -> Data {
        var (header, sealedBody) = try EncryptedFileHeaderV2.parse(fileData: encryptedData)

        // Verify owner identity matches the file
        guard header.ownerEncryptionPublicKeyData == ownerKeyPair.encryptionPublicKeyData else {
            throw SEEncryptionError.decryptionFailed
        }

        header.fekBlocks.removeAll {
            $0.blockType == .recipient && $0.holderPublicKeyData == recipientPublicKeyData
        }

        return try header.buildFile(sealedBody: sealedBody)
    }

    // MARK: - Private: Build FEKBlock

    private func buildFEKBlock(
        blockType:           FEKBlock.BlockType,
        fekData:             Data,
        holderPublicKey:     P256.KeyAgreement.PublicKey,
        holderPublicKeyData: Data,
        signingKey:          VaultSigningKey,
        fileId:              UUID,
        timestamp:           UInt64
    ) throws -> FEKBlock {
        // ── a. Ephemeral software P-256 key (never stored in SE) ───────────

        let ephPrivKey = P256.KeyAgreement.PrivateKey()
        let ephPubKeyData = ephPrivKey.publicKey.x963Representation

        // ── b. 16-byte HKDF salt ───────────────────────────────────────────

        var saltBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, 16, &saltBytes)
        guard status == errSecSuccess else {
            throw SEEncryptionError.keyGenerationFailed("SecRandomCopyBytes failed: \(status)")
        }
        let salt = Data(saltBytes)

        // ── c. ECDH shared secret ──────────────────────────────────────────

        let sharedSecret = try ephPrivKey.sharedSecretFromKeyAgreement(with: holderPublicKey)

        // ── d. HKDF-SHA256 → 32-byte wrapping key ─────────────────────────

        let context = blockType == .owner
            ? FEKBlock.ownerContext
            : FEKBlock.recipientContext

        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using:        SHA256.self,
            salt:         salt,
            sharedInfo:   Data(context.utf8),
            outputByteCount: 32
        )

        // ── e. AES-256-GCM wrap the FEK ───────────────────────────────────

        let wrappedFEKBox    = try AES.GCM.seal(fekData, using: wrappingKey)
        let wrappedFEKCombined = wrappedFEKBox.combined!   // nonce(12)+ciphertext(32)+tag(16)

        // ── f. Sign the grant payload ──────────────────────────────────────

        let candidateBlock = FEKBlock(
            blockType:              blockType,
            holderPublicKeyData:    holderPublicKeyData,
            ephemeralPublicKeyData: ephPubKeyData,
            salt:                   salt,
            wrappedFEKCombined:     wrappedFEKCombined,
            timestamp:              timestamp,
            signatureData:          Data()   // temporary; replaced below
        )

        let payload   = candidateBlock.grantPayload(fileId: fileId)
        let digest    = SHA256.hash(data: payload)
        let signature = try signingKey.signature(for: Data(digest))

        // ── g. Return fully-formed block ───────────────────────────────────

        return FEKBlock(
            blockType:              blockType,
            holderPublicKeyData:    holderPublicKeyData,
            ephemeralPublicKeyData: ephPubKeyData,
            salt:                   salt,
            wrappedFEKCombined:     wrappedFEKCombined,
            timestamp:              timestamp,
            signatureData:          signature.derRepresentation
        )
    }

    // MARK: - Private: Verify Grant Signature

    private func verifyGrantSignature(
        block:  FEKBlock,
        header: EncryptedFileHeaderV2
    ) throws {
        let ownerSigningPubKey = try P256.Signing.PublicKey(
            x963Representation: header.ownerSigningPublicKeyData
        )

        let payload   = block.grantPayload(fileId: header.fileId)
        let digest    = SHA256.hash(data: payload)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: block.signatureData)

        guard ownerSigningPubKey.isValidSignature(signature, for: Data(digest)) else {
            throw SEEncryptionError.signatureVerificationFailed
        }
    }

    // MARK: - Private: Timestamp Guard

    private func checkTimestamp(_ timestamp: UInt64) throws {
        guard timestamp > 0 else { return }  // 0 means owner block — skip

        let grantDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let age = Date().timeIntervalSince(grantDate)

        // Reject if grant is from the future (> 5 min clock skew) or too old
        guard age > -300 && age < Self.maxGrantAge else {
            throw SEEncryptionError.replayAttackDetected
        }
    }

    // MARK: - Private: ECDH → HKDF → Unwrap FEK

    private func unwrapFEK(
        block:     FEKBlock,
        myEncKey:  VaultEncryptionKey
    ) throws -> Data {
        let ephemeralPubKey = try P256.KeyAgreement.PublicKey(
            x963Representation: block.ephemeralPublicKeyData
        )

        // ECDH(myPriv, ephPub) == ECDH(ephPriv, myPub)  (commutativity)
        let sharedSecret = try myEncKey.sharedSecretFromKeyAgreement(with: ephemeralPubKey)

        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using:           SHA256.self,
            salt:            block.salt,
            sharedInfo:      block.hkdfContext,
            outputByteCount: 32
        )

        let sealedBox = try AES.GCM.SealedBox(combined: block.wrappedFEKCombined)
        let fekData   = try AES.GCM.open(sealedBox, using: wrappingKey)

        guard fekData.count == 32 else { throw SEEncryptionError.decryptionFailed }
        return fekData
    }

    // MARK: - Private: Safety Code

    /// SHA-256(ephPK ‖ recipientPK), take the first 4 bytes → 8 uppercase hex chars.
    /// Displayed on both sender and receiver screens for verbal OOB verification.
    private func computeSafetyCode(
        ephemeralPublicKeyData: Data,
        recipientPublicKeyData: Data
    ) -> String {
        var combined = ephemeralPublicKeyData
        combined.append(recipientPublicKeyData)
        let digest = SHA256.hash(data: combined)
        let prefix = Data(digest.prefix(4))
        let hex    = prefix.map { String(format: "%02X", $0) }.joined()
        // Format as "A1B2 C3D4"
        return stride(from: 0, to: hex.count, by: 4).map { i -> String in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end   = hex.index(start, offsetBy: min(4, hex.count - i))
            return String(hex[start..<end])
        }.joined(separator: " ")
    }
}
