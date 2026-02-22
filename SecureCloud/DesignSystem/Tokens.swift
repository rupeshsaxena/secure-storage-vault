import SwiftUI

// MARK: - Tokens
// All design decisions are final. Colours, typography, radii, and spacing match
// the finalized SecureCloud design system.

enum Tokens {

    // MARK: - Colors

    enum Color {
        /// Page/screen background — #F0F2F5
        static let background     = SwiftUI.Color(hex: "F0F2F5")
        /// Glass card surface — white 80% opacity
        static let surface        = SwiftUI.Color.white.opacity(0.80)
        /// Glass card surface elevated — white 95% opacity
        static let surfaceHi      = SwiftUI.Color.white.opacity(0.95)
        /// Border default — black 7% opacity
        static let border         = SwiftUI.Color.black.opacity(0.07)
        /// Border medium — black 11% opacity
        static let borderMed      = SwiftUI.Color.black.opacity(0.11)
        /// Primary text — black 85%
        static let textPrimary    = SwiftUI.Color.black.opacity(0.85)
        /// Secondary text — black 46%
        static let textSecondary  = SwiftUI.Color.black.opacity(0.46)
        /// Tertiary text — black 28%
        static let textTertiary   = SwiftUI.Color.black.opacity(0.28)
        /// Divider / subtle fill — black 7%
        static let textQuaternary = SwiftUI.Color.black.opacity(0.07)
        /// Accent blue — #2F78C5
        static let accent         = SwiftUI.Color(hex: "2F78C5")
        /// Accent blue dim — 12% opacity
        static let accentDim      = SwiftUI.Color(hex: "2F78C5").opacity(0.12)
        /// Green — #2D8A52
        static let green          = SwiftUI.Color(hex: "2D8A52")
        /// Green dim — 11% opacity
        static let greenDim       = SwiftUI.Color(hex: "2D8A52").opacity(0.11)
        /// Orange/warning — #B06828
        static let orange         = SwiftUI.Color(hex: "B06828")
        /// Red/danger — #B03030
        static let red            = SwiftUI.Color(hex: "B03030")
        /// Red dim — 10% opacity
        static let redDim         = SwiftUI.Color(hex: "B03030").opacity(0.10)
        /// Page background outer (device chrome) — #DDE0E8
        static let pageBg         = SwiftUI.Color(hex: "DDE0E8")
    }

    // MARK: - Typography (Inter)

    enum Font {
        static func largeTitle(_ weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .custom("Inter", size: 22).weight(weight)
        }
        static func title(_ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .custom("Inter", size: 18).weight(weight)
        }
        static func headline(_ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .custom("Inter", size: 16).weight(weight)
        }
        static func subheadline(_ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .custom("Inter", size: 14).weight(weight)
        }
        static func body(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom("Inter", size: 13).weight(weight)
        }
        static func footnote(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom("Inter", size: 12).weight(weight)
        }
        static func caption1(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom("Inter", size: 11).weight(weight)
        }
        static func caption2(_ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .custom("Inter", size: 10).weight(weight)
        }
        /// Section labels — uppercase 10pt
        static func label(_ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .custom("Inter", size: 10).weight(weight)
        }
    }

    // MARK: - Radii

    enum Radius {
        static let screen:  CGFloat = 39   // Screen inset from device
        static let device:  CGFloat = 48   // Device outer
        static let card:    CGFloat = 14   // Standard glass card
        static let cardSm:  CGFloat = 12   // Smaller cards, inputs
        static let chip:    CGFloat = 16   // Filter chips (pill)
        static let icon:    CGFloat = 8    // Icon container
        static let iconSm:  CGFloat = 7    // Small icon container
        static let tabBar:  CGFloat = 22   // Tab bar container
        static let avatar:  CGFloat = 50   // Person avatar
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 6
        static let md:  CGFloat = 9
        static let lg:  CGFloat = 12
        static let xl:  CGFloat = 16
        static let xxl: CGFloat = 20
    }

    // MARK: - Blur

    static let blur: CGFloat = 20   // backdrop blur radius
}

// MARK: - Color hex init helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
