import SwiftUI
import UIKit

/// Steel & Kraft design tokens. Hex values mirror docs/design/tokens/*.json
/// (design/check_tokens.py fails if they drift). Light is kraft paper and
/// steel; dark is gunmetal. Names are roles, not colors.
enum DS {
  // MARK: Color

  /// The palette of the style chosen in Settings; read each time so a change shows at once.
  static var palette: Palette { AppStyle.current.palette }
  /// Shape, type and density of that style. Nothing is cached, so a switch shows at once.
  static var flavor: Flavor { AppStyle.current.flavor }

  static var bg: Color { Color(palette.bg) }  // screen: kraft / gunmetal
  static var paper: Color { Color(palette.paper) }  // sheets, tables, tiles
  static var steel: Color { Color(palette.steel) }  // instrument panels, table headers
  static var onSteel: Color { Color(palette.onSteel) }
  static var ink: Color { Color(palette.ink) }  // primary text
  /// Secondary text; Increase Contrast swaps it for primary text.
  static var ink2: Color {
    let p = palette
    return Color(
      UIColor {
        let pair = $0.accessibilityContrast == .high ? p.ink : p.ink2
        return $0.userInterfaceStyle == .dark ? UIColor(hex: pair.dark) : UIColor(hex: pair.light)
      })
  }
  static var line: Color { Color(palette.line) }  // rules and control outlines (3:1 UI)
  static var signal: Color { Color(palette.signal) }  // the one accent
  static var onSignal: Color { Color(palette.onSignal) }
  static var signalOnSteel: Color { Color(palette.signalOnSteel) }  // accent on steel
  static var kraft: Color { Color(palette.kraft) }  // label stock for notes
  static var onKraft: Color { Color(palette.onKraft) }
  static var error: Color { Color(palette.error) }
  static var ok: Color { Color(palette.ok) }

  // MARK: Space (4-pt base, scaled by the flavor's density)

  enum Space {
    private static func scaled(_ value: CGFloat) -> CGFloat {
      (value * DS.flavor.density.factor).rounded()
    }
    static var xs: CGFloat { scaled(4) }
    static var sm: CGFloat { scaled(8) }
    static var md: CGFloat { scaled(12) }
    static var lg: CGFloat { scaled(16) }
    static var xl: CGFloat { scaled(24) }
    static var xxl: CGFloat { scaled(32) }
  }

  /// Minimum touch target and the control heights used on the brew station.
  enum Size {
    static let minTap: CGFloat = 44
    static let control: CGFloat = 48
    static let primary: CGFloat = 60
    static let timerControl: CGFloat = 64
  }

  // MARK: Shape

  /// The flavor's corner radius for panels, tiles and tables.
  static var radius: CGFloat { flavor.radius }
  /// Buttons: the pill flavors round them fully.
  static var controlRadius: CGFloat { flavor.control == .pill ? 999 : flavor.radius }
  static let hairline: CGFloat = 1
  static let rule: CGFloat = 1.5

  // MARK: Type

  enum Font {
    static func din(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .title)
      -> SwiftUI.Font
    {
      DS.flavor.display(size, relativeTo: style)
    }
    static func mono(_ style: SwiftUI.Font.TextStyle, _ weight: SwiftUI.Font.Weight = .regular)
      -> SwiftUI.Font
    {
      DS.flavor.number(style, weight)
    }
    static func typewriter(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle = .body)
      -> SwiftUI.Font
    {
      .custom("AmericanTypewriter", size: size, relativeTo: style)
    }
    /// Page title: recipe name, screen heading.
    static var display: SwiftUI.Font {
      DS.flavor.caps ? din(34, relativeTo: .title) : DS.flavor.display(34, relativeTo: .title)
    }
    /// Row and button names.
    static var headline: SwiftUI.Font {
      DS.flavor.caps ? din(21, relativeTo: .headline) : DS.flavor.display(21, relativeTo: .headline)
    }
    /// Column headers, tile labels. Always set uppercase.
    static var label: SwiftUI.Font {
      DS.flavor.caps ? din(16, relativeTo: .footnote) : .system(.caption, weight: .semibold)
    }
    /// Measured values in tables and lists.
    static var data: SwiftUI.Font { mono(.callout, .bold) }
    /// Measured values in tiles.
    static var dataLarge: SwiftUI.Font { mono(.title, .bold) }
    /// The timer. Capped at xxxLarge by the screen; stays readable at arm's length.
    static var readout: SwiftUI.Font { DS.flavor.readout }
    /// Notes on kraft.
    static var note: SwiftUI.Font { typewriter(15) }
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
  var bg, paper, steel, onSteel, ink, ink2, line, signal, onSignal, signalOnSteel: P
  var kraft, onKraft, error, ok: P
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

/// The flavors. Each is a palette plus a `Flavor` (type, corners, density, control and
/// number style). Palettes are mirrored in docs/design/tokens/<name>.json.
enum AppStyle: String, CaseIterable, Identifiable {
  case daily, bloom
  case steelKraft, charcoalCrema, quietCeramic
  case nightMint, espressoBlack, cafePage, roasterPoster
  /// The three handoff directions (docs/design/handoff): alternative complete systems.
  case sundayStudio, morningEdition, precisionAtelier

  static let storageKey = "appStyle"

  /// Read live so `DS` colors and fonts follow the Settings choice. A removed look falls
  /// back to the default.
  static var current: AppStyle {
    UserDefaults.standard.string(forKey: storageKey).flatMap(AppStyle.init) ?? .sundayStudio
  }

  /// Moves everyone onto Sunday Studio once, the first launch after the redesign ships.
  static func adoptSundayStudioOnce(_ d: UserDefaults = .standard) {
    guard !d.bool(forKey: "style.sundayStudioAdopted") else { return }
    d.set(AppStyle.sundayStudio.rawValue, forKey: storageKey)
    d.set(true, forKey: "style.sundayStudioAdopted")
  }

  /// Moves everyone onto Night Mint once, the first launch after it ships. A launch
  /// argument (UI tests) still wins, because the argument domain is read first.
  static func adoptNightMintOnce(_ d: UserDefaults = .standard) {
    guard !d.bool(forKey: "style.nightMintAdopted") else { return }
    d.set(AppStyle.nightMint.rawValue, forKey: storageKey)
    d.set(true, forKey: "style.nightMintAdopted")
  }

  var id: String { rawValue }

  var title: String {
    switch self {
    case .daily: "Daily"
    case .bloom: "Bloom"
    case .steelKraft: "Steel & Kraft"
    case .charcoalCrema: "Charcoal & Crema"
    case .quietCeramic: "Quiet Ceramic"
    case .nightMint: "Night Mint"
    case .espressoBlack: "Espresso Black"
    case .cafePage: "Café Page"
    case .roasterPoster: "Roaster Poster"
    case .sundayStudio: "Sunday Studio"
    case .morningEdition: "Morning Edition"
    case .precisionAtelier: "Precision Atelier"
    }
  }

  /// One line for the picker tile's accessibility hint.
  var mood: String {
    switch self {
    case .daily: "Clean white cards, serif, one amber"
    case .bloom: "Cream, serif, brew rings"
    case .steelKraft: "Spec sheet, square, one orange"
    case .charcoalCrema: "Ledger, Didot numerals"
    case .quietCeramic: "Calm, airy, celadon"
    case .nightMint: "Calm mint, rounded"
    case .espressoBlack: "True black, high contrast"
    case .cafePage: "Serif headings on paper"
    case .roasterPoster: "Loud stickers with offset shadow"
    case .sundayStudio: "Butter and cobalt, bold rounded type"
    case .morningEdition: "Ivory and terracotta, editorial serif"
    case .precisionAtelier: "Midnight and copper, instrument numerals"
    }
  }

  /// Everything but color that sets a flavor apart.
  var flavor: Flavor {
    switch self {
    case .daily, .bloom:
      Flavor(
        displayDesign: .serif, displayWeight: .regular, radius: 24, density: .airy,
        control: .pill, numbers: .serif, caps: false)
    case .steelKraft:
      Flavor(
        displayFont: "DINCondensed-Bold", radius: 3, density: .regular, control: .square,
        numbers: .monospaced)
    case .charcoalCrema:
      Flavor(
        displayFont: "Didot-Bold", radius: 2, density: .regular, control: .square,
        numbers: .monospaced)
    case .quietCeramic:
      Flavor(
        displayFont: "HiraMinProN-W6", radius: 20, density: .airy, control: .pill,
        numbers: .rounded)
    case .nightMint:
      Flavor(
        bodyDesign: .rounded, displayDesign: .rounded, displayWeight: .semibold, radius: 20,
        density: .airy, control: .pill, numbers: .rounded)
    case .espressoBlack:
      Flavor(
        displayDesign: .default, displayWeight: .semibold, radius: 14, density: .regular,
        control: .pill, numbers: .monospaced)
    case .cafePage:
      Flavor(
        displayDesign: .serif, displayWeight: .semibold, radius: 18, density: .airy,
        control: .square, numbers: .monospaced)
    case .roasterPoster:
      Flavor(
        displayDesign: .rounded, displayWeight: .heavy, radius: 12, density: .regular,
        control: .sticker, numbers: .condensed)
    case .sundayStudio:
      Flavor(
        bodyDesign: .rounded, displayDesign: .rounded, displayWeight: .heavy, radius: 22,
        density: .airy, control: .pill, numbers: .rounded, caps: false, motion: .playful,
        accentReadout: true)
    case .morningEdition:
      Flavor(
        displayDesign: .serif, displayWeight: .medium, radius: 8, density: .airy,
        control: .pill, numbers: .serif, caps: false, motion: .quiet)
    case .precisionAtelier:
      Flavor(
        displayFont: "DINCondensed-Bold", radius: 10, density: .regular, control: .square,
        numbers: .monospaced, motion: .crisp)
    }
  }

  var palette: Palette {
    switch self {
    // The Daily Loop look: warm white ground, white cards, one amber that passes
    // AA with white text in light (5.1:1) and with near-black text in dark.
    case .daily:
      Palette(
        bg: P(0xF7F5F1, 0x0F0F10), paper: P(0xFFFFFF, 0x1C1C1E), steel: P(0x1C1A17, 0x2A2A2D),
        onSteel: P(0xFFFFFF, 0xF2EFEA), ink: P(0x1C1A17, 0xF2EFEA), ink2: P(0x6B645C, 0xA8A39C),
        line: P(0x8C847A, 0x6E6A64), signal: P(0x93591A, 0xE3A75C),
        onSignal: P(0xFFFFFF, 0x1A1208), signalOnSteel: P(0xE3A75C, 0xE3A75C),
        kraft: P(0xF3E9DC, 0x2A2117), onKraft: P(0x1C1A17, 0xF2EFEA),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x55684A, 0xA9BC97))
    case .bloom:
      Palette(
        bg: P(0xF5EFE6, 0x17110D), paper: P(0xFBF8F3, 0x221A14), steel: P(0x2B1D14, 0x2E241C),
        onSteel: P(0xFBF8F3, 0xF3EADF), ink: P(0x2B1D14, 0xF3EADF), ink2: P(0x6E5E52, 0xB8A898),
        line: P(0x8F7C6C, 0x7A6B5E), signal: P(0x9A5222, 0xE0A06A),
        onSignal: P(0xFFFFFF, 0x17110D), signalOnSteel: P(0xE0A06A, 0xE0A06A),
        kraft: P(0xEDE3D6, 0x2E241C), onKraft: P(0x2B1D14, 0xF3EADF),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x55684A, 0xA9BC97))
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
    case .nightMint:
      Palette(
        bg: P(0xF4F8F7, 0x0E1513), paper: P(0xFFFFFF, 0x18211F), steel: P(0x13201D, 0x1F2B28),
        onSteel: P(0xE3EEEB, 0xE3EEEB), ink: P(0x13201D, 0xE3EEEB), ink2: P(0x4F615C, 0x9FB3AE),
        line: P(0x4F615C, 0x9FB3AE), signal: P(0x0F766E, 0x82D5C8),
        onSignal: P(0xFFFFFF, 0x0E1513), signalOnSteel: P(0x82D5C8, 0x82D5C8),
        kraft: P(0xCFE5DF, 0x2A3B37), onKraft: P(0x13201D, 0xE3EEEB),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .espressoBlack:
      Palette(
        bg: P(0xF2F2F7, 0x000000), paper: P(0xFFFFFF, 0x0D0D0D), steel: P(0x1C1C1E, 0x1C1C1E),
        onSteel: P(0xF2F2F7, 0xF2F2F7), ink: P(0x000000, 0xFFFFFF), ink2: P(0x5C5C63, 0x9A9AA1),
        line: P(0x5C5C63, 0x9A9AA1), signal: P(0x2F6B3F, 0x7EE2A0),
        onSignal: P(0xFFFFFF, 0x000000), signalOnSteel: P(0x7EE2A0, 0x7EE2A0),
        kraft: P(0xE4E4EA, 0x1F1F22), onKraft: P(0x000000, 0xFFFFFF),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .cafePage:
      Palette(
        bg: P(0xFBF8F3, 0x1A1816), paper: P(0xF3EEE6, 0x24211E), steel: P(0x2E2A33, 0x2F2B33),
        onSteel: P(0xF3EEE6, 0xEDE7DD), ink: P(0x22201C, 0xEDE7DD), ink2: P(0x625C52, 0xABA396),
        line: P(0x625C52, 0xABA396), signal: P(0x7A4A8C, 0xD6B3E3),
        onSignal: P(0xFFFFFF, 0x1A1816), signalOnSteel: P(0xD6B3E3, 0xD6B3E3),
        kraft: P(0xE6DAEC, 0x3A3140), onKraft: P(0x22201C, 0xEDE7DD),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .roasterPoster:
      Palette(
        bg: P(0xFFFFFF, 0x121413), paper: P(0xF1F7F2, 0x1C201D), steel: P(0x0B0B0B, 0x1C201D),
        onSteel: P(0xF2F5F2, 0xF2F5F2), ink: P(0x0B0B0B, 0xF2F5F2), ink2: P(0x4A4F4B, 0xA7AFA9),
        line: P(0x0B0B0B, 0xF2F5F2), signal: P(0x1E7A3E, 0x8FF0A4),
        onSignal: P(0xFFFFFF, 0x0B0B0B), signalOnSteel: P(0x8FF0A4, 0x8FF0A4),
        kraft: P(0xD9F2DF, 0x233326), onKraft: P(0x0B0B0B, 0xF2F5F2),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .sundayStudio:
      Palette(
        bg: P(0xFFFDF3, 0x0E1230), paper: P(0xFFFFFF, 0x171D45), steel: P(0x1B2F7A, 0x2448C8),
        onSteel: P(0xFFFDF3, 0xFFFDF3), ink: P(0x2B1A12, 0xFFFDF3), ink2: P(0x625046, 0xC9CCE6),
        line: P(0x8A7A6E, 0x7B82B8), signal: P(0x2448C8, 0xF5E8A4),
        onSignal: P(0xFFFFFF, 0x2B1A12), signalOnSteel: P(0xF5E8A4, 0xF5E8A4),
        kraft: P(0xF5E8A4, 0x1E3A9E), onKraft: P(0x2B1A12, 0xFFFDF3),
        error: P(0x9A1B0A, 0xFFA08C), ok: P(0x2A6A2A, 0x9FE0A8))
    case .morningEdition:
      Palette(
        bg: P(0xF4EFE4, 0x1C1713), paper: P(0xFBF8F1, 0x27201A), steel: P(0x302820, 0x302820),
        onSteel: P(0xF4EFE4, 0xF4EFE4), ink: P(0x302820, 0xF4EFE4), ink2: P(0x675A4D, 0xBFB2A4),
        line: P(0x8E7E6E, 0x7E7064), signal: P(0xA9472F, 0xE08A6E),
        onSignal: P(0xFFFFFF, 0x1C1713), signalOnSteel: P(0xE8A085, 0xE8A085),
        kraft: P(0xEADFCB, 0x332A22), onKraft: P(0x302820, 0xF4EFE4),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x55684A, 0xA9BC97))
    case .precisionAtelier:
      Palette(
        bg: P(0xF5EBD7, 0x101B24), paper: P(0xFBF4E6, 0x18242E), steel: P(0x101B24, 0x1F2D38),
        onSteel: P(0xF5EBD7, 0xF5EBD7), ink: P(0x101B24, 0xF5EBD7), ink2: P(0x4F5962, 0xB5BCC2),
        line: P(0x7A8089, 0x6E7A85), signal: P(0x9A5A22, 0xDB9154),
        onSignal: P(0xFFFFFF, 0x101B24), signalOnSteel: P(0xDB9154, 0xDB9154),
        kraft: P(0xE6D9C0, 0x1F2D38), onKraft: P(0x101B24, 0xF5EBD7),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    }
  }
}

// MARK: Flavor

enum Density: String, CaseIterable, Identifiable {
  case compact, regular, airy
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var factor: CGFloat {
    switch self {
    case .compact: 0.8
    case .regular: 1
    case .airy: 1.2
    }
  }
}

/// How buttons and panels are drawn: hard-cornered, fully rounded, or a bordered
/// sticker with a hard offset shadow in the accent.
enum ControlStyle { case square, pill, sticker }

/// How measured values are set.
enum NumberStyle { case monospaced, rounded, condensed, serif }

/// The personality of a flavor's movement. Reduce Motion overrides all three.
enum MotionStyle {
  /// Soft fades and small moves.
  case quiet
  /// Short, instrument-like.
  case crisp
  /// A little spring on secondary feedback; the timer and the instruction never bounce.
  case playful

  /// A state change on screen (a step card, a kicker, a check).
  var transition: Animation {
    switch self {
    case .quiet: .easeInOut(duration: 0.3)
    case .crisp: .easeOut(duration: 0.18)
    case .playful: .spring(response: 0.35, dampingFraction: 0.72)
    }
  }
  /// Text and instructions: never a bounce.
  var text: Animation {
    switch self {
    case .quiet: .easeInOut(duration: 0.3)
    case .crisp: .easeOut(duration: 0.18)
    case .playful: .easeOut(duration: 0.25)
    }
  }
}

struct Flavor {
  var bodyDesign: SwiftUI.Font.Design?
  /// PostScript name of the display face; nil sets display text in the system font.
  var displayFont: String?
  var displayDesign: SwiftUI.Font.Design = .default
  var displayWeight: SwiftUI.Font.Weight = .bold
  var radius: CGFloat
  var density: Density
  var control: ControlStyle
  var numbers: NumberStyle
  /// Display text in capitals (spec-sheet flavors) or as written (Bloom).
  var caps = true
  var motion: MotionStyle = .quiet
  /// The brew timer's digits in the accent (Sunday Studio) rather than ink.
  var accentReadout = false

  /// Display text. A named face scales from `size`; the system face uses the text style.
  func display(_ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
    if let displayFont { return .custom(displayFont, size: size, relativeTo: style) }
    return .system(style, design: displayDesign, weight: displayWeight)
  }

  func number(_ style: SwiftUI.Font.TextStyle, _ weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
    switch numbers {
    case .monospaced: .system(style, design: .monospaced, weight: weight)
    case .serif:
      .system(style, design: .serif, weight: weight == .bold ? .semibold : weight)
        .monospacedDigit()
    case .rounded: .system(style, design: .rounded, weight: weight).monospacedDigit()
    case .condensed:
      .custom(
        "DINCondensed-Bold", size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize * 1.15,
        relativeTo: style)
    }
  }

  /// The brew timer's elapsed time: big, with room beside it for remaining and total.
  var timerReadout: SwiftUI.Font {
    switch numbers {
    case .monospaced: .system(size: 72, weight: .bold, design: .monospaced)
    case .serif: .system(size: 80, weight: .medium, design: .serif).monospacedDigit()
    case .rounded: .system(size: 84, weight: .heavy, design: .rounded).monospacedDigit()
    case .condensed: .custom("DINCondensed-Bold", size: 88)
    }
  }

  var readout: SwiftUI.Font {
    switch numbers {
    case .monospaced: .system(size: 104, weight: .bold, design: .monospaced)
    case .serif: .system(size: 96, weight: .regular, design: .serif).monospacedDigit()
    case .rounded: .system(size: 104, weight: .bold, design: .rounded).monospacedDigit()
    case .condensed: .custom("DINCondensed-Bold", size: 120)
    }
  }
}

extension String {
  /// A title as the flavor sets it: capitals for spec-sheet flavors, as written for Bloom.
  var dsTitle: String { DS.flavor.caps ? uppercased() : self }
}

extension SwiftUI.Font.TextStyle {
  fileprivate var uiKit: UIFont.TextStyle {
    switch self {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    default: .body
    }
  }
}

private struct FlavorKey: EnvironmentKey {
  static var defaultValue: Flavor { AppStyle.current.flavor }
}

extension EnvironmentValues {
  /// The chosen flavor, set once at the app root.
  var flavor: Flavor {
    get { self[FlavorKey.self] }
    set { self[FlavorKey.self] = newValue }
  }
}
