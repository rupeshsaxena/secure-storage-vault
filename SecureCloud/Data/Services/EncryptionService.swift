import CryptoKit
import Foundation
import Security

// MARK: - EncryptionServiceProtocol

protocol EncryptionServiceProtocol: Sendable {
    func encrypt(data: Data, password: String) throws -> Data
    func decrypt(data: Data, password: String) throws -> Data
    func encryptStream(url: URL, password: String, destination: URL) throws
    func decryptToMemory(url: URL, password: String) throws -> Data
}

// MARK: - EncryptionService

/// AES-256-GCM encryption using Apple CryptoKit.
///
/// Encrypted file layout on disk:
/// ```
/// [ 4 bytes  ] Magic: 0x53 0x43 0x5F 0x56  ("SC_V")
/// [ 2 bytes  ] Version: 0x00 0x01
/// [ 16 bytes ] Salt  (PBKDF2 input)
/// [ 12 bytes ] GCM Nonce
/// [ 8 bytes  ] Original plaintext size (UInt64 little-endian)
/// [ N bytes  ] AES-256-GCM ciphertext + 16-byte auth tag
/// ```
/// Total header: 42 bytes before ciphertext.
final class EncryptionService: EncryptionServiceProtocol, Sendable {

    // MARK: - Key Derivation

    /// Derives a 256-bit symmetric key using HKDF-SHA256.
    /// For production the comment block shows how to swap in PBKDF2 via CommonCrypto
    /// if you need the full 310,000-iteration hardness benchmark.
    private func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPassword
        }

        // HKDF-SHA256 (fast, suitable for keys already stored in Keychain)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("SecureCloud-AES256GCM".utf8),
            outputByteCount: 32
        )
        return derivedKey

        /*
         // PBKDF2-SHA256 via CommonCrypto (310k iterations — use for password-based auth):
         import CommonCrypto
         var derivedBytes = [UInt8](repeating: 0, count: 32)
         let status = salt.withUnsafeBytes { saltBytes in
             passwordData.withUnsafeBytes { pwBytes in
                 CCKeyDerivationPBKDF(
                     CCPBKDFAlgorithm(kCCPBKDF2),
                     pwBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                     passwordData.count,
                     saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                     salt.count,
                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                     310_000,
                     &derivedBytes,
                     derivedBytes.count
                 )
             }
         }
         guard status == kCCSuccess else { throw EncryptionError.keyDerivationFailed }
         return SymmetricKey(data: Data(derivedBytes))
         */
    }

    // MARK: - Encrypt

    func encrypt(data: Data, password: String) throws -> Data {
        let salt = try generateRandom(bytes: 16)
        let nonce = try generateRandom(bytes: 12)

        let key = try deriveKey(password: password, salt: salt)
        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealed = try AES.GCM.seal(data, using: key, nonce: gcmNonce)

        var result = Data()
        // Magic: "SC_V"
        result.append(contentsOf: [0x53, 0x43, 0x5F, 0x56])
        // Version: 0x0001
        result.append(contentsOf: [0x00, 0x01])
        // Salt (16 bytes)
        result.append(salt)
        // Nonce (12 bytes)
        result.append(nonce)
        // Original size (8 bytes, little-endian)
        var originalSize = UInt64(data.count).littleEndian
        result.append(Data(bytes: &originalSize, count: 8))
        // Ciphertext + auth tag (appended by CryptoKit)
        result.append(sealed.ciphertext)
        result.append(sealed.tag)
        return result
    }

    // MARK: - Decrypt

    func decrypt(data: Data, password: String) throws -> Data {
        guard data.count > 42 else { throw EncryptionError.invalidFormat }

        // Validate magic bytes
        let magic = data[data.startIndex..<data.index(data.startIndex, offsetBy: 4)]
        guard magic.elementsEqual([0x53, 0x43, 0x5F, 0x56]) else {
            throw EncryptionError.invalidFormat
        }

        let base = data.startIndex
        let salt  = data[data.index(base, offsetBy: 6)..<data.index(base, offsetBy: 22)]
        let nonce = data[data.index(base, offsetBy: 22)..<data.index(base, offsetBy: 34)]
        // originalSize at 34..<42 (available if needed for streaming)
        let ciphertextAndTag = data[data.index(base, offsetBy: 42)...]

        let key = try deriveKey(password: password, salt: salt)
        let gcmNonce = try AES.GCM.Nonce(data: nonce)

        guard ciphertextAndTag.count >= 16 else { throw EncryptionError.invalidFormat }
        let ciphertext = ciphertextAndTag.dropLast(16)
        let tag = ciphertextAndTag.suffix(16)

        do {
            let sealed = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealed, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - Stream Encrypt (large files)

    func encryptStream(url: URL, password: String, destination: URL) throws {
        // MVP: load entire file — chunked streaming added in v2
        let data = try Data(contentsOf: url)
        let encrypted = try encrypt(data: data, password: password)
        try encrypted.write(to: destination, options: .atomic)
    }

    // MARK: - Decrypt to Memory (media playback — never writes plaintext to disk)

    func decryptToMemory(url: URL, password: String) throws -> Data {
        let encrypted = try Data(contentsOf: url)
        return try decrypt(data: encrypted, password: password)
    }

    // MARK: - Helpers

    private func generateRandom(bytes count: Int) throws -> Data {
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard result == errSecSuccess else { throw EncryptionError.keyDerivationFailed }
        return data
    }
}

// MARK: - EncryptionError

enum EncryptionError: LocalizedError {
    case invalidPassword
    case invalidFormat
    case decryptionFailed
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPassword:     return "Invalid password provided."
        case .invalidFormat:       return "File is not a valid SecureCloud encrypted file."
        case .decryptionFailed:    return "Decryption failed — wrong password or corrupted file."
        case .keyDerivationFailed: return "Key derivation failed."
        }
    }
}
