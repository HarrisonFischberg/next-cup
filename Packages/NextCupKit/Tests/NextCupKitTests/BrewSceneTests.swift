import Testing

@testable import NextCupKit

struct BrewSceneTests {
  private func steps(_ pairs: [(Double, String)]) -> [BrewSceneStep] {
    pairs.map { BrewSceneStep(startS: $0.0, kind: $0.1) }
  }

  private let cone = [(0.0, "bloom"), (45, "pour"), (75, "pour"), (105, "drawdown")]

  @Test func builtInKeysAndStylesPickTheirScene() {
    #expect(BrewSceneKind(methodKey: "inverted-press", style: "immersion") == .inverted)
    #expect(BrewSceneKind(methodKey: "iced-pour-over", style: "cold") == .pourOver)
    #expect(BrewSceneKind(methodKey: nil, style: "immersion") == .press)
    #expect(BrewSceneKind(methodKey: "my-own", style: "espresso") == .espresso)
    #expect(BrewSceneKind(methodKey: nil, style: nil) == .pourOver)
  }

  @Test func nothingMovesBeforeTheStart() {
    let f = BrewScene.frame(.pourOver, steps: steps(cone), totalS: 180, elapsedS: 0)
    #expect(f == BrewSceneFrame())
  }

  @Test func kettleTipsOnlyDuringTheFirstPartOfAPour() {
    let s = steps(cone)
    #expect(BrewScene.frame(.pourOver, steps: s, totalS: 180, elapsedS: 50).pouring)
    #expect(!BrewScene.frame(.pourOver, steps: s, totalS: 180, elapsedS: 72).pouring)
    #expect(!BrewScene.frame(.pourOver, steps: s, totalS: 180, elapsedS: 120).kettleShown)
  }

  @Test func pourOverFillsTheServerAndEmptiesTheBed() {
    let s = steps(cone)
    let mid = BrewScene.frame(.pourOver, steps: s, totalS: 180, elapsedS: 90)
    let end = BrewScene.frame(.pourOver, steps: s, totalS: 180, elapsedS: 180)
    #expect(mid.bed == 1 && mid.dripping)
    #expect(end.bed == 0 && !end.dripping)
    #expect(end.vessel > mid.vessel)
  }

  @Test func switchableHoldsWaterUntilTheValveOpens() {
    let s = steps([(0, "closeValve"), (5, "pour"), (30, "stir"), (40, "wait"), (120, "openValve"), (150, "drawdown")])
    let steep = BrewScene.frame(.switchable, steps: s, totalS: 210, elapsedS: 80)
    #expect(steep.bed == 1 && !steep.dripping && steep.vessel == 0 && steep.lidOn)
    let release = BrewScene.frame(.switchable, steps: s, totalS: 210, elapsedS: 140)
    #expect(release.dripping && release.vessel > 0 && !release.lidOn)
  }

  @Test func pressPlungesOnlyOnThePressStep() {
    let s = steps([(0, "pour"), (20, "stir"), (30, "wait"), (240, "press")])
    #expect(BrewScene.frame(.press, steps: s, totalS: 270, elapsedS: 100).plunger == 0)
    #expect(BrewScene.frame(.press, steps: s, totalS: 270, elapsedS: 255).plunger == 0.5)
    #expect(BrewScene.frame(.press, steps: s, totalS: 270, elapsedS: 300).plunger == 1)
    #expect(BrewScene.frame(.press, steps: s, totalS: 270, elapsedS: 100).steeping)
  }

  @Test func invertedPressFlipsHalfwayThroughTheInvertStep() {
    let s = steps([(0, "plug"), (5, "pour"), (25, "stir"), (35, "wait"), (90, "invert"), (100, "press")])
    #expect(BrewScene.frame(.inverted, steps: s, totalS: 130, elapsedS: 60).inverted)
    #expect(BrewScene.frame(.inverted, steps: s, totalS: 130, elapsedS: 94).inverted)
    #expect(!BrewScene.frame(.inverted, steps: s, totalS: 130, elapsedS: 96).inverted)
    let pressing = BrewScene.frame(.inverted, steps: s, totalS: 130, elapsedS: 115)
    #expect(pressing.plunger == 0.5 && pressing.vessel == 0.5)
  }

  @Test func espressoBuildsPressureThenPulls() {
    let s = steps([(0, "pour"), (8, "wait")])
    #expect(BrewScene.frame(.espresso, steps: s, totalS: 28, elapsedS: 3).pressureBar == 3)
    let pulling = BrewScene.frame(.espresso, steps: s, totalS: 28, elapsedS: 17)
    #expect(pulling.pressureBar == 9 && pulling.shot && !pulling.pouring)
    let done = BrewScene.frame(.espresso, steps: s, totalS: 28, elapsedS: 28)
    #expect(done.vessel == 1 && !done.shot && done.pressureBar == 0)
  }

  @Test func coldBrewDarkensOverTheSteep() {
    let s = steps([(0, "pour"), (60, "stir"), (120, "wait")])
    let f = BrewScene.frame(.cold, steps: s, totalS: 57600, elapsedS: 28800)
    #expect(f.bed == 1 && f.darkness == 0.5)
  }
}
