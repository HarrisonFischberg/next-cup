import SwiftUI
import UIKit

/// Steel & Kraft design tokens. Hex values mirror docs/design/tokens/*.json
/// (design/check_tokens.py fails if they drift). Light is kraft paper and
/// steel; dark is gunmetal. Names are roles, not colors.
enum DS {
    // MARK: Color

    static let bg = Color(light: 0xD9C4A0, dark: 0x1B1D1F)          // screen: kraft / gunmetal
    static let paper = Color(light: 0xEFE6D3, dark: 0x26292C)       // sheets, tables, tiles
    static let steel = Color(light: 0x2B2F33, dark: 0x30353A)       // instrument panels, table headers
    static let onSteel = Color(light: 0xE8EAEC, dark: 0xE8EAEC)
    static let ink = Color(light: 0x1E1E1C, dark: 0xECEAE4)         // primary text
    static let ink2 = Color(light: 0x4A463E, dark: 0xB4B1A8)        // secondary text
    static let line = Color(light: 0x1E1E1C, dark: 0x8A9096)        // rules and control outlines (3:1 UI)
    static let signal = Color(light: 0xC2410C, dark: 0xFF7A3D)      // the one accent: primary action, live step
    static let onSignal = Color(light: 0xFFFFFF, dark: 0x1B1D1F)
    static let signalOnSteel = Color(light: 0xFF7A3D, dark: 0xFF7A3D) // accent text and fills on steel
    static let kraft = Color(light: 0xC9AE82, dark: 0xC9AE82)       // label stock for notes
    static let onKraft = Color(light: 0x1E1E1C, dark: 0x1E1E1C)
    static let error = Color(light: 0x9A1B0A, dark: 0xFF9C85)
    static let ok = Color(light: 0x2A6A2A, dark: 0x7FD18A)

    // MARK: Space (4-pt base)

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Minimum touch target and the control heights used on the brew station.
    enum Size {
        static let minTap: CGFloat = 44
        static let control: CGFloat = 48
        static let primary: CGFloat = 60
        static let timerControl: CGFloat = 64
    }

    // MARK: Shape

    /// One corner radius. Panels, tiles and tables are square.
    static let radius: CGFloat = 3
    static let hairline: CGFloat = 1
    static let rule: CGFloat = 1.5

    // MARK: Type

    enum Font {
        static func din(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .title) -> SwiftUI.Font {
            .custom("DINCondensed-Bold", size: size, relativeTo: style)
        }
        static func mono(_ style: SwiftUI.Font.TextStyle, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(style, design: .monospaced, weight: weight)
        }
        static func typewriter(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .body) -> SwiftUI.Font {
            .custom("AmericanTypewriter", size: size, relativeTo: style)
        }
        /// Page title: recipe name, screen heading.
        static let display = din(34, relativeTo: .title)
        /// Row and button names.
        static let headline = din(21, relativeTo: .headline)
        /// Column headers, tile labels. Always set uppercase.
        static let label = din(16, relativeTo: .footnote)
        /// Measured values in tables and lists.
        static let data = mono(.callout, .bold)
        /// Measured values in tiles.
        static let dataLarge = mono(.title, .bold)
        /// The timer. Capped at xxxLarge by the screen; stays readable at arm's length.
        static let readout = SwiftUI.Font.system(size: 104, weight: .bold, design: .monospaced)
        /// Notes on kraft.
        static let note = typewriter(15)
    }

    /// Cap for large display text so one control never exceeds the screen.
    static let displayCap: DynamicTypeSize = .accessibility1
    static let readoutCap: DynamicTypeSize = .xxxLarge
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
