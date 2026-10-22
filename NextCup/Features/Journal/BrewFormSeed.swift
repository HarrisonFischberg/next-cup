import Foundation
import NextCupKit
import SwiftUI

/// The values the brew form (S02) opens with after a guided brew. Targets come
/// from the recipe as scaled; the time is what the timer actually reached.
struct BrewFormSeed: Hashable {
  let recipeID: UUID
  let recipeName: String
  let methodName: String?
  let doseG: Double
  let waterG: Double
  let tempC: Double?
  let totalTimeS: Int
  let endedEarly: Bool
}

/// Stands in for the brew form until T009 builds S02. It shows exactly what the
/// timer hands over, so the handoff can be checked now.
struct BrewFormPlaceholder: View {
  let seed: BrewFormSeed
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text("NEW BREW").font(DS.Font.display).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap)
          .accessibilityAddTraits(.isHeader)
        Text([seed.recipeName, seed.methodName].compactMap { $0 }.joined(separator: " · "))
          .font(.subheadline).foregroundStyle(DS.ink2)
        if seed.endedEarly {
          StateBanner(
            kind: .info, message: "You ended this brew early. The time below is what it reached.")
        }
        ReadoutTile(title: "Dose", value: RecipeFormat.weight(seed.doseG, units))
          .accessibilityIdentifier("brewform.dose")
        ReadoutTile(title: "Water", value: RecipeFormat.weight(seed.waterG, units))
          .accessibilityIdentifier("brewform.water")
        ReadoutTile(title: "Time", value: RecipeFormat.clock(seed.totalTimeS))
          .accessibilityIdentifier("brewform.time")
        if let tempC = seed.tempC {
          ReadoutTile(title: "Temperature", value: RecipeFormat.temperature(tempC, units))
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("New brew")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("brewform.prefilled")
  }
}
