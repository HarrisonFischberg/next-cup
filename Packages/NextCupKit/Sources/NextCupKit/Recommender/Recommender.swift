import Foundation

/// One taxonomy bucket together with the dimension it belongs to, so a bean and a
/// past brew can be compared bucket by bucket.
public struct BucketRef: Hashable, Sendable {
  public var dimension: Taxonomy.Dimension
  public var key: String
  public var name: String

  public init(dimension: Taxonomy.Dimension, key: String, name: String) {
    self.dimension = dimension
    self.key = key
    self.name = name
  }

  public init(_ bucket: Taxonomy.Bucket, in dimension: Taxonomy.Dimension) {
    self.init(dimension: dimension, key: bucket.key, name: bucket.name)
  }

  /// Identity for matching: two refs are the same bucket when dimension and key agree.
  fileprivate var identity: String { "\(dimension.rawValue):\(key)" }
}

/// One saved brew, reduced to what the recommender reads: how it turned out, how it
/// was made, and the buckets of the beans in it. Canonical units.
public struct RecommenderBrew: Equatable, Sendable {
  public var date: Date
  public var ratingTenths: Int?
  /// The method's `builtInKey`, `nil` for a method the user made.
  public var methodKey: String?
  public var methodName: String
  public var recipeName: String?
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?
  public var grindSetting: String?
  public var buckets: [BucketRef]

  public init(
    date: Date, ratingTenths: Int? = nil, methodKey: String? = nil, methodName: String,
    recipeName: String? = nil, doseG: Double? = nil, waterG: Double? = nil, tempC: Double? = nil,
    totalTimeS: Int? = nil, grindSetting: String? = nil, buckets: [BucketRef] = []
  ) {
    self.date = date
    self.ratingTenths = ratingTenths
    self.methodKey = methodKey
    self.methodName = methodName
    self.recipeName = recipeName
    self.doseG = doseG
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
    self.grindSetting = grindSetting
    self.buckets = buckets
  }

  fileprivate var isRated: Bool { (ratingTenths ?? 0) > 0 }

  /// Brews of the same method group together: by built-in key, else by name.
  fileprivate var methodID: String {
    methodKey ?? "name:" + Taxonomy.normalize(methodName)
  }
}

/// The values a brew can start from. Any of them may be missing.
public struct StartParameters: Equatable, Sendable {
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?
  public var grindSetting: String?

  public init(
    doseG: Double? = nil, waterG: Double? = nil, tempC: Double? = nil, totalTimeS: Int? = nil,
    grindSetting: String? = nil
  ) {
    self.doseG = doseG
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
    self.grindSetting = grindSetting
  }
}

/// The computed facts a history-based recommendation stands on. The explanation is
/// built from these and nothing else.
public struct HistoryFacts: Equatable, Sendable {
  /// Rated, similar brews made with this method.
  public var methodBrews: Int
  /// Rated, similar brews made with any method.
  public var similarBrews: Int
  /// Mean grade in half-stars over `methodBrews`.
  public var averageTenths: Double
  public var bestTenths: Int
  public var bestDate: Date
  /// Names of the buckets the similar brews share with the bean.
  public var sharedBuckets: [String]
}

public struct Recommendation: Equatable, Sendable {
  public enum Basis: Equatable, Sendable {
    case history(HistoryFacts)
    /// Bundled starting point for a roast band. `roast` is the band's name, or `nil`
    /// when the bean has no roast level and the medium default was used.
    case bundledDefault(roast: String?)
  }

  public var methodKey: String?
  public var methodName: String
  public var recipeName: String?
  public var start: StartParameters
  public var basis: Basis

  public var isDefault: Bool {
    if case .bundledDefault = basis { return true }
    return false
  }

  /// One sentence made only from the computed facts, or the label that says this is
  /// a default and not learned from the user's brews.
  public var explanation: String {
    switch basis {
    case .history(let facts):
      let brews = facts.methodBrews == 1 ? "1 brew" : "\(facts.methodBrews) brews"
      let similar =
        facts.similarBrews == facts.methodBrews
        ? "" : " of \(facts.similarBrews) similar rated brews"
      let shared =
        facts.sharedBuckets.isEmpty
        ? "" : " (\(facts.sharedBuckets.joined(separator: ", ")))"
      return
        "Your \(brews)\(similar) with beans like this\(shared) averaged \(Recommender.grade(facts.averageTenths)) of 10; the best was \(Recommender.grade(Double(facts.bestTenths)))."
    case .bundledDefault(let roast):
      let band = roast.map { "\($0.lowercased()) roasts" } ?? "a bean with no roast level"
      return
        "A default starting point for \(band). It is not based on your brews yet; grade a few similar brews and this changes."
    }
  }
}

public struct RecommendationResult: Equatable, Sendable {
  public var items: [Recommendation]
  /// True when `items` is the bundled default and not learned from history.
  public var isDefault: Bool
  /// Rated brews that were similar to the bean, whatever their method.
  public var similarRatedCount: Int
}

public enum Recommender {
  /// How many rated, similar brews it takes before history replaces the default.
  public static let minimumSimilarBrews = 3

  /// Dimensions that decide whether two beans are alike. Flavor and brewer are too
  /// loose: bag notes vary a lot between bags of the same coffee.
  private static let similarityDimensions: Set<Taxonomy.Dimension> = [.origin, .process, .roast]

  /// Bundled starting points by roast band, written for Next Cup.
  private static let defaults: [String: (key: String, name: String, start: StartParameters)] = [
    "light": (
      "cone-dripper", "Cone dripper",
      StartParameters(doseG: 15, waterG: 250, tempC: 96, totalTimeS: 165, grindSetting: nil)
    ),
    "medium": (
      "cone-dripper", "Cone dripper",
      StartParameters(doseG: 15, waterG: 250, tempC: 93, totalTimeS: 180, grindSetting: nil)
    ),
    "dark": (
      "press", "Press pot",
      StartParameters(doseG: 16, waterG: 250, tempC: 90, totalTimeS: 240, grindSetting: nil)
    ),
  ]

  /// Ranks the methods that worked best for brews of similar beans. With fewer than
  /// `minimumSimilarBrews` rated similar brews it returns the bundled default for
  /// the bean's roast band, labelled as a default.
  public static func recommend(
    for beanBuckets: [BucketRef], history: [RecommenderBrew], limit: Int = 3
  ) -> RecommendationResult {
    let wanted = beanBuckets.filter { similarityDimensions.contains($0.dimension) }
    let wantedIDs = Set(wanted.map(\.identity))
    // A bean with only a roast level needs one match; with more it needs two.
    let required = min(2, wantedIDs.count)

    var similar: [(brew: RecommenderBrew, shared: Set<BucketRef>)] = []
    if required > 0 {
      for brew in history where brew.isRated {
        let shared = Set(brew.buckets.filter { wantedIDs.contains($0.identity) })
        if shared.count >= required { similar.append((brew, shared)) }
      }
    }

    guard similar.count >= minimumSimilarBrews else {
      return RecommendationResult(
        items: [bundledDefault(for: beanBuckets)], isDefault: true, similarRatedCount: similar.count
      )
    }

    let sharedNames = Dictionary(
      grouping: similar.flatMap(\.shared), by: \.identity
    ).values.compactMap { $0.first }
      .sorted { ($0.dimension.rawValue, $0.name) < ($1.dimension.rawValue, $1.name) }
      .map(\.name)

    let groups = Dictionary(grouping: similar.map(\.brew), by: \.methodID)
    let ranked = groups.values.map { group -> (average: Double, group: [RecommenderBrew]) in
      let grades = group.compactMap(\.ratingTenths)
      return (Double(grades.reduce(0, +)) / Double(grades.count), group)
    }.sorted { a, b in
      if a.average != b.average { return a.average > b.average }
      if a.group.count != b.group.count { return a.group.count > b.group.count }
      let (x, y) = (
        a.group.map(\.date).max() ?? .distantPast, b.group.map(\.date).max() ?? .distantPast
      )
      if x != y { return x > y }
      return a.group[0].methodID < b.group[0].methodID
    }

    let items = ranked.prefix(max(1, limit)).map { entry -> Recommendation in
      let best = entry.group.max {
        let (a, b) = ($0.ratingTenths ?? 0, $1.ratingTenths ?? 0)
        return a == b ? $0.date < $1.date : a < b
      }!
      let facts = HistoryFacts(
        methodBrews: entry.group.count, similarBrews: similar.count,
        averageTenths: entry.average, bestTenths: best.ratingTenths ?? 0,
        bestDate: best.date, sharedBuckets: sharedNames)
      let grind = best.grindSetting?.trimmingCharacters(in: .whitespacesAndNewlines)
      return Recommendation(
        methodKey: best.methodKey, methodName: best.methodName, recipeName: best.recipeName,
        start: StartParameters(
          doseG: best.doseG, waterG: best.waterG, tempC: best.tempC, totalTimeS: best.totalTimeS,
          grindSetting: grind?.isEmpty == false ? grind : nil),
        basis: .history(facts))
    }
    return RecommendationResult(
      items: Array(items), isDefault: false, similarRatedCount: similar.count)
  }

  private static func bundledDefault(for buckets: [BucketRef]) -> Recommendation {
    let roast = buckets.first { $0.dimension == .roast }
    let entry = roast.flatMap { defaults[$0.key] }
    let chosen = entry ?? defaults["medium"]!
    return Recommendation(
      methodKey: chosen.key, methodName: chosen.name, recipeName: nil, start: chosen.start,
      basis: .bundledDefault(roast: entry == nil ? nil : roast?.name))
  }

  /// A rating out of 10 with at most one decimal: 74 → "7.4", 80 → "8".
  static func grade(_ tenths: Double) -> String { Rating.text(Int(tenths.rounded())) }
}
