import Foundation
import NextCupKit

/// The values the brew form (S02) opens with after a guided brew. Targets come
/// from the recipe as scaled; the time is what the timer actually reached.
struct BrewFormSeed: Hashable {
  /// Identifies the timer run, so reopening the form for the same run restores
  /// the draft instead of resetting it.
  let sessionKey: String
  let recipeID: UUID
  let recipeName: String
  let methodName: String?
  let doseG: Double
  let waterG: Double
  let tempC: Double?
  let totalTimeS: Int
  let targetTimeS: Int?
  let endedEarly: Bool
  /// The bean, grinder and grind picked on the Start brew page, if any.
  var beanID: UUID?
  var beanName: String?
  var grinderID: UUID?
  var grindSetting = ""

  var targets: BrewTargets {
    BrewTargets(doseG: doseG, waterG: waterG, tempC: tempC, totalTimeS: targetTimeS)
  }
}
