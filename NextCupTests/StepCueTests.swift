import Foundation
import NextCupKit
import Testing

@testable import NextCup

@Suite("Step cues") struct StepCueTests {
  private func cues(
    _ steps: [(String, Int, Double?)], total: Int, method: String
  ) throws -> [StepCue] {
    let plan = try TimerPlan(
      steps: steps.enumerated().map { index, step in
        TimerStep(
          order: index, label: step.0, startOffsetS: step.1, targetCumulativeWaterG: step.2)
      }, totalDurationS: total)
    return StepCue.cues(
      plan: plan, kinds: steps.map(\.0), method: method, units: UnitPreferences())
  }

  @Test func switchableSaysWhenTheValveClosesAndOpens() throws {
    let all = try cues(
      [
        ("closeValve", 0, nil), ("pour", 0, 270), ("stir", 30, nil), ("wait", 40, nil),
        ("openValve", 120, nil), ("drawdown", 125, nil),
      ], total: 210, method: "switchable-dripper")
    #expect(
      all.map(\.title) == [
        "Close the valve, then pour to 270 g", "Stir the grounds", "Hands off. Let it steep",
        "Open the valve", "Hands off. Let it drain",
      ])
    #expect(all.map(\.valveOpen) == [false, false, false, true, true])
    #expect(all[0].waitTitle == "Hands off. Let it steep")
    #expect(all[0].waitDetail == "You should be at 270 g.")
    #expect(all[0].nowChip == "Do it now" && all[0].doS == 3 + 54)
  }

  @Test func conePoursSayTheTargetAndHowMuchToAdd() throws {
    let all = try cues(
      [("bloom", 0, 45), ("pour", 45, 150), ("pour", 85, 250), ("drawdown", 125, nil)],
      total: 180, method: "cone-dripper")
    #expect(all[0].waitTitle == "Hands off. Let it bloom")
    #expect(all[1].title == "Pour to 150 g")
    #expect(all[1].detail == "Add 105 g.")
    #expect(all[1].doS == 21 && all[1].nowChip == "Pour now")
    #expect(all[1].waitTitle == "Hands off. Let it drain")
    #expect(all.allSatisfy { $0.valveOpen == nil })
    #expect(all[3].doS == 0)
  }

  @Test func espressoStartsAndStopsTheShotAtTheYield() throws {
    let all = try cues([("pour", 0, 36), ("wait", 25, nil)], total: 28, method: "espresso")
    #expect(all.map(\.title) == ["Start the shot", "Stop the shot at 36 g"])
    #expect(all[0].nowChip == "Watch the scale" && all[0].doS == nil)
    #expect(all[0].detail == "Aim for 36 g in the cup.")
  }

  @Test func mokaPotSaysFillHeatWatchAndTakeOff() throws {
    let all = try cues(
      [("pour", 0, 180), ("heat", 30, nil), ("wait", 150, nil), ("offHeat", 200, nil)],
      total: 240, method: "moka-pot")
    #expect(
      all.map(\.title) == [
        "Fill the base with 180 g of water", "Put it on the heat, lid open",
        "Watch the spout as the coffee rises", "Take it off the heat and cool the base",
      ])
    #expect(all[1].waitTitle == "Hands off. Wait for the coffee to rise")
  }

  @Test func aeropressPlungesAndTopsUp() throws {
    let all = try cues(
      [
        ("pour", 0, 100), ("stir", 10, nil), ("plug", 20, nil), ("press", 60, nil),
        ("bypass", 90, 200),
      ], total: 120, method: "aeropress")
    #expect(
      all.map(\.title) == [
        "Pour to 100 g", "Stir the grounds", "Set the plunger on top",
        "Press the plunger down slowly",
        "Top up with 100 g of hot water",
      ])
    #expect(all[2].waitTitle == "Hands off. Let it steep")
    #expect(all[3].doS == nil && all[3].nowChip == "Press now")
  }

  @Test func dripMachineFillsStartsAndWaits() throws {
    let all = try cues(
      [("pour", 0, 850), ("brew", 15, nil), ("wait", 330, nil)], total: 360,
      method: "drip-machine")
    #expect(
      all.map(\.title) == [
        "Fill the reservoir with 850 g of water", "Start the machine",
        "Hands off. Wait until it stops dripping",
      ])
    #expect(all[1].waitTitle == "Hands off. Let the machine brew")
  }

  /// Every built-in recipe reads as plain commands: no bare step names and no empty
  /// lines. With `docs/design/brew-timer/.capture` present it also writes the whole
  /// script, method by method, for review.
  @Test func everyBuiltInRecipeReadsAsCommands() throws {
    let content = try BuiltInContent()
    let names = Dictionary(uniqueKeysWithValues: content.methods.map { ($0.key, $0.name) })
    var script = "# What the brew timer says, step by step\n"
    for method in content.methods {
      script += "\n## \(method.name)\n"
      for recipe in content.recipes where recipe.methodKey == method.key {
        let steps = recipe.steps.enumerated().map { index, step in
          TimerStep(
            order: index, label: RecipeFormat.title(step.kind), instruction: step.instruction,
            startOffsetS: step.startOffsetS, targetCumulativeWaterG: step.targetCumulativeWaterG)
        }
        let last = steps.map(\.startOffsetS).max() ?? 0
        let plan = try TimerPlan(
          steps: steps, totalDurationS: max(recipe.totalTimeS ?? 0, last + 30))
        let cues = StepCue.cues(
          plan: plan, kinds: recipe.steps.map(\.kind.rawValue), method: recipe.methodKey,
          units: UnitPreferences())
        script += "\n### \(recipe.name)\n\n"
        for (group, cue) in zip(plan.displayGroups, cues) {
          #expect(!cue.title.isEmpty && !cue.waitTitle.isEmpty, "\(recipe.key)")
          #expect(
            !StepKind.allCases.map(RecipeFormat.title).contains(cue.title),
            "\(recipe.key) shows a bare step name: \(cue.title)")
          let at = RecipeFormat.clock(plan.steps[group[0]].startOffsetS)
          script += "- **\(at) · \(cue.title)** (\(cue.nowChip))"
          if let detail = cue.detail { script += ". \(detail)" }
          if cue.doS != nil {
            script += " Then: **\(cue.waitTitle)**"
            if let waitDetail = cue.waitDetail { script += ". \(waitDetail)" }
          }
          if let open = cue.valveOpen { script += open ? " [Valve open]" : " [Valve closed]" }
          script += "\n"
        }
      }
      #expect(names[method.key] != nil)
    }
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-timer")
    if FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path) {
      try script.write(
        to: folder.appendingPathComponent("step-script.md"), atomically: true, encoding: .utf8)
    }
  }
}
