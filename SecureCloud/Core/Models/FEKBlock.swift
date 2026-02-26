import Foundation

// MARK: - FEKBlock
//
// A single File Encryption Key (FEK) block stored inside an EncryptedFileHeaderV2.
//
// There is always ONE owner block (type .owner) created at file encryption time.
// Zero or more recipient blocks (type .recipient) are appended when the owner
// shares the file with another user.
//
// Cryptographic layout for each block:
//
//   ephemeralPublicKey  — P-256 ephemeral key (generated in software, never in SE)
//   salt                — 16 random bytes for HKDF domain separation
//   wrappedFEK          — AES-256-GCM.combined(nonce+ciphertext+tag) of the 32-byte FEK
//                         encrypted under: HKDF(ECDH(ephPriv, holderSEPubKey), salt, context)
//   timestamp           — Unix seconds (0 for owner block)
//   signature           — ECDSA-P256 over grantPayload (signed by owner's SE signing key)

struct FEKBlock: Codable, Hashable, Sendable {

    // MARK: - Block Type

    enum BlockType: String, Codable, Sendable {
        case owner     = "owner"
        case recipient = "recipient"
    }

    // MARK: - Properties

    let blockType: BlockType

    /// x9.63 uncompressed P-256 public key of the key holder (owner or recipient).
    let holderPublicKeyData: Data

    /// x9.63 uncompressed P-256 ephemeral public key used for ECDH.
    /// Generated fresh per encryption / per share — never stored in SE.
    let ephemeralPublicKeyData: Data

    /// 16-byte HKDF salt. Unique per block.
    let salt: Data

    /// AES-256-GCM `.combined` representation (nonce[12] + ciphertext[32] + tag[16] = 60 bytes)
    /// of the 32-byte File Encryption Key, wrapped under the derived wrapping key.
    let wrappedFEKCombined: Data

    /// Unix timestamp in seconds. 0 for owner blocks; set to share-time for recipient blocks.
    let timestamp: UInt64

    /// ECDSA-P256 signature over `grantPayload(fileId:)`, signed by owner's SE signing key.
    let signatureData: Data

    // MARK: - Grant Payload Construction
    //
    // MUST be identical on both sender and receiver sides for signature verification to pass.
    //
    // grantPayload = SHA-256( fileId_bytes
    //                       ‖ holderPublicKeyData
    //                       ‖ ephemeralPublicKeyData
    //                       ‖ salt
    //                       ‖ wrappedFEKCombined
    //                       ‖ timestamp_LE_8bytes )

    func grantPayload(fileId: UUID) -> Data {
        var payload = Data()
        // Convert UUID to its 16 raw bytes using withUnsafeBytes on the uuid tuple
        withUnsafeBytes(of: fileId.uuid) { payload.append(contentsOf: $0) }
        payload.append(holderPublicKeyData)
        payload.append(ephemeralPublicKeyData)
        payload.append(salt)
        payload.append(wrappedFEKCombined)
        var ts = timestamp.littleEndian
        payload.append(Data(bytes: &ts, count: 8))
        return payload
    }

    // MARK: - HKDF context strings (domain separation)

    static let ownerContext    = "SecureCloud-FEK-Owner-v2"
    static let recipientContext = "SecureCloud-FEK-Recipient-v2"

    var hkdfContext: Data {
        Data((blockType == .owner ? FEKBlock.ownerContext : FEKBlock.recipientContext).utf8)
    }
}

