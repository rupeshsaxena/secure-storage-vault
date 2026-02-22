import SwiftUI

// MARK: - NavBarModifier
//
// Applies a transparent glass-style navigation bar across the app.
// Attach with .modifier(NavBarModifier()) on NavigationStack.

struct NavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - SheetNavBarModifier

struct SheetNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Tokens.Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - View Convenience

extension View {
    func glassNavBar() -> some View {
        modifier(NavBarModifier())
    }

    func sheetNavBar() -> some View {
        modifier(SheetNavBarModifier())
    }
}
