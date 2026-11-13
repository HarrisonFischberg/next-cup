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
  /// "update" and "end" in the order they came.
  private(set) var calls: [String] = []
  func update(setup: TimerSetup, state: TimerState) {
    updates.append(state)
    calls.append("update")
  }
  func end() {
    endCount += 1
    calls.append("end")
  }
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

  /// Starts a run of `setup` that records its choices in `defaults`.
  private func startRun(
    _ setup: TimerSetup, clock: FakeClock, store: MemoryStore, defaults: UserDefaults
  ) {
    TimerSession(
      setup: setup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity(), defaults: defaults
    ).start()
  }

  @Test func aReopenedTimerGetsBackTheChoicesOfTheSameRun() throws {
    let suite = "nextcup.timertests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let (clock, store) = (FakeClock(), MemoryStore())
    let recipe = makeRecipe()
    var started = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    (started.beanID, started.beanName) = (UUID(), "Ethiopia")
    (started.grinderID, started.grindSetting) = (UUID(), "18")
    startRun(started, clock: clock, store: store, defaults: defaults)

    let reopened = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
      .withRememberedChoices(resuming: store.load(), now: clock.now(), from: defaults)
    #expect(reopened.beanID == started.beanID)
    #expect(reopened.beanName == "Ethiopia")
    #expect(reopened.grinderID == started.grinderID)
    #expect(reopened.grindSetting == "18")

    let otherDose = try TimerPlanBuilder.setup(for: recipe, doseG: 20)
      .withRememberedChoices(resuming: store.load(), now: clock.now(), from: defaults)
    #expect(otherDose.beanID == nil && otherDose.grindSetting.isEmpty)
  }

  /// Siri and a fresh link build the same setup, but with no saved run of this plan to
  /// pick up it is a new brew, so an old run's choices stay out of it.
  @Test func aFreshRunOfTheSameRecipeGetsNoRememberedChoices() throws {
    let suite = "nextcup.timertests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let (clock, store) = (FakeClock(), MemoryStore())
    let recipe = makeRecipe()
    var started = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    (started.beanID, started.grindSetting) = (UUID(), "18")
    startRun(started, clock: clock, store: store, defaults: defaults)

    let fresh = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    let noRun = fresh.withRememberedChoices(resuming: nil, now: clock.now(), from: defaults)
    #expect(noRun.beanID == nil && noRun.grindSetting.isEmpty)
    clock.advance(120 + 3601)
    let stale = fresh.withRememberedChoices(
      resuming: store.load(), now: clock.now(), from: defaults)
    #expect(stale.beanID == nil && stale.grindSetting.isEmpty)
  }

  @Test func aStartWithoutChoicesOverwritesEarlierOnes() throws {
    let suite = "nextcup.timertests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let (clock, store) = (FakeClock(), MemoryStore())
    let recipe = makeRecipe()
    var chosen = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    (chosen.beanID, chosen.grinderID, chosen.grindSetting) = (UUID(), UUID(), "18")
    startRun(chosen, clock: clock, store: store, defaults: defaults)

    // The same recipe started again from the roaster catalog, with nothing picked.
    store.clear()
    startRun(
      try TimerPlanBuilder.setup(for: recipe, doseG: 30), clock: clock, store: store,
      defaults: defaults)
    let reopened = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
      .withRememberedChoices(resuming: store.load(), now: clock.now(), from: defaults)
    #expect(reopened.beanID == nil && reopened.grinderID == nil)
    #expect(reopened.grindSetting.isEmpty)
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

  /// A 10-second stir is shown joined to the pour after it, so the cue comes once, when
  /// the screen changes, not again when the pour's own time arrives inside it.
  @Test func aShortStepJoinedOnScreenCuesOnce() throws {
    let recipe = makeRecipe()
    recipe.steps?.append(RecipeStep(order: 3, kind: .stir, startOffsetS: 30))
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 15)
    #expect(setup.plan.displayGroups.count == 3)
    let haptics = RecordingHaptics()
    let clock = FakeClock()
    let session = TimerSession(
      setup: setup, clock: clock, store: MemoryStore(), haptics: haptics,
      activity: RecordingActivity())
    session.start()
    clock.advance(31)
    session.tick()
    #expect(haptics.played == [.start, .stepChange])
    clock.advance(10)
    session.tick()
    #expect(session.state.currentIndex == 2)
    #expect(haptics.played == [.start, .stepChange], "the pour began inside the shown step")
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

  @Test func aTimerLeftRunningYesterdayIsNotPickedUp() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    let setup = try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 15)
    let first = TimerSession(
      setup: setup, clock: clock, store: store, haptics: RecordingHaptics(),
      activity: RecordingActivity())
    first.start()
    clock.advance(86_400)

    let activity = RecordingActivity()
    let second = TimerSession(
      setup: setup, clock: clock, store: store, haptics: RecordingHaptics(), activity: activity)
    #expect(second.state.phase == .notStarted)
    #expect(store.load() == nil)
    #expect(activity.endCount == 1)
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

  /// The app has one Live Activity for every session, so a run of another plan ends the
  /// first run's activity before its own first update, never pushing into it.
  @Test func aRunOfAnotherPlanEndsTheSharedActivityFirst() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    let activity = RecordingActivity()
    let first = TimerSession(
      setup: try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 15), clock: clock,
      store: store, haptics: RecordingHaptics(), activity: activity)
    first.start()

    let second = TimerSession(
      setup: try TimerPlanBuilder.setup(for: makeRecipe(), doseG: 20), clock: clock,
      store: store, haptics: RecordingHaptics(), activity: activity)
    #expect(activity.calls == ["update"], "opening another plan leaves the running brew alone")
    second.start()
    #expect(activity.calls == ["update", "end", "update"])
    second.pause()
    #expect(activity.endCount == 1)
  }

  // MARK: Live Activity

  private let linkA = URL(string: "nextcup://timer/a?dose=15")!
  private let linkB = URL(string: "nextcup://timer/b?dose=15")!

  @Test func theSameRecipeStartedAgainGetsANewActivityNotTheEndingOne() {
    let old = ActivityCandidate(id: "old", linkURL: linkA, state: .live)
    let plan = ActivityAdoption.plan(held: nil, link: linkA, listed: [old], ending: ["old"])
    #expect(plan.keep == nil && plan.request, "a new one is requested")
    #expect(plan.end.isEmpty, "already ending")
  }

  @Test func aRelaunchAdoptsTheLiveActivityOfThisRunAndEndsTheOthers() {
    let listed = [
      ActivityCandidate(id: "b", linkURL: linkB, state: .live),
      ActivityCandidate(id: "a", linkURL: linkA, state: .live),
    ]
    let plan = ActivityAdoption.plan(held: nil, link: linkA, listed: listed, ending: [])
    #expect(plan.keep == "a" && !plan.request)
    #expect(plan.end == ["b"])
  }

  /// Swiping the activity away is the person saying no: it does not come back at the
  /// next step, and stays away for the rest of that run.
  @Test func anActivityThePersonDismissedStaysGone() {
    let swiped = ActivityCandidate(id: "a", linkURL: linkA, state: .dismissed)
    let plan = ActivityAdoption.plan(held: "a", link: linkA, listed: [swiped], ending: [])
    #expect(plan.declined && !plan.request && plan.keep == nil)
    let next = ActivityAdoption.plan(
      held: nil, link: linkA, listed: [], ending: [], declined: plan.declined)
    #expect(!next.request, "the next step change requests nothing")
  }

  /// One this app ended (Delete all, or asked to end with immediate dismissal) is replaced.
  @Test func anActivityTheAppEndedIsReplaced() {
    let ended = ActivityCandidate(id: "a", linkURL: linkA, state: .ended)
    let plan = ActivityAdoption.plan(held: "a", link: linkA, listed: [ended], ending: [])
    #expect(plan.request && plan.end == ["a"])
    let ours = ActivityCandidate(id: "a", linkURL: linkA, state: .dismissed)
    #expect(ActivityAdoption.plan(held: "a", link: linkA, listed: [ours], ending: ["a"]).request)
    let live = ActivityCandidate(id: "a", linkURL: linkA, state: .live)
    #expect(ActivityAdoption.plan(held: "a", link: linkA, listed: [live], ending: []).keep == "a")
  }

  /// `end()` (the run finished, or another plan started) clears the "no", so the next run
  /// gets a fresh activity.
  @Test func aNewRunAfterADismissalGetsAFreshActivity() {
    let swiped = ActivityCandidate(id: "a", linkURL: linkA, state: .dismissed)
    let plan = ActivityAdoption.plan(
      held: nil, link: linkB, listed: [swiped], ending: ["a"], declined: false)
    #expect(plan.request && !plan.declined)
  }

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

  /// Two steps at 0:00 are one displayed step, on the Lock Screen as on the timer screen.
  @Test func activityCountsStepsThatStartTogetherAsOne() throws {
    let recipe = makeRecipe()
    let close = RecipeStep(order: 0, kind: .closeValve, startOffsetS: 0)
    recipe.steps?.append(close)
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 15)
    let session = TimerSession(
      setup: setup, clock: FakeClock(), store: MemoryStore(), haptics: RecordingHaptics(),
      activity: RecordingActivity())
    session.start()
    let content = try #require(
      TimerActivityAttributes.ContentState(state: session.state, plan: setup.plan, now: Date()))
    #expect(content.stepNumber == 1)
    #expect(TimerActivityAttributes(setup: setup).stepCount == 3)
  }

  @Test func activityLinkReopensTheTimerAtTheScaledDose() throws {
    let recipe = makeRecipe()
    let setup = try TimerPlanBuilder.setup(for: recipe, doseG: 30)
    let attributes = TimerActivityAttributes(setup: setup)
    #expect(DeepLink(url: attributes.linkURL) == .timer(recipeID: recipe.id, doseG: 30))
    #expect(attributes.stepCount == 3)
  }
}
