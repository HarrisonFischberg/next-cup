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
  public var ratingHalfSteps: Int
  public var notes: String
  public var photo: Data?
  public var targets: BrewTargets?
  public var endedEarly: Bool

  public init(
    id: UUID = UUID(), sourceKey: String? = nil, date: Date = Date(), methodID: UUID? = nil,
    recipeID: UUID? = nil, doseG: Double? = nil, waterG: Double? = nil, tempC: Double? = nil,
    totalTimeS: Int? = nil, grindSetting: String = "", verdict: String? = nil,
    ratingHalfSteps: Int = 0, notes: String = "", photo: Data? = nil, targets: BrewTargets? = nil,
    endedEarly: Bool = false
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
    self.ratingHalfSteps = ratingHalfSteps
    self.notes = notes
    self.photo = photo
    self.targets = targets
    self.endedEarly = endedEarly
  }

  /// A brew needs the two numbers every derived value rests on.
  public var canSave: Bool {
    guard let doseG, let waterG else { return false }
    return doseG > 0 && waterG > 0
  }
}
