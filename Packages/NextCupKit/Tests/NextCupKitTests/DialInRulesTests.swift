import Testing

@testable import NextCupKit

@Suite("DialInRules")
struct DialInRulesTests {
  private func input(
    _ verdict: DialInVerdict, style: DialInStyle = .pourOver,
    tracked: Set<DialInParameter> = [.grind, .temperature, .time], grind: String? = "20",
    water: Double? = 250, temp: Double? = 94, time: Int? = 180
  ) -> DialInInput {
    DialInInput(
      verdict: verdict, style: style, tracked: tracked, grindSetting: grind, waterG: water,
      tempC: temp, totalTimeS: time)
  }

  private func change(_ outcome: DialInOutcome) -> SuggestionDraft? {
    if case .change(let draft) = outcome { return draft }
    return nil
  }

  @Test func balancedKeepsEverything() {
    let outcome = DialInRules.suggest(for: input(.balanced))
    guard case .keep(let message) = outcome else {
      Issue.record("balanced must not propose a change")
      return
    }
    #expect(message.contains("balanced"))
  }

  @Test func sourGoesFinerFirst() {
    let draft = change(DialInRules.suggest(for: input(.sour)))
    #expect(draft?.parameter == .grind)
    #expect(draft?.fromValue == "20")
    #expect(draft?.toValue == "19")
  }

  @Test func bitterGoesCoarserFirst() {
    let draft = change(DialInRules.suggest(for: input(.bitter)))
    #expect(draft?.parameter == .grind)
    #expect(draft?.toValue == "21")
  }

  @Test func grindKeepsTheTextAroundTheNumber() {
    let sour = change(DialInRules.suggest(for: input(.sour, grind: "21 clicks")))
    #expect(sour?.toValue == "20 clicks")
    let decimal = change(DialInRules.suggest(for: input(.bitter, grind: "5.5")))
    #expect(decimal?.toValue == "6.5")
  }

  @Test func wordsAndBlankGrindGetAWrittenStep() {
    let words = change(DialInRules.suggest(for: input(.sour, grind: "medium fine")))
    #expect(words?.parameter == .grind)
    #expect(words?.toValue == "one step finer")
    let blank = change(DialInRules.suggest(for: input(.bitter, grind: nil)))
    #expect(blank?.fromValue == "")
    #expect(blank?.toValue == "one step coarser")
  }

  @Test func theFinestSettingFallsBackToAWrittenStep() {
    let draft = change(DialInRules.suggest(for: input(.sour, grind: "0")))
    #expect(draft?.toValue == "one step finer")
  }

  @Test func sourWithoutGrindTrackedRaisesTemperature() {
    let draft = change(
      DialInRules.suggest(for: input(.sour, tracked: [.temperature, .time])))
    #expect(draft?.parameter == .temperature)
    #expect(draft?.fromValue == "94")
    #expect(draft?.toValue == "96")
  }

  @Test func bitterWithoutGrindTrackedLowersTemperature() {
    let draft = change(DialInRules.suggest(for: input(.bitter, tracked: [.temperature])))
    #expect(draft?.toValue == "92")
  }

  @Test func temperatureStopsAtItsLimits() {
    let hot = DialInRules.suggest(for: input(.sour, tracked: [.temperature], temp: 99))
    #expect(hot == .keep("No setting for this sour cup can be changed from here."))
    let cool = DialInRules.suggest(for: input(.bitter, tracked: [.temperature], temp: 80))
    #expect(change(cool) == nil)
  }

  @Test func immersionAndColdUseSteepTime() {
    let immersion = change(
      DialInRules.suggest(for: input(.sour, style: .immersion, tracked: [.time], time: 240)))
    #expect(immersion?.parameter == .time)
    #expect(immersion?.toValue == "270")
    let cold = change(
      DialInRules.suggest(
        for: input(.bitter, style: .cold, tracked: [.time, .temperature], time: 50_400)))
    #expect(cold?.parameter == .time)
    #expect(cold?.toValue == "43200")
  }

  @Test func pourOverTimeIsAResultNotALever() {
    let outcome = DialInRules.suggest(for: input(.sour, tracked: [.time]))
    #expect(change(outcome) == nil)
  }

  @Test func coldBrewNeverGetsHotWaterAdvice() {
    let draft = change(
      DialInRules.suggest(for: input(.sour, style: .cold, tracked: [.temperature, .time])))
    #expect(draft?.parameter == .time)
  }

  @Test func weakCutsWaterAndStrongAddsIt() {
    let weak = change(DialInRules.suggest(for: input(.weak, water: 250)))
    #expect(weak?.parameter == .water)
    #expect(weak?.toValue == "235")
    let strong = change(DialInRules.suggest(for: input(.strong, water: 250)))
    #expect(strong?.toValue == "270")
  }

  @Test func espressoMovesTheOutputWeight() {
    let weak = change(DialInRules.suggest(for: input(.weak, style: .espresso, water: 36)))
    #expect(weak?.parameter == .yield)
    #expect(weak?.toValue == "32.5")
    let strong = change(DialInRules.suggest(for: input(.strong, style: .espresso, water: 36)))
    #expect(strong?.toValue == "39.5")
  }

  @Test func strengthNeedsAWaterWeight() {
    #expect(change(DialInRules.suggest(for: input(.weak, water: nil))) == nil)
    #expect(change(DialInRules.suggest(for: input(.strong, water: 0))) == nil)
  }

  @Test func everyChangeCarriesAReason() {
    for verdict in DialInVerdict.allCases where verdict != .balanced {
      let draft = change(DialInRules.suggest(for: input(verdict)))
      #expect(draft?.rationale.isEmpty == false)
    }
  }

  @Test func theSameInputGivesTheSameAnswer() {
    let first = DialInRules.suggest(for: input(.sour))
    #expect(first == DialInRules.suggest(for: input(.sour)))
  }
}
