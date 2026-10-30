import Foundation
import NextCupKit
import Testing

@testable import NextCup

private final class FakeClock: TimerClock, @unchecked Sendable {
  private let lock = NSLock()
  private var current: Date
  init(_ start: Date = Date(timeIntervalSince1970: 1_000_000)) { current = start }
  func now() -> Date { lock.withLock { current } }
  func advance(_ seconds: Double) {
    lock.withLock { current = current.addingTimeInterval(seconds) }
  }
}

private final class MemoryStore: TimerStateStore, @unchecked Sendable {
  private let lock = NSLock()
  private var saved: TimerSnapshot?
  func save(_ snapshot: TimerSnapshot) { lock.withLock { saved = snapshot } }
  func load() -> TimerSnapshot? { lock.withLock { saved } }
  func clear() { lock.withLock { saved = nil } }
}

@MainActor
private final class RecordingHaptics: TimerHaptics {
  private(set) var played: [TimerHaptic] = []
  func play(_ haptic: TimerHaptic) { played.append(haptic) }
}

@MainActor
private final class RecordingActivity: TimerActivityControlling {
  private(set) var updates: [TimerState] = []
  private(set) var endCount = 0
  func update(setup: TimerSetup, state: TimerState) { updates.append(state) }
  func end() { endCount += 1 }
}

@MainActor
@Suite("TimerSession")
struct TimerSessionTests {
  private func makeRecipe(total: Int? = 120) -> Recipe {
    let recipe = Recipe(name: "Test cone", doseG: 15, waterG: 250)
    recipe.totalTimeS = total
    recipe.tempC = 94
    let bloom = RecipeStep(order: 0, kind: .bloom, startOffsetS: 0)
    bloom.targetCumulativeWaterG = 45
    bloom.instruction = "Wet the bed"
    let pour = RecipeStep(order: 1, kind: .pour, startOffsetS: 40)
    pour.targetCumulativeWaterG = 250
    pour.instruction = "Pour to 250 g at 94 °C."
    let drawdown = RecipeStep(order: 2, kind: .drawdown, startOffsetS: 90)
    recipe.steps = [pour, drawdown, bloom]
    return recipe
  }

  private func makeSession(
    total: Int? = 120, dose: Double = 15, clock: FakeClock = FakeClock(),
    store: MemoryStore = MemoryStore(), haptics: RecordingHaptics = RecordingHaptics(),
    activity: RecordingActivity = RecordingActivity()
  ) throws -> (TimerSession, FakeClock, MemoryStore, RecordingHaptics) {
    let setup = try TimerPlanBuilder.setup(for: makeRecipe(total: total), doseG: dose)
    return (
      TimerSession(
        setup: setup, clock: clock, store: store, haptics: haptics, activity: activity),
      clock, store, haptics
    )
  }

  // MARK: Plan

  @Test func planFollowsStepOrderAndScalesTargets() throws {
    let setup = try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 30)
    #expect(setup.plan.steps.map(\.label) == ["Bloom", "Pour", "Drawdown"])
    #expect(setup.plan.steps.map(\.startOffsetS) == [0, 40, 90])
    #expect(setup.plan.steps.map(\.targetCumulativeWaterG) == [90, 500, nil])
    #expect(setup.plan.totalDurationS == 120)
    #expect(setup.scaled.doseG == 30)
    #expect(setup.plan.steps[1].instruction == "Pour to 500 g at 94 °C.")
    #expect(setup.plan.steps[0].instruction == "Wet the bed")
  }

  @Test func stepWeightsInTheTextFollowTheDose() {
    #expect(
      TimerPlanBuilder.scaledWeights(in: "Pour to 500 g in the centre.", by: 0.806)
        == "Pour to 403 g in the centre.")
    #expect(
      TimerPlanBuilder.scaledWeights(in: "Stop at 36g, about 30 s.", by: 0.5)
        == "Stop at 18g, about 30 s.")
    #expect(TimerPlanBuilder.scaledWeights(in: "Pour to 500 g.", by: 1) == "Pour to 500 g.")
  }

  @Test func planAddsATailWhenTheRecipeGivesNoUsableTotal() throws {
    #expect(
      try TimerPlanBuilder.setup(for: makeRecipe(total: nil), doseG: 15).plan.totalDurationS == 120)
    #expect(
      try TimerPlanBuilder.setup(for: makeRecipe(total: 60), doseG: 15).plan.totalDurationS == 120)
  }

  @Test func recipeWithoutStepsCannotBeTimed() {
    let empty = Recipe(name: "Empty", doseG: 15, waterG: 250)
    #expect(throws: TimerPlanError.noSteps) { try TimerPlanBuilder.setup(for: empty, doseG: 15) }
  }

  // MARK: Ticking

  @Test func tickWaitsForTheNextWholeSecondAtMostAQuarterSecond() {
    #expect(abs(TimerSession.delay(toNextSecondFrom: 4.9) - 0.105) < 1e-9)
    #expect(abs(TimerSession.delay(toNextSecondFrom: 4.999) - 0.006) < 1e-9)
    #expect(TimerSession.delay(toNextSecondFrom: 4.0) == 0.25)
    #expect(TimerSession.delay(toNextSecondFrom: 4.3) == 0.25)
  }

  /// The screen's loop: tick, then wait `nextTickDelay()`. Every second must show within a
  /// few milliseconds of starting, so the readout and its countdown change a full second apart.
  @Test func eachSecondShowsAsItStarts() throws {
    let (session, clock, _, _) = try makeSession()
    session.start()
    clock.advance(0.37)  // the screen's first tick never lands on a boundary
    var now = 0.37
    var shownAt: [Int: Double] = [:]
    while now < 30 {
      session.tick()
      let second = Int(session.state.elapsedS)
      if shownAt[second] == nil { shownAt[second] = now }
      let wait = session.nextTickDelay()
      clock.advance(wait)
      now += wait
    }
    for second in 1..<30 {
      let late = try #require(shownAt[second]) - Double(second)
      #expect(late >= 0 && late < 0.01, "second \(second) showed \(late)s late")
    }
  }

  // MARK: Running

  @Test func runsEndToEndAndHandsOverTheTimeReached() throws {
    let (session, clock, store, haptics) = try makeSession()
    #expect(session.state.phase == .notStarted)
    session.start()
    #expect(session.state.currentIndex == 0)
    clock.advance(41)
    session.tick()
    #expect(session.state.currentIndex == 1)
    clock.advance(50)
    session.tick()
    #expect(session.state.currentIndex == 2)
    clock.advance(30)
    session.tick()
    #expect(session.outcome == nil, "reaching the target keeps the brew running")
    #expect(session.state.targetReached)
    clock.advance(15)
    session.tick()
    session.finish()
    #expect(session.outcome == TimerOutcome(elapsedS: 136, endedEarly: false))
    #expect(session.setup.seed(elapsedS: 136, endedEarly: false).totalTimeS == 136)
    #expect(haptics.played == [.start, .stepChange, .stepChange, .targetReached, .finish])
    #expect(store.load() == nil, "the saved timer is forgotten once the form has the values")
  }

  @Test func pauseStopsTimeAndResumeContinues() throws {
    let (session, clock, _, haptics) = try makeSession()
    session.start()
    clock.advance(10)
    session.pause()
    clock.advance(600)
    session.tick()
    #expect(session.state.phase == .paused)
    #expect(Int(session.state.elapsedS) == 10)
    session.resume()
    clock.advance(5)
    session.tick()
    #expect(Int(session.state.elapsedS) == 15)
    #expect(haptics.played == [.start, .pauseToggle, .pauseToggle])
  }

  @Test func foregroundCatchUpDoesNotReplayMissedCues() throws {
    let (session, clock, _, haptics) = try makeSession()
    session.start()
    clock.advance(200)
    session.tick(cues: false)
    #expect(session.state.currentIndex == 2)
    #expect(session.state.targetReached)
    #expect(haptics.played == [.start])
  }

  @Test func skipJumpsToTheNextStepWithOneHaptic() throws {
    let (session, _, _, haptics) = try makeSession()
    session.start()
    session.skipToNextStep()
    #expect(session.state.currentIndex == 1)
    #expect(haptics.played == [.start, .stepChange])
  }

  @Test func endEarlyKeepsTheElapsedTime() throws {
    let (session, clock, _, haptics) = try makeSession()
    session.start()
    clock.advance(55)
    session.endEarly()
    #expect(session.outcome == TimerOutcome(elapsedS: 55, endedEarly: true))
    #expect(haptics.played.last == .finish)
  }

  @Test func returningFromTheBackgroundCatchesUpWithOneStepHaptic() throws {
    let (session, clock, _, haptics) = try makeSession()
    session.start()
    clock.advance(95)  // app was backgrounded across two step changes
    session.tick()
    #expect(session.state.currentIndex == 2)
    #expect(haptics.played == [.start, .stepChange])
  }

  @Test func ticksWithoutAChangeNeverPlayHaptics() throws {
    let (session, clock, _, haptics) = try makeSession()
    session.start()
    for _ in 0..<5 {
      clock.advance(1)
      session.tick()
    }
    #expect(haptics.played == [.start])
  }

  // MARK: Restore

  @Test func aSessionForTheSamePlanPicksUpWhereTheLastOneStopped() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    let setup = try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 15)
    let first = TimerSession(
      setup: setup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity())
    first.start()
    clock.advance(45)

    let second = TimerSession(
      setup: setup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity())
    #expect(second.state.phase == .running)
    #expect(second.state.currentIndex == 1)
  }

  @Test func aSavedTimerForAnotherPlanIsNotAdopted() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    let firstSetup = try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 15)
    let first = TimerSession(
      setup: firstSetup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity())
    first.start()

    let otherSetup = try TimerPlanBuilder.setup(for: makeRecipe(total: 200), doseG: 15)
    let second = TimerSession(
      setup: otherSetup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity())
    #expect(second.state.phase == .notStarted)
  }

  // MARK: Live Activity

  @Test func activityHearsStartPauseResumeAndStepChangesThenEnds() throws {
    let activity = RecordingActivity()
    let (session, clock, _, _) = try makeSession(activity: activity)
    session.tick()
    #expect(activity.updates.isEmpty, "nothing to show before the start")
    session.start()
    clock.advance(10)
    session.tick()
    #expect(activity.updates.count == 1, "plain seconds never reach the activity")
    session.pause()
    session.resume()
    clock.advance(31)
    session.tick()
    #expect(
      activity.updates.map(\.phase) == [.running, .paused, .running, .running])
    #expect(activity.updates.last?.currentIndex == 1)
    #expect(activity.endCount == 0)
    session.endEarly()
    #expect(activity.endCount == 1)
  }

  @Test func contentStateCountsFromTheVirtualStartAndFreezesWhilePaused() throws {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let (session, clock, _, _) = try makeSession()
    session.start()
    clock.advance(50)
    session.tick()
    let running = try #require(TimerActivityAttributes.ContentState(state: session.state, now: now))
    #expect(running.startDate == now.addingTimeInterval(-50))
    #expect(running.endDate == running.startDate.addingTimeInterval(120))
    #expect(running.pausedAt == nil)
    #expect(running.stepLabel == "Pour")
    #expect(running.nextLabel == "Drawdown")
    #expect(running.stepNumber == 2)

    session.pause()
    let paused = try #require(TimerActivityAttributes.ContentState(state: session.state, now: now))
    #expect(paused.pausedAt == now)

    session.endEarly()
    #expect(TimerActivityAttributes.ContentState(state: session.state, now: now) == nil)
  }

  @Test func activityLinkReopensTheTimerAtTheScaledDose() throws {
    let recipe = makeRecipe()
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    let attributes = TimerActivityAttributes(setup: setup)
    #expect(DeepLink(url: attributes.linkURL) == .timer(recipeID: recipe.id, doseG: 30))
    #expect(attributes.stepCount == 3)
  }
}
