import Foundation

/// What the recipe asked for, kept beside the values the user actually brewed
/// with. Never locks the form (X5).
public struct BrewTargets: Codable, Equatable, Sendable {
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?

  public init(
    doseG: Double? = nil, waterG: Double? = nil, tempC: Double? = nil, totalTimeS: Int? = nil
  ) {
    self.doseG = doseG
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
  }
}

/// A bean in a brew being repeated: which bean (when it still exists), its name
/// as it was, and its share of the dose.
public struct DraftBean: Codable, Equatable, Sendable {
  public var beanID: UUID?
  public var name: String
  public var grams: Double

  public init(beanID: UUID?, name: String, grams: Double) {
    self.beanID = beanID
    self.name = name
    self.grams = grams
  }
}

/// The open brew form, saved outside the store so typed input survives
/// navigation, backgrounding and a crash. Canonical units only (grams, °C,
/// seconds); `verdict` holds the stored raw value.
public struct BrewDraft: Codable, Equatable, Sendable {
  public var id: UUID
  /// Identifies what opened the form (a finished timer run), so reopening the
  /// same run restores this draft instead of overwriting it with the seed.
  public var sourceKey: String?
  public var date: Date
  public var methodID: UUID?
  public var recipeID: UUID?
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?
  public var grindSetting: String
  public var verdict: String?
  public var ratingTenths: Int
  public var notes: String
  public var photo: Data?
  public var targets: BrewTargets?
  public var endedEarly: Bool
  /// The beans in the brew, as shares of the dose (`grams` holds the share, so the
  /// dose can change and each bean still takes its part). `nil` for a draft that
  /// predates bean choice: saving it leaves the brew's beans alone.
  public var beans: [DraftBean]?
  /// The grinder used, if one was chosen. Old drafts without it read as `nil`.
  public var grinderID: UUID?
  /// Total dissolved solids of the cup in percent, if measured.
  public var tds: Double?
  /// The water used, if a profile was chosen.
  public var waterProfileID: UUID?

  public init(
    id: UUID = UUID(), sourceKey: String? = nil, date: Date = Date(), methodID: UUID? = nil,
    recipeID: UUID? = nil, doseG: Double? = nil, waterG: Double? = nil, tempC: Double? = nil,
    totalTimeS: Int? = nil, grindSetting: String = "", verdict: String? = nil,
    ratingTenths: Int = 0, notes: String = "", photo: Data? = nil, targets: BrewTargets? = nil,
    endedEarly: Bool = false, beans: [DraftBean]? = nil, grinderID: UUID? = nil, tds: Double? = nil,
    waterProfileID: UUID? = nil
  ) {
    self.id = id
    self.sourceKey = sourceKey
    self.date = date
    self.methodID = methodID
    self.recipeID = recipeID
    self.doseG = doseG
    self.waterG = waterG
    self.tempC = tempC
    self.totalTimeS = totalTimeS
    self.grindSetting = grindSetting
    self.verdict = verdict
    self.ratingTenths = ratingTenths
    self.notes = notes
    self.photo = photo
    self.targets = targets
    self.endedEarly = endedEarly
    self.beans = beans
    self.grinderID = grinderID
    self.tds = tds
    self.waterProfileID = waterProfileID
  }

  /// Identifies a "Brew again" draft, so reopening the same repeat restores it.
  public static func repeatKey(for sourceID: UUID) -> String { "again:\(sourceID.uuidString)" }

  /// A fresh brew that repeats `source` (X2): the same method, recipe, beans,
  /// amounts, temperature and grind, with the time reset. The date, verdict,
  /// grade, notes and photo belong to the cup that was drunk, so they start empty.
  /// The recipe's targets stay beside the values.
  public static func repeating(
    _ source: BrewDraft, sourceID: UUID, beans: [DraftBean], now: Date = Date(),
    id: UUID = UUID()
  ) -> BrewDraft {
    BrewDraft(
      id: id, sourceKey: repeatKey(for: sourceID), date: now, methodID: source.methodID,
      recipeID: source.recipeID, doseG: source.doseG, waterG: source.waterG,
      tempC: source.tempC, totalTimeS: nil, grindSetting: source.grindSetting,
      targets: source.targets, beans: beans, grinderID: source.grinderID,
      waterProfileID: source.waterProfileID)
  }

  /// A brew needs the two numbers every derived value rests on.
  public var canSave: Bool {
    guard let doseG, let waterG else { return false }
    return doseG > 0 && waterG > 0
  }
}
