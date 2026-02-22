import SwiftUI

// MARK: - SheetModifier
//
// Standard grab-handle + medium/large detent configuration used by all sheets.

struct SheetModifier: ViewModifier {
    var detents: Set<PresentationDetent> = [.medium, .large]
    var showsIndicator: Bool = true
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(showsIndicator ? .visible : .hidden)
            .presentationCornerRadius(cornerRadius)
            .presentationBackground(.regularMaterial)
    }
}

// MARK: - Convenience

extension View {
    func standardSheet(
        detents: Set<PresentationDetent> = [.medium, .large],
        showsIndicator: Bool = true
    ) -> some View {
        modifier(SheetModifier(detents: detents, showsIndicator: showsIndicator))
    }

    func largeSheet() -> some View {
        modifier(SheetModifier(detents: [.large], showsIndicator: true))
    }
}
