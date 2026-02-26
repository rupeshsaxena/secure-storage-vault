@testable import SecureCloud
import CryptoKit
import XCTest

// MARK: - SecureEnclaveEncryptionTests
//
// All tests use *software* P-256 keys so they can run on the Simulator.
// The SecureEnclaveService itself switches to hardware SE keys on a real
// device, but the cryptographic operations are identical.

@MainActor
final class SecureEnclaveEncryptionTests: XCTestCase {

    // ── System Under Test ──────────────────────────────────────────────────

    private var sut: SecureEnclaveEncryptionService!
    private var verifier: KeyVerificationService!

    // ── Fixtures ───────────────────────────────────────────────────────────

    private var ownerKeyPair: VaultKeyPair!
    private var recipientKeyPair: VaultKeyPair!
    private var recipientContact: TrustedContact!

    override func setUp() async throws {
        try await super.setUp()
        sut      = SecureEnclaveEncryptionService()
        verifier = KeyVerificationService()

        // Build owner key pair (software, since SE unavailable in tests)
        ownerKeyPair = makeSoftwareKeyPair(userId: UUID())

        // Build recipient key pair
        recipientKeyPair = makeSoftwareKeyPair(userId: UUID())

        // Build a verified TrustedContact for the recipient
        recipientContact = TrustedContact(
            id:                       UUID(),
            remoteUserId:             recipientKeyPair.userId,
            displayName:              "Alice",
            encryptionPublicKeyData:  recipientKeyPair.encryptionPublicKeyData,
            signingPublicKeyData:     recipientKeyPair.signingPublicKeyData,
            addedAt:                  Date(),
            verifiedAt:               Date(),
            verificationMethod:       .qrCodeScan
        )
    }

    override func tearDown() async throws {
        sut = nil
        verifier = nil
        ownerKeyPair = nil
        recipientKeyPair = nil
        recipientContact = nil
        try await super.tearDown()
    }

    // MARK: - 1. Owner encrypt / decrypt round-trip

    func test_ownerEncryptDecrypt_roundTrip() throws {
        let plaintext = Data("Top secret document content 🔒".utf8)

        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "test.txt",
            contentType: "public.plain-text"
        )

        XCTAssertFalse(encrypted.isEmpty)

        let (decrypted, header) = try sut.decryptFile(
            encryptedData: encrypted,
            keyPair:       ownerKeyPair
        )

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertEqual(header.filename, "test.txt")
        XCTAssertEqual(header.originalSize, UInt64(plaintext.count))
        XCTAssertEqual(header.ownerEncryptionPublicKeyData, ownerKeyPair.encryptionPublicKeyData)
    }

    // MARK: - 2. Large file round-trip

    func test_ownerEncryptDecrypt_largeFile() throws {
        let plaintext = Data(repeating: 0xAB, count: 2 * 1024 * 1024)  // 2 MB

        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "large.bin",
            contentType: "public.data"
        )
        let (decrypted, _) = try sut.decryptFile(
            encryptedData: encrypted,
            keyPair:       ownerKeyPair
        )
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - 3. Wrong identity cannot decrypt

    func test_wrongIdentity_cannotDecrypt() throws {
        let plaintext = Data("secret".utf8)
        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "x.txt",
            contentType: "public.plain-text"
        )

        // Recipient (no FEKBlock for them yet) tries to decrypt → noRecipientBlock
        XCTAssertThrowsError(
            try sut.decryptFile(encryptedData: encrypted, keyPair: recipientKeyPair)
        ) { error in
            XCTAssertEqual(error as? SEEncryptionError, .noRecipientBlock)
        }
    }

    // MARK: - 4. Share grant creation + recipient decryption

    func test_addRecipient_recipientCanDecrypt() throws {
        let plaintext = Data("shared secret payload".utf8)

        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "share.pdf",
            contentType: "com.adobe.pdf"
        )

        let (updatedFile, _) = try sut.addRecipient(
            to:               encrypted,
            recipientContact: recipientContact,
            ownerKeyPair:     ownerKeyPair
        )

        let (decrypted, header) = try sut.decryptFile(
            encryptedData: updatedFile,
            keyPair:       recipientKeyPair
        )

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertEqual(header.fekBlocks.count, 2)    // owner + recipient
        XCTAssertEqual(
            header.fekBlocks.filter { $0.blockType == .recipient }.count,
            1
        )
    }

    // MARK: - 5. Safety code is deterministic for same inputs

    func test_safetyCode_deterministic() throws {
        let plaintext = Data("safety code test".utf8)
        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "f.txt",
            contentType: "public.plain-text"
        )
        let (updated, code1) = try sut.addRecipient(
            to: encrypted,
            recipientContact: recipientContact,
            ownerKeyPair: ownerKeyPair
        )

        // Extract the recipient block and compute safety code independently
        let (header, _) = try EncryptedFileHeaderV2.parse(fileData: updated)
        let recipientBlock = try header.recipientBlock(
            for: recipientKeyPair.encryptionPublicKeyData
        )

        let code2 = verifier.safetyCode(
            ephemeralPublicKeyData: recipientBlock.ephemeralPublicKeyData,
            recipientPublicKeyData: recipientContact.encryptionPublicKeyData
        )

        XCTAssertEqual(code1, code2)
        XCTAssertEqual(code1.count, 9)   // "A1B2 C3D4" = 4+1+4 = 9 chars
    }

    // MARK: - 6. MITM detection — tampered signature

    func test_mitmDetection_tamperedSignature() throws {
        let encrypted = try sut.encryptFile(
            data:        Data("mitm test".utf8),
            keyPair:     ownerKeyPair,
            filename:    "m.txt",
            contentType: "public.plain-text"
        )

        // Parse the file and corrupt the owner block signature
        var (header, sealedBody) = try EncryptedFileHeaderV2.parse(fileData: encrypted)

        let ownerIdx = header.fekBlocks.firstIndex { $0.blockType == .owner }!
        let originalBlock = header.fekBlocks[ownerIdx]

        // Flip a byte in the signature
        var corruptedSig = originalBlock.signatureData
        corruptedSig[8] ^= 0xFF

        header.fekBlocks[ownerIdx] = FEKBlock(
            blockType:              originalBlock.blockType,
            holderPublicKeyData:    originalBlock.holderPublicKeyData,
            ephemeralPublicKeyData: originalBlock.ephemeralPublicKeyData,
            salt:                   originalBlock.salt,
            wrappedFEKCombined:     originalBlock.wrappedFEKCombined,
            timestamp:              originalBlock.timestamp,
            signatureData:          corruptedSig
        )

        let tampered = try header.buildFile(sealedBody: sealedBody)

        XCTAssertThrowsError(
            try sut.decryptFile(encryptedData: tampered, keyPair: ownerKeyPair)
        ) { error in
            XCTAssertEqual(error as? SEEncryptionError, .signatureVerificationFailed)
        }
    }

    // MARK: - 7. Replay attack — expired timestamp

    func test_replayAttack_expiredTimestamp() throws {
        // Create an encrypted file + grant for recipient
        let plaintext = Data("replay test".utf8)
        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "r.txt",
            contentType: "public.plain-text"
        )
        let (updated, _) = try sut.addRecipient(
            to: encrypted,
            recipientContact: recipientContact,
            ownerKeyPair: ownerKeyPair
        )

        // Backdate the recipient block timestamp by 2 years
        var (header, sealedBody) = try EncryptedFileHeaderV2.parse(fileData: updated)

        let recipIdx = header.fekBlocks.firstIndex { $0.blockType == .recipient }!
        let recipBlock = header.fekBlocks[recipIdx]

        let expiredTimestamp = UInt64(
            Date().addingTimeInterval(-60 * 60 * 24 * 400).timeIntervalSince1970
        )  // 400 days ago

        header.fekBlocks[recipIdx] = FEKBlock(
            blockType:              recipBlock.blockType,
            holderPublicKeyData:    recipBlock.holderPublicKeyData,
            ephemeralPublicKeyData: recipBlock.ephemeralPublicKeyData,
            salt:                   recipBlock.salt,
            wrappedFEKCombined:     recipBlock.wrappedFEKCombined,
            timestamp:              expiredTimestamp,
            signatureData:          recipBlock.signatureData
        )

        let expired = try header.buildFile(sealedBody: sealedBody)

        // Note: the timestamp change also invalidates the signature, so we
        // expect signatureVerificationFailed (checked before timestamp).
        XCTAssertThrowsError(
            try sut.decryptFile(encryptedData: expired, keyPair: recipientKeyPair)
        )
    }

    // MARK: - 8. Unverified contact cannot be added as recipient

    func test_unverifiedContact_shareThrows() throws {
        let encrypted = try sut.encryptFile(
            data:        Data("x".utf8),
            keyPair:     ownerKeyPair,
            filename:    "y.txt",
            contentType: "public.plain-text"
        )

        let unverified = TrustedContact(
            id:                      UUID(),
            remoteUserId:            UUID(),
            displayName:             "Eve",
            encryptionPublicKeyData: recipientKeyPair.encryptionPublicKeyData,
            signingPublicKeyData:    recipientKeyPair.signingPublicKeyData,
            addedAt:                 Date(),
            verifiedAt:              nil,
            verificationMethod:      .unverified
        )

        XCTAssertThrowsError(
            try sut.addRecipient(
                to:               encrypted,
                recipientContact: unverified,
                ownerKeyPair:     ownerKeyPair
            )
        ) { error in
            XCTAssertEqual(error as? SEEncryptionError, .contactNotVerified)
        }
    }

    // MARK: - 9. Remove recipient

    func test_removeRecipient_grantIsGone() throws {
        let plaintext = Data("removable grant".utf8)
        let encrypted = try sut.encryptFile(
            data:        plaintext,
            keyPair:     ownerKeyPair,
            filename:    "rem.txt",
            contentType: "public.plain-text"
        )
        let (withRecipient, _) = try sut.addRecipient(
            to:               encrypted,
            recipientContact: recipientContact,
            ownerKeyPair:     ownerKeyPair
        )
        let (h1, _) = try EncryptedFileHeaderV2.parse(fileData: withRecipient)
        XCTAssertEqual(h1.fekBlocks.count, 2)

        let withoutRecipient = try sut.removeRecipient(
            from:                   withRecipient,
            recipientPublicKeyData: recipientKeyPair.encryptionPublicKeyData,
            ownerKeyPair:           ownerKeyPair
        )
        let (h2, _) = try EncryptedFileHeaderV2.parse(fileData: withoutRecipient)
        XCTAssertEqual(h2.fekBlocks.count, 1)
        XCTAssertEqual(h2.fekBlocks[0].blockType, .owner)
    }

    // MARK: - 10. QR code identity round-trip

    func test_qrCodePayload_roundTrip() throws {
        let identity = makeVaultIdentity(from: ownerKeyPair)

        let qrData = try verifier.qrCodeData(for: identity)
        XCTAssertFalse(qrData.isEmpty)

        let decoded = try verifier.identity(fromQRData: qrData)
        XCTAssertEqual(decoded.userId, identity.userId)
        XCTAssertEqual(decoded.encryptionPublicKeyData, identity.encryptionPublicKeyData)
        XCTAssertEqual(decoded.signingPublicKeyData,    identity.signingPublicKeyData)
        XCTAssertEqual(decoded.displayName,             identity.displayName)
    }

    // MARK: - 11. Fingerprint strings

    func test_fingerprintString_format() throws {
        let identity = makeVaultIdentity(from: ownerKeyPair)
        let full  = verifier.fingerprintString(for: identity)
        let short = verifier.shortFingerprint(for: identity)

        // Full: 8 groups of 4 hex chars separated by spaces = 8*4 + 7 = 39 chars
        XCTAssertEqual(full.count, 39)

        // Short: 4 groups separated by "-" = 4*4 + 3 = 19 chars
        XCTAssertEqual(short.count, 19)
    }

    // MARK: - 12. Grant signature verification service

    func test_verifyGrant_validSignature_passes() throws {
        let encrypted = try sut.encryptFile(
            data:        Data("verify test".utf8),
            keyPair:     ownerKeyPair,
            filename:    "v.txt",
            contentType: "public.plain-text"
        )
        let (header, _) = try EncryptedFileHeaderV2.parse(fileData: encrypted)
        let ownerBlock = try header.ownerBlock()

        // Should not throw
        XCTAssertNoThrow(try verifier.verifyGrant(block: ownerBlock, in: header))
    }

    // MARK: - Helpers

    private func makeSoftwareKeyPair(userId: UUID) -> VaultKeyPair {
        let encKey  = P256.KeyAgreement.PrivateKey()
        let signKey = P256.Signing.PrivateKey()
        return VaultKeyPair(
            userId:        userId,
            encryptionKey: .software(encKey),
            signingKey:    .software(signKey)
        )
    }

    private func makeVaultIdentity(from pair: VaultKeyPair) -> VaultIdentity {
        VaultIdentity(
            userId:                  pair.userId,
            encryptionPublicKeyData: pair.encryptionPublicKeyData,
            signingPublicKeyData:    pair.signingPublicKeyData,
            createdAt:               Date(),
            displayName:             "Test User"
        )
    }
}

// MARK: - SEEncryptionError equatable for XCTest

extension SEEncryptionError: Equatable {
    public static func == (lhs: SEEncryptionError, rhs: SEEncryptionError) -> Bool {
        switch (lhs, rhs) {
        case (.secureEnclaveUnavailable, .secureEnclaveUnavailable):   return true
        case (.identityNotFound, .identityNotFound):                   return true
        case (.missingOwnerBlock, .missingOwnerBlock):                 return true
        case (.noRecipientBlock, .noRecipientBlock):                   return true
        case (.signatureVerificationFailed, .signatureVerificationFailed): return true
        case (.replayAttackDetected, .replayAttackDetected):           return true
        case (.decryptionFailed, .decryptionFailed):                   return true
        case (.invalidFileFormat, .invalidFileFormat):                 return true
        case (.contactNotVerified, .contactNotVerified):               return true
        case (.keyGenerationFailed(let a), .keyGenerationFailed(let b)): return a == b
        default:                                                       return false
        }
    }
}
