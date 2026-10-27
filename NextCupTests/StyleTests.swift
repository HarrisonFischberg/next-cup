import Foundation
import Testing
import UIKit

@testable import NextCup

@Suite("Appearance and style", .serialized)
struct StyleTests {
  private func luminance(_ hex: UInt32) -> Double {
    func channel(_ shift: UInt32) -> Double {
      let v = Double((hex >> shift) & 0xFF) / 255
      return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
  }

  private func ratio(_ a: UInt32, _ b: UInt32) -> Double {
    let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
    return (hi + 0.05) / (lo + 0.05)
  }

  /// The same pairs as docs/design/tokens/tokens.light.json: (foreground, background, needed ratio).
  private func pairs(_ p: Palette) -> [(String, P, P, Double)] {
    [
      ("ink/bg", p.ink, p.bg, 4.5), ("ink2/bg", p.ink2, p.bg, 4.5),
      ("ink/paper", p.ink, p.paper, 4.5), ("ink2/paper", p.ink2, p.paper, 4.5),
      ("onSteel/steel", p.onSteel, p.steel, 4.5),
      ("signalOnSteel/steel", p.signalOnSteel, p.steel, 4.5),
      ("onSignal/signal", p.onSignal, p.signal, 4.5), ("onKraft/kraft", p.onKraft, p.kraft, 4.5),
      ("error/bg", p.error, p.bg, 4.5), ("error/paper", p.error, p.paper, 4.5),
      ("ok/paper", p.ok, p.paper, 4.5),
      ("line/bg", p.line, p.bg, 3), ("line/paper", p.line, p.paper, 3),
      ("signal/bg", p.signal, p.bg, 3),
    ]
  }

  @Test(arguments: AppStyle.allCases)
  func everyPairPassesAA(style: AppStyle) {
    for (name, fg, bg, need) in pairs(style.palette) {
      #expect(ratio(fg.light, bg.light) >= need, "\(style.title) light \(name)")
      #expect(ratio(fg.dark, bg.dark) >= need, "\(style.title) dark \(name)")
    }
  }

  @Test(arguments: AppStyle.allCases)
  func namedFontsAreInstalled(style: AppStyle) {
    let condensed = style.flavor.numbers == .condensed ? "DINCondensed-Bold" : nil
    for name in [style.flavor.displayFont, condensed].compactMap({ $0 }) {
      #expect(UIFont(name: name, size: 20) != nil, "\(name)")
    }
  }

  @Test func twelveFlavorsWithoutTheRemovedOnes() {
    #expect(AppStyle.allCases.count == 12)
    #expect(Set(AppStyle.allCases.map(\.title)).count == 12)
    for removed in ["terracotta", "lateNightCafe", "makeItYours"] {
      #expect(AppStyle(rawValue: removed) == nil)
    }
  }

  @Test func everyoneMovesToNightMintOnceThenKeepsTheirChoice() {
    let d = UserDefaults(suiteName: "mint.\(UUID().uuidString)")!
    d.set(AppStyle.bloom.rawValue, forKey: AppStyle.storageKey)
    AppStyle.adoptNightMintOnce(d)
    #expect(d.string(forKey: AppStyle.storageKey) == AppStyle.nightMint.rawValue)
    d.set(AppStyle.daily.rawValue, forKey: AppStyle.storageKey)
    AppStyle.adoptNightMintOnce(d)
    #expect(d.string(forKey: AppStyle.storageKey) == AppStyle.daily.rawValue)
  }

  @Test func everyoneMovesToSundayStudioOnceThenKeepsTheirChoice() {
    let d = UserDefaults(suiteName: "sunday.\(UUID().uuidString)")!
    d.set(AppStyle.nightMint.rawValue, forKey: AppStyle.storageKey)
    AppStyle.adoptSundayStudioOnce(d)
    #expect(d.string(forKey: AppStyle.storageKey) == AppStyle.sundayStudio.rawValue)
    d.set(AppStyle.morningEdition.rawValue, forKey: AppStyle.storageKey)
    AppStyle.adoptSundayStudioOnce(d)
    #expect(d.string(forKey: AppStyle.storageKey) == AppStyle.morningEdition.rawValue)
  }

  @Test func handoffDirectionsKeepTheirOwnPersonalities() {
    #expect(AppStyle.sundayStudio.flavor.motion == .playful)
    #expect(AppStyle.sundayStudio.flavor.control == .pill && !AppStyle.sundayStudio.flavor.caps)
    #expect(AppStyle.morningEdition.flavor.motion == .quiet)
    #expect(AppStyle.morningEdition.flavor.displayDesign == .serif)
    #expect(AppStyle.precisionAtelier.flavor.motion == .crisp)
    #expect(AppStyle.precisionAtelier.flavor.control == .square)
  }

  @Test func defaultFlavorKeepsTheOriginalShape() {
    let steel = AppStyle.steelKraft.flavor
    #expect(steel.radius == 3 && steel.density == .regular && steel.control == .square)
    #expect(steel.displayFont == "DINCondensed-Bold" && steel.numbers == .monospaced)
  }

  @Test func flavorsDifferInShapeAndControl() {
    #expect(AppStyle.roasterPoster.flavor.control == .sticker)
    #expect(AppStyle.nightMint.flavor.control == .pill)
    #expect(AppStyle.nightMint.flavor.density == .airy)
    #expect(AppStyle.cafePage.flavor.displayDesign == .serif)
    #expect(AppStyle.espressoBlack.palette.bg.dark == 0x000000)
  }

  @Test func switchingFlavorChangesColorsSpaceAndShapeAtOnce() {
    let defaults = UserDefaults.standard
    let saved = defaults.object(forKey: AppStyle.storageKey)
    defer { defaults.set(saved, forKey: AppStyle.storageKey) }

    defaults.set(AppStyle.steelKraft.rawValue, forKey: AppStyle.storageKey)
    let (steelSpace, steelRadius) = (DS.Space.lg, DS.radius)
    defaults.set(AppStyle.nightMint.rawValue, forKey: AppStyle.storageKey)
    #expect(DS.palette.bg.dark == 0x0E1513)
    #expect(DS.Space.lg > steelSpace && DS.radius > steelRadius)
  }

  @Test func choicePersistsAndDrivesTokens() {
    let defaults = UserDefaults.standard
    let saved = defaults.object(forKey: AppStyle.storageKey)
    defer { defaults.set(saved, forKey: AppStyle.storageKey) }

    defaults.removeObject(forKey: AppStyle.storageKey)
    #expect(AppStyle.current == .sundayStudio)

    defaults.set(AppStyle.cafePage.rawValue, forKey: AppStyle.storageKey)
    #expect(AppStyle.current == .cafePage)
    #expect(DS.palette.bg.light == AppStyle.cafePage.palette.bg.light)

    defaults.set("terracotta", forKey: AppStyle.storageKey)
    #expect(AppStyle.current == .sundayStudio, "a removed look falls back to Sunday Studio")
  }

  @Test func appearanceModesMapToColorSchemes() {
    #expect(AppearanceMode.system.colorScheme == nil)
    #expect(AppearanceMode.light.colorScheme == .light)
    #expect(AppearanceMode.dark.colorScheme == .dark)
  }
}
