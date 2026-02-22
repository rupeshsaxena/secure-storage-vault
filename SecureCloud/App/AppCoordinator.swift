import SwiftUI

// MARK: - AppCoordinator
//
// Root navigation coordinator — owns the lock gate and the tab controller.
// All deep-link routing is resolved here.

@MainActor
final class AppCoordinator: ObservableObject {

    @Published var path = NavigationPath()
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Deep Link Routing

    func handle(url: URL) {
        // securecloud://open?fileId=<uuid>
        guard url.scheme == "securecloud",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idString = components.queryItems?.first(where: { $0.name == "fileId" })?.value,
              let fileId = UUID(uuidString: idString)
        else { return }

        // Unlock the vault first, then push to the file
        if appState.isVaultLocked { return }
        // In a real app: resolve the VaultFile from the repository and push it
        _ = fileId  // placeholder until repository access is wired
    }
}
