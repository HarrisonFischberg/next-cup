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
    /// Display text for flavors that set it as written: the named face, else the system face.
    private static func asWritten(_ size: CGFloat, _ style: SwiftUI.Font.TextStyle)
      -> SwiftUI.Font
    {
      let f = DS.flavor
      if let name = f.displayFont { return .custom(name, size: size, relativeTo: style) }
      return .system(style, design: f.displayDesign, weight: f.displayWeight)
    }
    /// Page title: recipe name, screen heading.
    static var display: SwiftUI.Font {
      DS.flavor.caps ? din(34, relativeTo: .title) : asWritten(34, .largeTitle)
    }
    /// Row and button names.
    static var headline: SwiftUI.Font {
      DS.flavor.caps ? din(21, relativeTo: .headline) : asWritten(20, .title3)
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

/// Twenty flavors; the ten Glass looks put their controls on Liquid Glass. Each is a palette plus a `Flavor` (type, corners, density, control and
/// number style). Palettes are mirrored in docs/design/tokens/<name>.json.
enum AppStyle: String, CaseIterable, Identifiable {
  case bloom
  case steelKraft, charcoalCrema, quietCeramic, terracotta, lateNightCafe
  case nightMint, espressoBlack, cafePage, roasterPoster
  case cremaGlass, pourOver, matchaGlass, midnightRoast, nordicMorning
  case clayGlass, auroraRoast, bentoBar, coldBrew, editorialCafe
  case makeItYours

  static let storageKey = "appStyle"

  /// Read live so `DS` colors and fonts follow the Settings choice.
  static var current: AppStyle {
    UserDefaults.standard.string(forKey: storageKey).flatMap(AppStyle.init) ?? .bloom
  }

  /// Moves everyone onto Bloom once, the first launch after it ships. A launch
  /// argument (UI tests) still wins, because the argument domain is read first.
  static func adoptBloomOnce(_ d: UserDefaults = .standard) {
    guard !d.bool(forKey: "style.bloomAdopted") else { return }
    d.set(AppStyle.bloom.rawValue, forKey: storageKey)
    d.set(true, forKey: "style.bloomAdopted")
  }

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bloom: "Bloom"
    case .steelKraft: "Steel & Kraft"
    case .charcoalCrema: "Charcoal & Crema"
    case .quietCeramic: "Quiet Ceramic"
    case .terracotta: "Terracotta"
    case .lateNightCafe: "Late-Night Café"
    case .nightMint: "Night Mint"
    case .espressoBlack: "Espresso Black"
    case .cafePage: "Café Page"
    case .roasterPoster: "Roaster Poster"
    case .cremaGlass: "Crema Glass"
    case .pourOver: "Pour Over"
    case .matchaGlass: "Matcha Glass"
    case .midnightRoast: "Midnight Roast"
    case .nordicMorning: "Nordic Morning"
    case .clayGlass: "Clay Glass"
    case .auroraRoast: "Aurora Roast"
    case .bentoBar: "Bento Bar"
    case .coldBrew: "Cold Brew"
    case .editorialCafe: "Editorial Café"
    case .makeItYours: "Make It Yours"
    }
  }

  /// One line for the picker tile's accessibility hint.
  var mood: String {
    switch self {
    case .bloom: "Cream, serif, brew rings"
    case .steelKraft: "Spec sheet, square, one orange"
    case .charcoalCrema: "Ledger, Didot numerals"
    case .quietCeramic: "Calm, airy, celadon"
    case .terracotta: "Warm clay, chunky chips"
    case .lateNightCafe: "Amber menu card"
    case .nightMint: "Calm mint, rounded"
    case .espressoBlack: "True black, high contrast"
    case .cafePage: "Serif headings on paper"
    case .roasterPoster: "Loud stickers with offset shadow"
    case .cremaGlass: "Cream rings, caramel glass"
    case .pourOver: "Bare white, clear glass"
    case .matchaGlass: "Sage, rounded, green glass"
    case .midnightRoast: "True black, amber glass"
    case .nordicMorning: "Cool grid, blue glass"
    case .clayGlass: "Warm clay, Cochin, clay glass"
    case .auroraRoast: "Plum and peach, serif"
    case .bentoBar: "Tiles, heavy type, mustard"
    case .coldBrew: "Ice blue, mono numbers"
    case .editorialCafe: "Didot, red, clear glass"
    case .makeItYours: "Your accent, corners and type"
    }
  }

  /// Everything but color that sets a flavor apart.
  var flavor: Flavor {
    switch self {
    case .bloom:
      Flavor(
        displayDesign: .serif, displayWeight: .regular, radius: 24, density: .airy,
        control: .pill, numbers: .serif, caps: false, rings: true)
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
    case .terracotta:
      Flavor(
        bodyDesign: .rounded, displayFont: "Cochin-Bold", radius: 18, density: .regular,
        control: .pill, numbers: .rounded)
    case .lateNightCafe:
      Flavor(
        displayFont: "BodoniSvtyTwoOSITCTT-Bold", radius: 4, density: .airy, control: .square,
        numbers: .monospaced)
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
    case .cremaGlass:
      Flavor(
        displayDesign: .serif, displayWeight: .regular, radius: 26, density: .airy,
        control: .pill, numbers: .serif, caps: false, glass: .regular, rings: true)
    case .pourOver:
      Flavor(
        displayWeight: .light, radius: 22, density: .airy, control: .pill, numbers: .rounded,
        caps: false, glass: .clear, rings: true)
    case .matchaGlass:
      Flavor(
        bodyDesign: .rounded, displayDesign: .rounded, displayWeight: .semibold, radius: 24,
        density: .airy, control: .pill, numbers: .rounded, caps: false, glass: .regular,
        rings: true)
    case .midnightRoast:
      Flavor(
        displayWeight: .bold, radius: 28, density: .regular, control: .pill, numbers: .rounded,
        caps: false, glass: .regular, rings: true)
    case .nordicMorning:
      Flavor(
        displayWeight: .semibold, radius: 12, density: .regular, control: .square,
        numbers: .monospaced, glass: .regular)
    case .clayGlass:
      Flavor(
        bodyDesign: .rounded, displayFont: "Cochin-Bold", radius: 22, density: .regular,
        control: .pill, numbers: .rounded, caps: false, glass: .regular, rings: true)
    case .auroraRoast:
      Flavor(
        displayDesign: .serif, displayWeight: .semibold, radius: 24, density: .airy,
        control: .pill, numbers: .serif, caps: false, glass: .regular, rings: true)
    case .bentoBar:
      Flavor(
        displayDesign: .rounded, displayWeight: .heavy, radius: 20, density: .compact,
        control: .pill, numbers: .rounded, caps: false, glass: .regular, rings: true)
    case .coldBrew:
      Flavor(
        displayWeight: .semibold, radius: 18, density: .regular, control: .pill,
        numbers: .monospaced, glass: .clear)
    case .editorialCafe:
      Flavor(
        displayFont: "Didot-Bold", radius: 6, density: .regular, control: .square,
        numbers: .serif, caps: false, glass: .clear)
    case .makeItYours: MakeItYours.current.flavor
    }
  }

  var palette: Palette {
    self == .makeItYours ? MakeItYours.current.accent.applied(to: basePalette) : basePalette
  }

  private var basePalette: Palette {
    switch self {
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
    case .cremaGlass:
      Palette(
        bg: P(0xF4EDE3, 0x16100C), paper: P(0xFBF7F1, 0x211913), steel: P(0x3A281C, 0x2E241C),
        onSteel: P(0xFBF7F1, 0xF3EADF), ink: P(0x2A1C13, 0xF3EADF), ink2: P(0x6A5A4E, 0xB8A898),
        line: P(0x8C7868, 0x7A6B5E), signal: P(0xA0561F, 0xE5A46B), onSignal: P(0xFFFFFF, 0x16100C),
        signalOnSteel: P(0xE5A46B, 0xE5A46B), kraft: P(0xEFE4D6, 0x2E241C),
        onKraft: P(0x2A1C13, 0xF3EADF),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x4F6645, 0xA9BC97))
    case .pourOver:
      Palette(
        bg: P(0xFAFAF8, 0x0B0B0B), paper: P(0xFFFFFF, 0x161616), steel: P(0x141414, 0x202020),
        onSteel: P(0xF5F5F5, 0xF5F5F5), ink: P(0x111111, 0xF5F5F3), ink2: P(0x5A5A5A, 0xA3A3A3),
        line: P(0x7A7A7A, 0x7A7A7A), signal: P(0xA2481B, 0xF08A5D), onSignal: P(0xFFFFFF, 0x0B0B0B),
        signalOnSteel: P(0xF08A5D, 0xF08A5D), kraft: P(0xF0EEEA, 0x242424),
        onKraft: P(0x111111, 0xF5F5F3),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2F6B3F, 0x7FD18A))
    case .matchaGlass:
      Palette(
        bg: P(0xEEF2E8, 0x111611), paper: P(0xF8FAF4, 0x1A211A), steel: P(0x26352A, 0x24302A),
        onSteel: P(0xF1F5EC, 0xE6EEE2), ink: P(0x1F2A20, 0xE6EEE2), ink2: P(0x526253, 0xA6B5A5),
        line: P(0x6F806F, 0x7E907E), signal: P(0x46693E, 0xA6CE95), onSignal: P(0xFFFFFF, 0x111611),
        signalOnSteel: P(0xA6CE95, 0xA6CE95), kraft: P(0xDFE8D4, 0x2A3A2C),
        onKraft: P(0x1F2A20, 0xE6EEE2),
        error: P(0x9A2A16, 0xFF9F85), ok: P(0x2F6B3F, 0x8FD39A))
    case .midnightRoast:
      Palette(
        bg: P(0xF3EEE7, 0x000000), paper: P(0xFFFFFF, 0x0F0D0B), steel: P(0x1C1714, 0x1C1916),
        onSteel: P(0xF3EEE7, 0xF3EEE7), ink: P(0x1A1410, 0xF4EEE6), ink2: P(0x5F554C, 0xA89E94),
        line: P(0x85796E, 0x6E655C), signal: P(0x8F4E0A, 0xF6B04D), onSignal: P(0xFFFFFF, 0x000000),
        signalOnSteel: P(0xF6B04D, 0xF6B04D), kraft: P(0xEDE4D8, 0x221D18),
        onKraft: P(0x1A1410, 0xF4EEE6),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2F6B3F, 0x7FD18A))
    case .nordicMorning:
      Palette(
        bg: P(0xEEF1F4, 0x12161B), paper: P(0xFFFFFF, 0x1B2026), steel: P(0x1F2933, 0x26303A),
        onSteel: P(0xEEF1F4, 0xE8ECF0), ink: P(0x141A21, 0xE8ECF0), ink2: P(0x525E6B, 0xA0ACB8),
        line: P(0x6B7785, 0x7D8996), signal: P(0x1F5FA8, 0x8CB8F0), onSignal: P(0xFFFFFF, 0x12161B),
        signalOnSteel: P(0x8CB8F0, 0x8CB8F0), kraft: P(0xE1E7EE, 0x27303A),
        onKraft: P(0x141A21, 0xE8ECF0),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .clayGlass:
      Palette(
        bg: P(0xF6EADC, 0x1F130E), paper: P(0xFDF6EE, 0x2B1B14), steel: P(0x4A2515, 0x43271B),
        onSteel: P(0xFFF3E4, 0xF7E6D2), ink: P(0x3A1F14, 0xF7E6D2), ink2: P(0x6B4332, 0xCFB29A),
        line: P(0x8E6A58, 0x9C7D69), signal: P(0xA33A1B, 0xEE9572), onSignal: P(0xFFFFFF, 0x1F130E),
        signalOnSteel: P(0xF0A07A, 0xF0A07A), kraft: P(0xEFD9C2, 0x3A251B),
        onKraft: P(0x3A1F14, 0xF7E6D2),
        error: P(0x9A2A16, 0xFFA58A), ok: P(0x3E5E2E, 0x9CCB8A))
    case .auroraRoast:
      Palette(
        bg: P(0xF5EEF1, 0x150F15), paper: P(0xFDF9FB, 0x201820), steel: P(0x2E1F2E, 0x2D222D),
        onSteel: P(0xF8F0F4, 0xF1E6EE), ink: P(0x251A25, 0xF1E6EE), ink2: P(0x63536A, 0xB6A6B8),
        line: P(0x85738A, 0x837187), signal: P(0x8A3F6E, 0xF4B08F), onSignal: P(0xFFFFFF, 0x150F15),
        signalOnSteel: P(0xF4B08F, 0xF4B08F), kraft: P(0xF1E2EA, 0x32253A),
        onKraft: P(0x251A25, 0xF1E6EE),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2F6B3F, 0x7FD18A))
    case .bentoBar:
      Palette(
        bg: P(0xEFEEEA, 0x0E0E0D), paper: P(0xFFFFFF, 0x1A1A18), steel: P(0x1C1C1A, 0x24241F),
        onSteel: P(0xF4F3EE, 0xF4F3EE), ink: P(0x151513, 0xF4F3EE), ink2: P(0x57564F, 0xA5A49B),
        line: P(0x76756C, 0x7C7B72), signal: P(0x7A5C00, 0xE8C547), onSignal: P(0xFFFFFF, 0x0E0E0D),
        signalOnSteel: P(0xE8C547, 0xE8C547), kraft: P(0xF3EBC9, 0x2B2818),
        onKraft: P(0x151513, 0xF4F3EE),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2F6B3F, 0x7FD18A))
    case .coldBrew:
      Palette(
        bg: P(0xE9F0F3, 0x0C1418), paper: P(0xF7FBFC, 0x152027), steel: P(0x17303A, 0x1C2E36),
        onSteel: P(0xEAF3F6, 0xE3EEF2), ink: P(0x102027, 0xE3EEF2), ink2: P(0x4C626C, 0x9BB2BC),
        line: P(0x66808B, 0x76909B), signal: P(0x19647E, 0x7FCBE6), onSignal: P(0xFFFFFF, 0x0C1418),
        signalOnSteel: P(0x7FCBE6, 0x7FCBE6), kraft: P(0xD9E8EE, 0x1F3640),
        onKraft: P(0x102027, 0xE3EEF2),
        error: P(0x9A1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))
    case .editorialCafe:
      Palette(
        bg: P(0xF7F4EE, 0x121110), paper: P(0xFFFFFF, 0x1C1A18), steel: P(0x1A1816, 0x262320),
        onSteel: P(0xF7F4EE, 0xF2EEE7), ink: P(0x141210, 0xF2EEE7), ink2: P(0x5A554E, 0xA9A39A),
        line: P(0x7B756D, 0x7F786F), signal: P(0xB0261C, 0xFF8A7A), onSignal: P(0xFFFFFF, 0x121110),
        signalOnSteel: P(0xFF8A7A, 0xFF8A7A), kraft: P(0xEFE9DE, 0x2A2622),
        onKraft: P(0x141210, 0xF2EEE7),
        error: P(0x8F1B0A, 0xFF9C85), ok: P(0x2A6A2A, 0x7FD18A))

    case .makeItYours:
      Palette(
        bg: P(0xF7F6F4, 0x111111), paper: P(0xFFFFFF, 0x1C1C1E), steel: P(0x1A1A1A, 0x2C2C2E),
        onSteel: P(0xF2F2F2, 0xF2F2F2), ink: P(0x1A1A1A, 0xF2F2F2), ink2: P(0x5E5E5E, 0xA0A0A5),
        line: P(0x5E5E5E, 0xA0A0A5), signal: P(0xB4531F, 0xF0915A),
        onSignal: P(0xFFFFFF, 0x111111), signalOnSteel: P(0xF0915A, 0xF0915A),
        kraft: P(0xECE7DF, 0x2A2724), onKraft: P(0x1A1A1A, 0xF2F2F2),
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

/// Which Liquid Glass the buttons sit on: tinted regular glass, or nearly invisible clear glass.
enum GlassKind { case regular, clear }

/// How measured values are set.
enum NumberStyle { case monospaced, rounded, condensed, serif }

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
  /// Buttons on Liquid Glass; content stays on solid paper. Nil draws them solid.
  var glass: GlassKind?
  /// Bloom's layout: rings and quiet headers instead of steel panels.
  var rings = false

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

// MARK: Make It Yours

/// An accent that passes AA on both grounds (docs/design/tokens/makeItYours.json).
struct Swatch: Identifiable {
  let id: String
  let light: UInt32
  let dark: UInt32

  static let all = [
    Swatch(id: "cherry", light: 0xB3202F, dark: 0xFF8A93),
    Swatch(id: "honey", light: 0x8A5A00, dark: 0xF2B84B),
    Swatch(id: "roast", light: 0xB4531F, dark: 0xF0915A),
    Swatch(id: "sage", light: 0x3F6B4A, dark: 0x9CCBA6),
    Swatch(id: "slate", light: 0x475A73, dark: 0xA9BCD6),
    Swatch(id: "blueberry", light: 0x4B4FA8, dark: 0xA8ACF0),
    Swatch(id: "crema", light: 0x7A5C3A, dark: 0xE0C097),
    Swatch(id: "matcha", light: 0x4C6B1F, dark: 0xB5D86B),
  ]

  var title: String { id.capitalized }

  /// The accent replaces `signal`; `signalOnSteel` takes the dark value on either steel.
  func applied(to p: Palette) -> Palette {
    var out = p
    out.signal = P(light, dark)
    out.signalOnSteel = P(dark, dark)
    return out
  }
}

enum Corners: String, CaseIterable, Identifiable {
  case square, soft, round
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var radius: CGFloat {
    switch self {
    case .square: 2
    case .soft: 12
    case .round: 24
    }
  }
}

enum FontChoice: String, CaseIterable, Identifiable {
  case standard, rounded, serif, mono
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var design: SwiftUI.Font.Design {
    switch self {
    case .standard: .default
    case .rounded: .rounded
    case .serif: .serif
    case .mono: .monospaced
    }
  }
}

/// The four settings of the Make It Yours flavor, kept in UserDefaults.
struct MakeItYours {
  static let accentKey = "mine.accent"
  static let cornersKey = "mine.corners"
  static let densityKey = "mine.density"
  static let fontKey = "mine.font"

  var accent: Swatch
  var corners: Corners
  var density: Density
  var font: FontChoice

  var flavor: Flavor {
    Flavor(
      bodyDesign: font == .standard ? nil : font.design, displayDesign: font.design,
      displayWeight: .semibold, radius: corners.radius, density: density,
      control: corners == .round ? .pill : .square, numbers: .monospaced)
  }

  static var current: MakeItYours {
    let d = UserDefaults.standard
    return MakeItYours(
      accent: Swatch.all.first { $0.id == d.string(forKey: accentKey) } ?? Swatch.all[2],
      corners: d.string(forKey: cornersKey).flatMap(Corners.init) ?? .soft,
      density: d.string(forKey: densityKey).flatMap(Density.init) ?? .regular,
      font: d.string(forKey: fontKey).flatMap(FontChoice.init) ?? .standard)
  }
}
