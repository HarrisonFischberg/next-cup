import NextCupKit
import Testing

@testable import NextCup

@Suite("Step cues") struct StepCueTests {
  private func cues(_ steps: [(String, Int, Double?)], total: Int) throws -> [StepCue] {
    let plan = try TimerPlan(
      steps: steps.enumerated().map { index, step in
        TimerStep(
          order: index, label: step.0, startOffsetS: step.1, targetCumulativeWaterG: step.2)
      }, totalDurationS: total)
    return StepCue.cues(plan: plan, kinds: steps.map(\.0), units: UnitPreferences())
  }

  @Test func switchableSaysWhenTheValveClosesAndOpens() throws {
    let all = try cues(
      [
        ("closeValve", 0, nil), ("pour", 0, 270), ("stir", 30, nil), ("wait", 40, nil),
        ("openValve", 120, nil), ("drawdown", 125, nil),
      ], total: 210)
    #expect(
      all.map(\.title) == [
        "Close the valve, then pour to 270 g", "Stir", "Wait", "Open the valve", "Let it drain",
      ])
    #expect(all.map(\.valveOpen) == [false, false, false, true, true])
    #expect(all[0].waitTitle == "Hands off. Let it steep")
    #expect(all[0].waitDetail == "You should be at 270 g.")
    #expect(all[3].waitTitle == "Hands off. Let it drain")
    #expect(all[0].pours && all[0].doS == 3 + 54)
  }

  @Test func conePoursSayTheTargetAndHowMuchToAdd() throws {
    let all = try cues(
      [("bloom", 0, 45), ("pour", 45, 150), ("pour", 85, 250), ("drawdown", 125, nil)],
      total: 180)
    #expect(all[1].title == "Pour to 150 g")
    #expect(all[1].detail == "Add 105 g.")
    #expect(all[1].doS == 21)
    #expect(all[1].waitTitle == "Hands off. Let it drain")
    #expect(all.allSatisfy { $0.valveOpen == nil })
    #expect(all[3].doS == 0)
  }

  @Test func pressStepsKeepYourHandsBusyForTheWholeStep() throws {
    let all = try cues(
      [("pour", 0, 250), ("stir", 30, nil), ("wait", 45, nil), ("press", 240, nil)], total: 270)
    #expect(all[0].waitTitle == "Hands off. Let it steep")
    #expect(all[3].title == "Press the plunger down")
    #expect(all[3].doS == nil)
  }
}
