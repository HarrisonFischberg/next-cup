import SwiftUI
import UIKit

/// Steel & Kraft design tokens. Hex values mirror docs/design/tokens/*.json
/// (design/check_tokens.py fails if they drift). Light is kraft paper and
/// steel; dark is gunmetal. Names are roles, not colors.
enum DS {
  // MARK: Color

  /// The palette of the style chosen in Settings; read each time so a change shows at once.
  static var palette: Palette { AppStyle.current.palette }

  static var bg: Color { Color(palette.bg) }  // screen: kraft / gunmetal
  static var paper: Color { Color(palette.paper) }  // sheets, tables, tiles
  static var steel: Color { Color(palette.steel) }  // instrument panels, table headers
  static var onSteel: Color { Color(palette.onSteel) }
  static var ink: Color { Color(palette.ink) }  // primary text
  static var ink2: Color { Color(palette.ink2) }  // secondary text
  static var line: Color { Color(palette.line) }  // rules and control outlines (3:1 UI)
  static var signal: Color { Color(palette.signal) }  // the one accent
  static var onSignal: Color { Color(palette.onSignal) }
  static var signalOnSteel: Color { Color(palette.signalOnSteel) }  // accent on steel
  static var kraft: Color { Color(palette.kraft) }  // label stock for notes
  static var onKraft: Color { Color(palette.onKraft) }
  static var error: Color { Color(palette.error) }
  static var ok: Color { Color(palette.ok) }

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
    static func din(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .title)
      -> SwiftUI.Font
    {
      .custom(AppStyle.current.displayFont, size: size, relativeTo: style)
    }
    static func mono(_ style: SwiftUI.Font.TextStyle, _ weight: SwiftUI.Font.Weight = .regular)
      -> SwiftUI.Font
    {
      .system(style, design: .monospaced, weight: weight)
    }
    static func typewriter(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .body)
      -> SwiftUI.Font
    {
      .custom("AmericanTypewriter", size: size, relativeTo: style)
    }
    /// Page title: recipe name, screen heading.
    static var display: SwiftUI.Font { din(34, relativeTo: .title) }
    /// Row and button names.
    static var headline: SwiftUI.Font { din(21, relativeTo: .headline) }
    /// Column headers, tile labels. Always set uppercase.
    static var label: SwiftUI.Font { din(16, relativeTo: .footnote) }
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
  init(_ pair: P) {
    self.init(
      UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(hex: pair.dark) : UIColor(hex: pair.light)
      })
  }
}

extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

// MARK: Styles
// Kept in this file because the Live Activity extension compiles Tokens.swift
// by itself. Hex values mirror docs/design/tokens/*.json (design/check_tokens.py).

/// A light/dark hex pair.
struct P {
  let light: UInt32
  let dark: UInt32
  init(_ light: UInt32, _ dark: UInt32) {
    self.light = light
    self.dark = dark
  }
}

/// Every color role the design system uses, for one style.
struct Palette {
  let bg, paper, steel, onSteel, ink, ink2, line, signal, onSignal, signalOnSteel: P
  let kraft, onKraft, error, ok: P
}

/// The owner's choice of Light, Dark or the system setting.
enum AppearanceMode: String, CaseIterable, Identifiable {
  case system, light, dark

  static let storageKey = "appearanceMode"

  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

/// Five looks that change colors and display fonts only; layout is shared.
/// Palettes come from docs/design/archive/*.swift.txt mapped onto the DS roles.
enum AppStyle: String, CaseIterable, Identifiable {
  case steelKraft, charcoalCrema, quietCeramic, terracotta, lateNightCafe

  static let storageKey = "appStyle"

  /// Read live so `DS` colors and fonts follow the Settings choice.
  static var current: AppStyle {
    UserDefaults.standard.string(forKey: storageKey).flatMap(AppStyle.init) ?? .steelKraft
  }

  var id: String { rawValue }

  var title: String {
    switch self {
    case .steelKraft: "Steel & Kraft"
    case .charcoalCrema: "Charcoal & Crema"
    case .quietCeramic: "Quiet Ceramic"
    case .terracotta: "Terracotta"
    case .lateNightCafe: "Late-Night Café"
    }
  }

  /// PostScript name of the bold display face.
  var displayFont: String {
    switch self {
    case .steelKraft: "DINCondensed-Bold"
    case .charcoalCrema: "Didot-Bold"
    case .quietCeramic: "HiraMinProN-W6"
    case .terracotta: "Cochin-Bold"
    case .lateNightCafe: "BodoniSvtyTwoOSITCTT-Bold"
    }
  }

  var palette: Palette {
    switch self {
    case .steelKraft:
      Palette(
        bg: P(0xD9C4A0, 0x1B1D1F), paper: P(0xEFE6D3, 0x26292C), steel: P(0x2B2F33, 0x30353A),
        onSteel: P(0xE8EAEC, 0xE8EAEC), ink: P(0x1E1E1C, 0xECEAE4), ink2: P(0x4A463E, 0xB4B1A8),
        line: P(0x1E1E1C, 0x8A9096), signal: P(0xC2410C, 0xFF7A3D),
        onSignal: P(0xFFFFFF, 0x1B1D1F), signalOnSteel: P(0xFF7A3D, 0xFF7A3D),
        kraft: P(0xC9AE82, 0xC9AE82), onKraft: P(0x1E1E1C, 0x1E1E1C),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .charcoalCrema:
      Palette(
        bg: P(0xF4ECDF, 0x1B1917), paper: P(0xEADFCC, 0x262320), steel: P(0x2A2622, 0x332E29),
        onSteel: P(0xF2E8D8, 0xF2E8D8), ink: P(0x1F1B18, 0xF2E8D8), ink2: P(0x5C5248, 0xBFB2A0),
        line: P(0x5C5248, 0x8F8372), signal: P(0x8A5A2B, 0xD9B88F),
        onSignal: P(0xF4ECDF, 0x1B1917), signalOnSteel: P(0xD9B88F, 0xD9B88F),
        kraft: P(0xD8C3A0, 0xC9AE82), onKraft: P(0x1F1B18, 0x1F1B18),
        error: P(0xA2331F, 0xF0907D), ok: P(0x2A6A2A, 0x7FD18A))
    case .quietCeramic:
      Palette(
        bg: P(0xF6F1E7, 0x1F1A16), paper: P(0xECE4D3, 0x2A241E), steel: P(0x33403A, 0x2F3A34),
        onSteel: P(0xF6F1E7, 0xEFE7D8), ink: P(0x3B2E25, 0xEFE7D8), ink2: P(0x6B5B4E, 0xB8AC9C),
        line: P(0x6B5B4E, 0x8F8374), signal: P(0x44695A, 0x9DBFAE),
        onSignal: P(0xF6F1E7, 0x1F1A16), signalOnSteel: P(0x9DBFAE, 0x9DBFAE),
        kraft: P(0xD3C8B3, 0xD3C8B3), onKraft: P(0x3B2E25, 0x3B2E25),
        error: P(0x9B3B2A, 0xEE9A86), ok: P(0x2A6A2A, 0x7FD18A))
    case .terracotta:
      Palette(
        bg: P(0xF3E3CF, 0x2A1710), paper: P(0xE8C7A2, 0x3D2318), steel: P(0x4A2515, 0x4A2B1E),
        onSteel: P(0xFFF3E4, 0xF7E6D2), ink: P(0x3A1F14, 0xF7E6D2), ink2: P(0x6B4332, 0xD4B59B),
        line: P(0x6B4332, 0xA88670), signal: P(0x962F14, 0xE58A63),
        onSignal: P(0xFFF3E4, 0x2A1710), signalOnSteel: P(0xF0A07A, 0xF0A07A),
        kraft: P(0xD9B48A, 0xD9B48A), onKraft: P(0x3A1F14, 0x3A1F14),
        error: P(0x9A2A16, 0xFFA58A), ok: P(0x1F5A1F, 0x7FD18A))
    case .lateNightCafe:
      Palette(
        bg: P(0xF2E6CF, 0x17100C), paper: P(0xE7D7B6, 0x241911), steel: P(0x2A1A10, 0x2E2217),
        onSteel: P(0xF1E4CC, 0xF1E4CC), ink: P(0x2A1A10, 0xF1E4CC), ink2: P(0x5E4630, 0xC2AE92),
        line: P(0x5E4630, 0x8F7C62), signal: P(0x8A4B08, 0xF0AE4A),
        onSignal: P(0xF8EEDB, 0x17100C), signalOnSteel: P(0xF0AE4A, 0xF0AE4A),
        kraft: P(0xC9A15B, 0xC9A15B), onKraft: P(0x17100C, 0x17100C),
        error: P(0x9B2A14, 0xFF9F85), ok: P(0x2A6A2A, 0x7FD18A))
    }
  }
}
