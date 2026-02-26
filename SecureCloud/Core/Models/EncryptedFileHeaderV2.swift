import Foundation

// MARK: - EncryptedFileHeaderV2
//
// JSON-serialisable header for SCV2 encrypted files.
//
// Binary layout on disk:
//   [8 bytes]  Header JSON length (UInt64 little-endian)
//   [N bytes]  Header JSON  (UTF-8)
//   [M bytes]  AES-256-GCM sealed file body
//              └─ .combined = nonce(12) + ciphertext + tag(16)

struct EncryptedFileHeaderV2: Codable, Sendable {

    // MARK: - Header Fields

    static let magic = "SCV2"
    static let currentVersion: Int = 2

    let magic: String           // always "SCV2"
    let version: Int            // always 2
    let fileId: UUID
    let filename: String
    let contentType: String     // UTType identifier, e.g. "public.pdf"
    let originalSize: UInt64

    /// x9.63 uncompressed P-256 key of the file's owner (for identity & sig verification).
    let ownerEncryptionPublicKeyData: Data

    /// x9.63 uncompressed P-256 signing key of the owner.
    let ownerSigningPublicKeyData: Data

    /// One owner FEKBlock + zero or more recipient FEKBlocks.
    var fekBlocks: [FEKBlock]

    // MARK: - Init

    init(
        fileId: UUID = UUID(),
        filename: String,
        contentType: String,
        originalSize: UInt64,
        ownerEncryptionPublicKeyData: Data,
        ownerSigningPublicKeyData: Data,
        fekBlocks: [FEKBlock] = []
    ) {
        self.magic = Self.magic
        self.version = Self.currentVersion
        self.fileId = fileId
        self.filename = filename
        self.contentType = contentType
        self.originalSize = originalSize
        self.ownerEncryptionPublicKeyData = ownerEncryptionPublicKeyData
        self.ownerSigningPublicKeyData = ownerSigningPublicKeyData
        self.fekBlocks = fekBlocks
    }

    // MARK: - Validation

    var isValid: Bool { magic == Self.magic && version == Self.currentVersion }

    func ownerBlock() throws -> FEKBlock {
        guard let block = fekBlocks.first(where: { $0.blockType == .owner }) else {
            throw SEEncryptionError.missingOwnerBlock
        }
        return block
    }

    func recipientBlock(for holderPublicKeyData: Data) throws -> FEKBlock {
        guard let block = fekBlocks.first(where: {
            $0.blockType == .recipient && $0.holderPublicKeyData == holderPublicKeyData
        }) else {
            throw SEEncryptionError.noRecipientBlock
        }
        return block
    }
}

// MARK: - Serialisation Helpers

extension EncryptedFileHeaderV2 {

    /// Serialise this header to JSON using base64 for all Data fields.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        return try encoder.encode(self)
    }

    static func from(jsonData: Data) throws -> EncryptedFileHeaderV2 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        let header = try decoder.decode(EncryptedFileHeaderV2.self, from: jsonData)
        guard header.isValid else { throw SEEncryptionError.invalidFileFormat }
        return header
    }

    /// Build the full binary file (header length prefix + JSON + sealed body).
    func buildFile(sealedBody: Data) throws -> Data {
        let headerJSON = try jsonData()
        var result = Data()

        // 8-byte length prefix (UInt64 little-endian)
        var headerLen = UInt64(headerJSON.count).littleEndian
        result.append(Data(bytes: &headerLen, count: 8))

        // Header JSON
        result.append(headerJSON)

        // Sealed file body (AES-GCM .combined)
        result.append(sealedBody)
        return result
    }

    /// Split raw file bytes back into (header, sealedBody).
    static func parse(fileData: Data) throws -> (header: EncryptedFileHeaderV2, sealedBody: Data) {
        guard fileData.count > 8 else { throw SEEncryptionError.invalidFileFormat }

        let base = fileData.startIndex
        let lenBytes = fileData[base..<fileData.index(base, offsetBy: 8)]
        let headerLen = lenBytes.withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }

        let headerStart = fileData.index(base, offsetBy: 8)
        guard headerLen > 0, Int(headerLen) <= fileData.count - 8 else {
            throw SEEncryptionError.invalidFileFormat
        }

        let headerEnd = fileData.index(headerStart, offsetBy: Int(headerLen))
        let headerJSON = fileData[headerStart..<headerEnd]
        let sealedBody = fileData[headerEnd...]

        let header = try Self.from(jsonData: Data(headerJSON))
        return (header, Data(sealedBody))
    }
}

// MARK: - SEEncryptionError

enum SEEncryptionError: LocalizedError {
    case secureEnclaveUnavailable
    case identityNotFound
    case missingOwnerBlock
    case noRecipientBlock
    case signatureVerificationFailed   // MITM detected
    case replayAttackDetected          // Timestamp too old
    case decryptionFailed
    case invalidFileFormat
    case keyGenerationFailed(String)
    case contactNotVerified

    var errorDescription: String? {
        switch self {
        case .secureEnclaveUnavailable:     return "Secure Enclave is not available on this device."
        case .identityNotFound:             return "No vault identity found. Please set up your identity first."
        case .missingOwnerBlock:            return "File is missing the owner encryption block."
        case .noRecipientBlock:             return "No decryption grant found for your identity."
        case .signatureVerificationFailed:  return "⚠️ Share grant signature is invalid — possible MITM attack detected. Do not use this file."
        case .replayAttackDetected:         return "Share grant has expired or timestamp is invalid."
        case .decryptionFailed:             return "Decryption failed — wrong key or corrupted file."
        case .invalidFileFormat:            return "File is not a valid SCV2 SecureCloud encrypted file."
        case .keyGenerationFailed(let msg): return "Key generation failed: \(msg)"
        case .contactNotVerified:           return "This contact's keys have not been verified. Please verify via QR code or safety number first."
        }
    }
}
