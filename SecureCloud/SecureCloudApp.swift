import SwiftUI

// MARK: - SecureCloudApp

@main
struct SecureCloudApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isVaultLocked {
                    LockView()
                } else {
                    RootTabView()
                }
            }
            .preferredColorScheme(.light)               // Light mode only — by design
            .environmentObject(appState)
            .environment(\.dependencyContainer, DependencyContainer.shared)
            .animation(.easeInOut(duration: 0.3), value: appState.isVaultLocked)
        }
    }
}
