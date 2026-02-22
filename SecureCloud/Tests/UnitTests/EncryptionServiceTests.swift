import XCTest
@testable import SecureCloud

// MARK: - EncryptionServiceTests

final class EncryptionServiceTests: XCTestCase {

    private var sut: EncryptionService!

    override func setUp() {
        super.setUp()
        sut = EncryptionService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Encrypt / Decrypt Round Trip

    func test_encryptDecrypt_roundTrip_succeeds() throws {
        let plaintext = "Hello, SecureCloud!".data(using: .utf8)!
        let password = "StrongPassword123"

        let encrypted = try sut.encrypt(data: plaintext, password: password)
        let decrypted = try sut.decrypt(data: encrypted, password: password)

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_encryptDecrypt_withEmptyData_succeeds() throws {
        let emptyData = Data()
        let password = "SomePassword"

        let encrypted = try sut.encrypt(data: emptyData, password: password)
        let decrypted = try sut.decrypt(data: encrypted, password: password)

        XCTAssertEqual(decrypted, emptyData)
    }

    func test_encryptDecrypt_withLargeData_succeeds() throws {
        let largeData = Data(repeating: 0xAB, count: 1_000_000)  // 1 MB
        let password = "StrongPassword123"

        let encrypted = try sut.encrypt(data: largeData, password: password)
        let decrypted = try sut.decrypt(data: encrypted, password: password)

        XCTAssertEqual(decrypted, largeData)
    }

    // MARK: - Wrong Password

    func test_decrypt_withWrongPassword_throwsDecryptionFailed() throws {
        let plaintext = "Sensitive data".data(using: .utf8)!
        let encrypted = try sut.encrypt(data: plaintext, password: "CorrectPassword")

        XCTAssertThrowsError(try sut.decrypt(data: encrypted, password: "WrongPassword")) { error in
            XCTAssertEqual(error as? EncryptionError, .decryptionFailed)
        }
    }

    // MARK: - Header Validation

    func test_encrypt_resultStartsWithMagicBytes() throws {
        let data = "test".data(using: .utf8)!
        let encrypted = try sut.encrypt(data: data, password: "password")

        XCTAssertEqual(encrypted[0], 0x53)  // S
        XCTAssertEqual(encrypted[1], 0x43)  // C
        XCTAssertEqual(encrypted[2], 0x5F)  // _
        XCTAssertEqual(encrypted[3], 0x56)  // V
    }

    func test_encrypt_resultHasCorrectMinimumLength() throws {
        let data = "test".data(using: .utf8)!
        let encrypted = try sut.encrypt(data: data, password: "password")

        // Header (42) + ciphertext + 16-byte auth tag
        XCTAssertGreaterThan(encrypted.count, 42 + 16)
    }

    func test_decrypt_withCorruptedData_throwsInvalidFormat() {
        let garbage = Data(repeating: 0xFF, count: 100)

        XCTAssertThrowsError(try sut.decrypt(data: garbage, password: "password")) { error in
            XCTAssertEqual(error as? EncryptionError, .invalidFormat)
        }
    }

    func test_decrypt_withTooShortData_throwsInvalidFormat() {
        let tooShort = Data(repeating: 0, count: 10)

        XCTAssertThrowsError(try sut.decrypt(data: tooShort, password: "password")) { error in
            XCTAssertEqual(error as? EncryptionError, .invalidFormat)
        }
    }

    // MARK: - Determinism

    func test_twoEncryptions_produceDifferentCiphertext() throws {
        let plaintext = "Same data".data(using: .utf8)!
        let password = "SamePassword"

        let encrypted1 = try sut.encrypt(data: plaintext, password: password)
        let encrypted2 = try sut.encrypt(data: plaintext, password: password)

        // Random salt + nonce means different ciphertext each time
        XCTAssertNotEqual(encrypted1, encrypted2)
    }
}

extension EncryptionError: Equatable {
    public static func == (lhs: EncryptionError, rhs: EncryptionError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPassword, .invalidPassword): return true
        case (.invalidFormat, .invalidFormat):     return true
        case (.decryptionFailed, .decryptionFailed): return true
        case (.keyDerivationFailed, .keyDerivationFailed): return true
        default: return false
        }
    }
}
