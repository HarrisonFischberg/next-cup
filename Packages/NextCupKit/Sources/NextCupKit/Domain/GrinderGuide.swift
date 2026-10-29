import Foundation

/// Starting grind ranges for popular grinders, per brew method, in each grinder's own
/// notation. Source: Honest Coffee Guide's per-grinder tables (each entry links its page),
/// read 2026-10-26; spot-checked against Fellow's Ode Gen 2 guide (pour over around 5)
/// and Comandante's 24-click factory filter setting. Starting points only: units, burrs
/// and beans differ, so the user dials in from here by taste. `espresso` is nil where the
/// maker sells the grinder for brewed coffee only.
public struct GrinderGuide: Identifiable, Hashable, Sendable {
  public enum Method: Sendable { case pourOver, aeroPress, frenchPress, moka, espresso, coldBrew }

  public let name: String
  /// "Hand" or "Electric".
  public let kind: String
  /// How the dial reads: clicks, dial, rotations, rotation.number.tick, number.click.
  public let notation: String
  public let pourOver: String?
  public let aeroPress: String?
  public let frenchPress: String?
  public let moka: String?
  public let espresso: String?
  public let coldBrew: String?
  public let source: String
  public var id: String { name }

  public func range(for method: Method) -> String? {
    switch method {
    case .pourOver: pourOver
    case .aeroPress: aeroPress
    case .frenchPress: frenchPress
    case .moka: moka
    case .espresso: espresso
    case .coldBrew: coldBrew
    }
  }

  /// One setting to start at: the middle of the range when both ends are plain numbers
  /// (whole numbers stay whole), otherwise the finer end, which is the safer first try.
  public func recommended(for method: Method) -> String? {
    guard let range = range(for: method) else { return nil }
    let ends = range.components(separatedBy: "–").map { $0.trimmingCharacters(in: .whitespaces) }
    guard ends.count == 2 else { return range }
    guard let low = Double(ends[0]), let high = Double(ends[1]),
      ends[0].filter({ $0 == "." }).count < 2
    else { return ends[0] }
    let middle = (low + high) / 2
    if !ends[0].contains("."), !ends[1].contains(".") { return String(Int(middle.rounded())) }
    let decimals = max(ends[0].split(separator: ".").last?.count ?? 1, 1)
    return String(format: "%.\(min(decimals, 2))f", middle)
  }

  /// Words for the notation, said after a range: "15 – 25 clicks".
  public var unitLabel: String {
    switch notation {
    case "clicks": "clicks"
    case "rotations": "rotations"
    case "rotation.number.tick": "(rotation.number.tick)"
    case "number.click": "(number.click)"
    default: "on the dial"
    }
  }

  /// Every setting the grind wheel offers, finest first, in the grinder's own notation:
  /// zero to the coarsest end in the guide, at the guide's finest step.
  public var settings: [String] {
    let ends = [pourOver, aeroPress, frenchPress, moka, espresso, coldBrew].compactMap { $0 }
      .flatMap { $0.components(separatedBy: "–") }.map { $0.trimmingCharacters(in: .whitespaces) }
    if notation == "rotation.number.tick" {
      let turns = ends.compactMap { Int($0.split(separator: ".").first ?? "") }.max() ?? 0
      return (0...turns).flatMap { r in
        (0...9).flatMap { n in (0...9).map { "\(r).\(n).\($0)" } }
      }
    }
    // Baratza Vario: macro 1–10, micro A–W.
    if ends.contains(where: { $0.last?.isLetter == true }) {
      return (1...10).flatMap { n in "ABCDEFGHIJKLMNOPQRSTUVW".map { "\(n)\($0)" } }
    }
    // Eureka: the first turn reads 0–5.9 on the dial, later turns "turns+dial".
    if ends.contains(where: { $0.contains("+") }) {
      let turns = ends.compactMap { Int($0.split(separator: "+").first ?? "") }.max() ?? 0
      let dial = (0..<60).map { Self.number(Double($0) / 10, decimals: 1) }
      return dial + (1...max(turns, 1)).flatMap { t in dial.map { "\(t)+\($0)" } }
    }
    let decimals = ends.map { $0.split(separator: ".").dropFirst().first?.count ?? 0 }.max() ?? 0
    let coarsest = ends.compactMap(Double.init).max() ?? 40
    return Self.steps(through: coarsest, decimals: decimals)
  }

  /// The wheel stop for a typed or saved setting: "9.0" finds "9", "1" finds "1.0.0".
  public static func setting(_ text: String, in settings: [String]) -> String? {
    let t = text.trimmingCharacters(in: .whitespaces)
    return settings.first { $0 == t || $0 == t + ".0.0" }
      ?? Double(t).flatMap { v in settings.first { Double($0) == v } }
  }

  /// The wheel for a grinder the guide does not know: 0–40 by halves.
  public static let otherSettings = steps(through: 40, decimals: 1, step: 0.5)

  private static func steps(through max: Double, decimals: Int, step: Double? = nil) -> [String] {
    let step = step ?? pow(10, -Double(decimals))
    let count = Int((max / step).rounded())
    return (0...count).map { number(Double($0) * step, decimals: decimals) }
  }

  /// "9", "3.7", "0.33": no trailing zeros, always a dot whatever the locale.
  private static func number(_ value: Double, decimals: Int) -> String {
    var text = String(format: "%.\(decimals)f", value)
    if text.contains(".") {
      while text.hasSuffix("0") { text.removeLast() }
      if text.hasSuffix(".") { text.removeLast() }
    }
    return text
  }

  /// The guide entry for a grinder the user named, ignoring case and spacing.
  public static func find(_ name: String?) -> GrinderGuide? {
    guard let name else { return nil }
    let key = name.lowercased().filter { $0.isLetter || $0.isNumber }
    return all.first { $0.name.lowercased().filter { $0.isLetter || $0.isNumber } == key }
  }

  /// The guide's method for one of the app's brew method names, or nil when none fits.
  public static func method(forMethodNamed name: String?) -> Method? {
    guard let n = name?.lowercased() else { return nil }
    if n.contains("espresso") { return .espresso }
    if n.contains("cold brew") { return .coldBrew }
    if n.contains("moka") { return .moka }
    if n.contains("inverted press") || n.contains("aeropress") { return .aeroPress }
    if n.contains("press") { return .frenchPress }
    if n.contains("drip") || n.contains("pour") || n.contains("chemex") { return .pourOver }
    return nil
  }

  public static let all: [GrinderGuide] = [
    GrinderGuide(
      name: "Baratza Encore", kind: "Electric", notation: "dial", pourOver: "7 – 18",
      aeroPress: "3 – 29", frenchPress: "19 – 40", moka: "5 – 17", espresso: nil,
      coldBrew: "24 – 40",
      source: "https://honestcoffeeguide.com/baratza-encore-grind-settings/"),
    GrinderGuide(
      name: "Fellow Ode Gen 2", kind: "Electric", notation: "dial", pourOver: "2.2 – 5.2",
      aeroPress: "1.2 – 8.2", frenchPress: "6 – 11", moka: "2 – 5.1", espresso: nil,
      coldBrew: "7 – 11",
      source: "https://honestcoffeeguide.com/fellow-ode-brew-grinder-gen-2-grind-settings/"),
    GrinderGuide(
      name: "Timemore Sculptor 078", kind: "Electric", notation: "dial", pourOver: "1 – 6.5",
      aeroPress: "0 – 11.5", frenchPress: "6.5 – 18", moka: "0 – 5.5", espresso: nil,
      coldBrew: "9 – 18",
      source: "https://honestcoffeeguide.com/timemore-sculptor-078-grind-settings/"),
    GrinderGuide(
      name: "Turin DF64 Gen 2", kind: "Electric", notation: "dial", pourOver: "23 – 53",
      aeroPress: "15 – 80", frenchPress: "53 – 90", moka: "19 – 49", espresso: "0 – 20",
      coldBrew: "65 – 90",
      source: "https://honestcoffeeguide.com/turin-df64-gen-2-grind-settings/"),
    GrinderGuide(
      name: "Option-O Lagom Casa 65CL", kind: "Electric", notation: "rotation.number.tick",
      pourOver: "0.8.5 – 1.4.7", aeroPress: "0.6.8 – 2.0.2", frenchPress: "1.4.6 – 2.7.3",
      moka: "0.7.6 – 1.3.9", espresso: "0.3.8 – 0.8.0", coldBrew: "1.6.9 – 2.9.5",
      source: "https://honestcoffeeguide.com/option-o-lagom-casa-grind-settings/"),
    GrinderGuide(
      name: "Niche Zero", kind: "Electric", notation: "rotations", pourOver: "0.33 – 0.56",
      aeroPress: "0.26 – 0.77", frenchPress: "0.56 – 1.14", moka: "0.30 – 0.53",
      espresso: "0.15 – 0.30", coldBrew: "0.65 – 1.23",
      source: "https://honestcoffeeguide.com/niche-zero-grind-settings/"),
    GrinderGuide(
      name: "Baratza Vario W+", kind: "Electric", notation: "dial", pourOver: "2T – 6B",
      aeroPress: "2A – 8T", frenchPress: "6A – 10V", moka: "2J – 5O", espresso: "1A – 2N",
      coldBrew: "7E – 10V",
      source: "https://honestcoffeeguide.com/baratza-vario-w-plus-grind-settings/"),
    GrinderGuide(
      name: "Turin DF54", kind: "Electric", notation: "dial", pourOver: "34 – 67",
      aeroPress: "24 – 90", frenchPress: "67 – 90", moka: "29 – 62", espresso: "8 – 30",
      coldBrew: "79 – 90",
      source: "https://honestcoffeeguide.com/turin-df54-grind-settings/"),
    GrinderGuide(
      name: "Baratza Virtuoso+", kind: "Electric", notation: "dial", pourOver: "8 – 20",
      aeroPress: "5 – 30", frenchPress: "20 – 40", moka: "7 – 18", espresso: nil,
      coldBrew: "24 – 40",
      source: "https://honestcoffeeguide.com/baratza-virtuoso-plus-grind-settings/"),
    GrinderGuide(
      name: "Baratza Encore ESP", kind: "Electric", notation: "dial", pourOver: "15 – 25",
      aeroPress: "8 – 30", frenchPress: "25 – 38", moka: "12 – 24", espresso: "0 – 13",
      coldBrew: "27 – 40",
      source: "https://honestcoffeeguide.com/baratza-encore-esp-grind-settings/"),
    GrinderGuide(
      name: "Eureka Mignon Specialità", kind: "Electric", notation: "rotations",
      pourOver: "4.5 – 1+4", aeroPress: "2.5 – 2+3", frenchPress: "1+4 – 3+4", moka: "3.5 – 1+3",
      espresso: "0 – 3.5", coldBrew: "2+0.5 – 4+0",
      source: "https://honestcoffeeguide.com/eureka-mignon-specialita-grind-settings/"),
    GrinderGuide(
      name: "1Zpresso K-Ultra", kind: "Hand", notation: "rotation.number.tick",
      pourOver: "0.5.3 – 0.9.2", aeroPress: "0.4.3 – 1", frenchPress: "0.9.1 – 1",
      moka: "0.4.8 – 0.8.6", espresso: "0.2.4 – 0.5", coldBrew: "1",
      source: "https://honestcoffeeguide.com/1zpresso-k-ultra-grind-settings/"),
    GrinderGuide(
      name: "1Zpresso ZP6 Special", kind: "Hand", notation: "number.click", pourOver: "1.8 – 5.1",
      aeroPress: "0.9 – 8.0", frenchPress: "5.0 – 9.0", moka: "1.4 – 4.6", espresso: "0.0 – 1.5",
      coldBrew: "6.3 – 9.0",
      source: "https://honestcoffeeguide.com/1zpresso-zp6-special-grind-settings/"),
    GrinderGuide(
      name: "KINGrinder K6", kind: "Hand", notation: "rotations", pourOver: "0.48 – 1.22",
      aeroPress: "0.38 – 1.53", frenchPress: "1.22 – 2.34", moka: "0.43 – 1.18",
      espresso: "0.22 – 0.45", coldBrew: "1.35 – 2.40",
      source: "https://honestcoffeeguide.com/kingrinder-k6-grind-settings/"),
    GrinderGuide(
      name: "Comandante C40 MK4", kind: "Hand", notation: "clicks", pourOver: "15 – 25",
      aeroPress: "12 – 35", frenchPress: "26 – 40", moka: "14 – 24", espresso: "7 – 13",
      coldBrew: "30 – 40",
      source: "https://honestcoffeeguide.com/comandante-c40-mk4-grind-settings/"),
    GrinderGuide(
      name: "Pietro Pro Brewing", kind: "Hand", notation: "dial", pourOver: "3.1 – 7.0",
      aeroPress: "2.0 – 10.0", frenchPress: "7.0 – 10.0", moka: "2.6 – 6.5", espresso: nil,
      coldBrew: "8.4 – 10.0",
      source: "https://honestcoffeeguide.com/fiorenzato-pietro-b-modal-burrs-grind-settings/"),
    GrinderGuide(
      name: "1Zpresso J-Ultra", kind: "Hand", notation: "rotation.number.tick",
      pourOver: "1.6.3 – 2.8.4", aeroPress: "1.3.1 – 3.9.0", frenchPress: "2.8.1 – 5.0.0",
      moka: "1.4.7 – 2.6.8", espresso: "0.7.4 – 1.5.4", coldBrew: "3.2.6 – 5.0.0",
      source: "https://honestcoffeeguide.com/1zpresso-j-ultra-grind-settings/"),
    GrinderGuide(
      name: "Kinu M47 Phoenix", kind: "Hand", notation: "rotations", pourOver: "2.5 – 4.2",
      aeroPress: "2 – 5.8", frenchPress: "4.2 – 7.8", moka: "2.2 – 4", espresso: "1.1 – 2.3",
      coldBrew: "4.9 – 8.5",
      source: "https://honestcoffeeguide.com/kinu-m47-phoenix-grind-settings/"),
    GrinderGuide(
      name: "Timemore Chestnut S3", kind: "Hand", notation: "clicks", pourOver: "0.9 – 4.2",
      aeroPress: "0 – 7.2", frenchPress: "4.2 – 9.0", moka: "0.4 – 3.8", espresso: nil,
      coldBrew: "5.5 – 9.0",
      source: "https://honestcoffeeguide.com/timemore-s3-grind-settings/"),
    GrinderGuide(
      name: "1Zpresso J", kind: "Hand", notation: "rotation.number.tick", pourOver: "1.5.0 – 2.5.2",
      aeroPress: "1.2.0 – 3.5.1", frenchPress: "2.5.2 – 4.0.0", moka: "1.3.1 – 2.4.1",
      espresso: "0.6.2 – 1.4.0", coldBrew: "2.9.2 – 4.0.0",
      source: "https://honestcoffeeguide.com/1zpresso-j-grind-settings/"),
    GrinderGuide(
      name: "1Zpresso Q Air", kind: "Hand", notation: "rotation.number.tick",
      pourOver: "1.2.0 – 2.0.1", aeroPress: "0.9.2 – 2.8.0", frenchPress: "2.0.1 – 3.8.0",
      moka: "1.0.2 – 1.9.1", espresso: "0.5.1 – 1.1.0", coldBrew: "2.3.2 – 4.0.0",
      source: "https://honestcoffeeguide.com/1zpresso-q-air-grind-settings/"),
  ]
}
