import XCTest

// MARK: - VaultUITests

final class VaultUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-biometrics"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Lock Screen

    func test_lockScreen_isShownOnLaunch() {
        XCTAssertTrue(app.staticTexts["SecureCloud"].waitForExistence(timeout: 3))
    }

    func test_lockScreen_hasPasscodeButton() {
        XCTAssertTrue(
            app.buttons["Use Passcode"].waitForExistence(timeout: 3)
            || app.buttons["Use Face ID"].waitForExistence(timeout: 3)
        )
    }

    // MARK: - Vault (after unlock)

    func test_vault_tabBarIsVisible_afterUnlock() {
        unlockWithPasscode()
        XCTAssertTrue(app.buttons["Vault"].waitForExistence(timeout: 3))
    }

    func test_vault_searchBarIsAccessible() {
        unlockWithPasscode()
        let search = app.textFields["Search files…"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
    }

    func test_vault_addFileButton_opensSheet() {
        unlockWithPasscode()
        let addButton = app.buttons["plus"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            XCTAssertTrue(app.staticTexts["Add File"].waitForExistence(timeout: 3))
        }
    }

    // MARK: - Sync Tab

    func test_syncTab_isNavigable() {
        unlockWithPasscode()
        let syncTab = app.buttons["Sync"]
        if syncTab.waitForExistence(timeout: 3) {
            syncTab.tap()
            XCTAssertTrue(app.navigationBars["Sync"].waitForExistence(timeout: 3))
        }
    }

    // MARK: - Settings Tab

    func test_settingsTab_showsFaceIDToggle() {
        unlockWithPasscode()
        app.buttons["Settings"].tap()
        XCTAssertTrue(
            app.staticTexts["Face ID / Touch ID"].waitForExistence(timeout: 3)
        )
    }

    // MARK: - Helpers

    private func unlockWithPasscode() {
        let passcodeButton = app.buttons["Use Passcode"]
        if passcodeButton.waitForExistence(timeout: 2) {
            passcodeButton.tap()
        }
        // In UI tests with --skip-biometrics the vault unlocks automatically
    }
}
