import XCTest
@testable import SecureCloud

// MARK: - VaultUseCaseTests

final class VaultUseCaseTests: XCTestCase {

    private var encryptionService: EncryptionService!
    private var vaultRepository: VaultRepository!
    private var sut: VaultUseCase!

    override func setUp() async throws {
        try await super.setUp()
        encryptionService = EncryptionService()
        vaultRepository = VaultRepository(
            encryption: encryptionService,
            keychain: KeychainService()
        )
        sut = VaultUseCase(repository: vaultRepository, encryption: encryptionService)
    }

    override func tearDown() async throws {
        sut = nil
        vaultRepository = nil
        encryptionService = nil
        try await super.tearDown()
    }

    // MARK: - Import File

    func test_importFile_addsFileToRepository() async throws {
        let data = "Test file content".data(using: .utf8)!
        let file = try await sut.importFile(
            name: "test.pdf",
            fileType: .pdf,
            data: data,
            password: "password"
        )

        XCTAssertEqual(file.name, "test.pdf")
        XCTAssertEqual(file.fileType, .pdf)
        XCTAssertEqual(file.sizeBytes, Int64(data.count))
        XCTAssertEqual(file.encryptionStandard, "AES-256-GCM")

        let files = try await sut.loadFiles()
        XCTAssertTrue(files.contains(where: { $0.id == file.id }))
    }

    // MARK: - Delete File

    func test_deleteFile_removesFileFromRepository() async throws {
        let data = "Content".data(using: .utf8)!
        let file = try await sut.importFile(
            name: "delete-me.pdf",
            fileType: .pdf,
            data: data,
            password: "password"
        )

        try await sut.deleteFile(id: file.id)

        let files = try await sut.loadFiles()
        XCTAssertFalse(files.contains(where: { $0.id == file.id }))
    }

    // MARK: - Create Folder

    func test_createFolder_addsToRepository() async throws {
        let folder = try await sut.createFolder(name: "TestFolder")

        XCTAssertEqual(folder.name, "TestFolder")

        let folders = try await sut.loadFolders()
        XCTAssertTrue(folders.contains(where: { $0.id == folder.id }))
    }

    // MARK: - Search

    func test_search_withMatchingQuery_returnsMatchingFiles() async throws {
        let data = Data(repeating: 0, count: 10)
        _ = try await sut.importFile(name: "Invoice_2024.pdf", fileType: .pdf, data: data, password: "p")
        _ = try await sut.importFile(name: "Photo.jpg", fileType: .image, data: data, password: "p")

        let results = try await sut.search(query: "Invoice")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Invoice_2024.pdf")
    }

    func test_search_withEmptyQuery_returnsEmpty() async throws {
        let results = try await sut.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Decrypt Round Trip

    func test_loadDecryptedData_afterImport_matchesOriginal() async throws {
        let originalData = "Sensitive content".data(using: .utf8)!
        let password = "vault-key"

        let file = try await sut.importFile(
            name: "secret.txt",
            fileType: .generic,
            data: originalData,
            password: password
        )

        let decrypted = try await sut.loadDecryptedData(for: file.id, password: password)
        XCTAssertEqual(decrypted, originalData)
    }
}
