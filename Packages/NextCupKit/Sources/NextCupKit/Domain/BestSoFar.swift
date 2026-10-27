import Foundation

/// One saved brew of a bean, reduced to the values the best-so-far card reads.
/// Canonical units (grams, °C, seconds); `grinder` is the grinder's name.
public struct BrewSample: Equatable, Sendable {
  public var date: Date
  public var ratingTenths: Int?
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?
  public var grindSetting: String?
  public var grinder: String?

  public init(
    date: Date, ratingTenths: Int? = nil, doseG: Double? = nil, waterG: Double? = nil,
    tempC: Double? = nil, totalTimeS: Int? = nil, grindSetting: String? = nil,
    grinder: String? = nil
  ) {
    self.date = date
    self.ratingTenths = ratingTenths
    self.doseG = doseG
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
    self.grindSetting = grindSetting
    self.grinder = grinder
  }

  var isRated: Bool { (ratingTenths ?? 0) > 0 }
}

/// How many brews got one grade (in half-stars, 1 to 10).
public struct RatingCount: Equatable, Sendable {
  public var tenths: Int
  public var brews: Int
}

/// One grind setting used at one dose on one grinder, with how it turned out.
public struct GrindEntry: Equatable, Sendable {
  /// `nil` when the brews did not record a grinder.
  public var grinder: String?
  public var doseG: Double?
  public var setting: String
  public var brews: Int
  /// Mean grade in half-stars over the rated brews, `nil` if none were rated.
  public var averageTenths: Double?
  public var lastUsed: Date
}

public struct BestSoFarSummary: Equatable, Sendable {
  public var brewCount: Int
  public var ratedCount: Int
  /// Grades from lowest to highest, only the ones that occur.
  public var spread: [RatingCount]
  public var averageTenths: Double?
  /// The highest-graded brew (the newest of any tie): its settings are the
  /// bean's best so far. `nil` until a brew is graded.
  public var best: BrewSample?
  /// Sorted by grinder (unnamed last), then dose, then newest first.
  public var grindHistory: [GrindEntry]
}

public enum BestSoFar {
  public static func summarize(_ samples: [BrewSample]) -> BestSoFarSummary {
    let rated = samples.filter(\.isRated)
    let counts = Dictionary(grouping: rated, by: { $0.ratingTenths ?? 0 })
      .map { RatingCount(tenths: $0.key, brews: $0.value.count) }
      .sorted { $0.tenths < $1.tenths }
    let average =
      rated.isEmpty
      ? nil : Double(rated.reduce(0) { $0 + ($1.ratingTenths ?? 0) }) / Double(rated.count)
    let best = rated.max {
      let (a, b) = ($0.ratingTenths ?? 0, $1.ratingTenths ?? 0)
      return a == b ? $0.date < $1.date : a < b
    }
    return BestSoFarSummary(
      brewCount: samples.count, ratedCount: rated.count, spread: counts,
      averageTenths: average, best: best, grindHistory: grindHistory(samples))
  }

  private struct Key: Hashable {
    var grinder: String?
    var dose: Int?  // tenths of a gram, so 15.0 and 15.04 are the same dose
    var setting: String
  }

  private static func grindHistory(_ samples: [BrewSample]) -> [GrindEntry] {
    var groups: [Key: [BrewSample]] = [:]
    for sample in samples {
      let setting = sample.grindSetting?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !setting.isEmpty else { continue }
      let grinder = sample.grinder?.trimmingCharacters(in: .whitespacesAndNewlines)
      let key = Key(
        grinder: grinder?.isEmpty == false ? grinder : nil,
        dose: sample.doseG.map { Int(($0 * 10).rounded()) }, setting: setting)
      groups[key, default: []].append(sample)
    }
    let entries = groups.map { key, group -> GrindEntry in
      let grades = group.compactMap { $0.isRated ? $0.ratingTenths : nil }
      return GrindEntry(
        grinder: key.grinder, doseG: key.dose.map { Double($0) / 10 }, setting: key.setting,
        brews: group.count,
        averageTenths: grades.isEmpty
          ? nil : Double(grades.reduce(0, +)) / Double(grades.count),
        lastUsed: group.map(\.date).max() ?? .distantPast)
    }
    return entries.sorted { a, b in
      switch (a.grinder, b.grinder) {
      case (let x?, let y?) where x != y:
        return x.localizedStandardCompare(y) == .orderedAscending
      case (_?, nil): return true
      case (nil, _?): return false
      default: break
      }
      if a.doseG != b.doseG { return (a.doseG ?? -1) < (b.doseG ?? -1) }
      return a.lastUsed > b.lastUsed
    }
  }
}
