import Foundation
import Testing

@testable import NextCupKit

private final class FakeClock: TimerClock, @unchecked Sendable {
  private let lock = NSLock()
  private var current: Date

  init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { current = start }

  func now() -> Date {
    lock.lock()
    defer { lock.unlock() }
    return current
  }

  func advance(_ seconds: Double) {
    lock.lock()
    defer { lock.unlock() }
    current = current.addingTimeInterval(seconds)
  }
}

private final class MemoryStore: TimerStateStore, @unchecked Sendable {
  private let lock = NSLock()
  private var saved: TimerSnapshot?
  private(set) var saveCount = 0

  func save(_ snapshot: TimerSnapshot) {
    lock.lock()
    defer { lock.unlock() }
    saved = snapshot
    saveCount += 1
  }

  func load() -> TimerSnapshot? {
    lock.lock()
    defer { lock.unlock() }
    return saved
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    saved = nil
  }
}

private func makePlan() throws -> TimerPlan {
  try TimerPlan(
    steps: [
      TimerStep(order: 0, label: "Bloom", startOffsetS: 0, targetCumulativeWaterG: 45),
      TimerStep(order: 1, label: "Pour", startOffsetS: 45, targetCumulativeWaterG: 250),
      TimerStep(order: 2, label: "Drawdown", startOffsetS: 120),
    ],
    totalDurationS: 180)
}

@Suite struct TimerPlanTests {
  @Test func rejectsEmptyNegativeAndShortPlans() {
    #expect(throws: TimerPlanError.noSteps) { try TimerPlan(steps: [], totalDurationS: 10) }
    #expect(throws: TimerPlanError.negativeOffset) {
      try TimerPlan(steps: [TimerStep(order: 0, label: "A", startOffsetS: -1)], totalDurationS: 10)
    }
    #expect(throws: TimerPlanError.totalNotAfterLastStep) {
      try TimerPlan(steps: [TimerStep(order: 0, label: "A", startOffsetS: 10)], totalDurationS: 10)
    }
  }

  @Test func sortsStepsByOffset() throws {
    let plan = try TimerPlan(
      steps: [
        TimerStep(order: 1, label: "B", startOffsetS: 30),
        TimerStep(order: 0, label: "A", startOffsetS: 0),
      ], totalDurationS: 60)
    #expect(plan.steps.map(\.label) == ["A", "B"])
  }
}

@Suite struct TimerEngineTests {
  private func engine(
    clock: FakeClock = FakeClock(), store: MemoryStore = MemoryStore()
  ) throws -> (TimerEngine, FakeClock, MemoryStore) {
    (TimerEngine(plan: try makePlan(), clock: clock, store: store), clock, store)
  }

  @Test func notStartedShowsFirstStepAsNext() throws {
    let (engine, _, store) = try engine()
    let state = engine.state()
    #expect(state.phase == .notStarted)
    #expect(state.current == nil)
    #expect(state.next?.label == "Bloom")
    #expect(store.load() == nil)
  }

  @Test func stepsChangeAtTheirOffsets() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    #expect(engine.state().current?.label == "Bloom")
    #expect(engine.state().next?.label == "Pour")
    #expect(engine.state().secondsToNextChange == 45)

    clock.advance(44.5)
    #expect(engine.state().current?.label == "Bloom")
    clock.advance(0.5)
    let pour = engine.state()
    #expect(pour.current?.label == "Pour")
    #expect(pour.currentIndex == 1)
    #expect(pour.secondsIntoStep == 0)
    #expect(pour.secondsToNextChange == 75)

    clock.advance(75)
    let last = engine.state()
    #expect(last.current?.label == "Drawdown")
    #expect(last.next == nil)
    #expect(last.secondsToNextChange == 60)
  }

  @Test func finishesWhenThePlanRunsOut() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(500)
    let state = engine.state()
    #expect(state.phase == .finished(endedEarly: false))
    #expect(state.elapsedS == 180)
    #expect(state.current == nil)
  }

  @Test func pauseFreezesElapsedAndResumeContinues() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(30)
    engine.pause()
    clock.advance(600)
    let frozen = engine.state()
    #expect(frozen.phase == .paused)
    #expect(frozen.elapsedS == 30)

    engine.resume()
    #expect(engine.state().phase == .running)
    clock.advance(20)
    #expect(engine.state().elapsedS == 50)
    #expect(engine.state().current?.label == "Pour")
  }

  @Test func multiplePausesAccumulate() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(10)
    engine.pause()
    clock.advance(100)
    engine.resume()
    clock.advance(10)
    engine.pause()
    clock.advance(100)
    engine.resume()
    clock.advance(10)
    #expect(engine.state().elapsedS == 30)
  }

  @Test func controlsIgnoreWrongPhases() throws {
    var (engine, clock, store) = try engine()
    engine.pause()
    engine.resume()
    engine.skipToNextStep()
    engine.endEarly()
    #expect(engine.state().phase == .notStarted)
    #expect(store.saveCount == 0)

    engine.start()
    engine.resume()
    clock.advance(5)
    engine.start()
    #expect(engine.state().elapsedS == 5)
  }

  @Test func skipJumpsToTheNextStepOffset() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(10)
    engine.skipToNextStep()
    let pour = engine.state()
    #expect(pour.current?.label == "Pour")
    #expect(pour.elapsedS == 45)

    clock.advance(5)
    #expect(engine.state().elapsedS == 50)
    engine.skipToNextStep()
    #expect(engine.state().current?.label == "Drawdown")
    #expect(engine.state().elapsedS == 120)
  }

  @Test func skipWhilePausedStaysPaused() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(10)
    engine.pause()
    engine.skipToNextStep()
    clock.advance(300)
    let state = engine.state()
    #expect(state.phase == .paused)
    #expect(state.elapsedS == 45)
    engine.resume()
    clock.advance(1)
    #expect(engine.state().elapsedS == 46)
  }

  @Test func skipOnTheLastStepFinishesNormally() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(130)
    engine.skipToNextStep()
    #expect(engine.state().phase == .finished(endedEarly: false))
    #expect(engine.state().elapsedS == 180)
  }

  @Test func endEarlyKeepsTheElapsedTime() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(95)
    engine.endEarly()
    clock.advance(1000)
    let state = engine.state()
    #expect(state.phase == .finished(endedEarly: true))
    #expect(state.elapsedS == 95)
    engine.pause()
    #expect(engine.state().phase == .finished(endedEarly: true))
  }

  @Test func restoreAfterTerminationContinuesFromWallClock() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    var original = TimerEngine(plan: try makePlan(), clock: clock, store: store)
    original.start()
    clock.advance(20)
    original.pause()
    clock.advance(10)
    original.resume()
    clock.advance(30)  // app is terminated here: 50 s of brewing so far

    clock.advance(10)  // time passes while the app is not running
    let restored = try #require(TimerEngine.restore(clock: clock, store: store))
    let state = restored.state()
    #expect(state.phase == .running)
    #expect(state.elapsedS == 60)
    #expect(state.current?.label == "Pour")
    #expect(restored.plan == original.plan)
  }

  @Test func restoreKeepsAPauseThatWasOpen() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    var original = TimerEngine(plan: try makePlan(), clock: clock, store: store)
    original.start()
    clock.advance(25)
    original.pause()
    clock.advance(3600)
    let restored = try #require(TimerEngine.restore(clock: clock, store: store))
    #expect(restored.state().phase == .paused)
    #expect(restored.state().elapsedS == 25)
  }

  @Test func restoreKeepsSkipsAndEarlyEnds() throws {
    let clock = FakeClock()
    let store = MemoryStore()
    var original = TimerEngine(plan: try makePlan(), clock: clock, store: store)
    original.start()
    clock.advance(5)
    original.skipToNextStep()
    clock.advance(10)
    let afterSkip = try #require(TimerEngine.restore(clock: clock, store: store))
    #expect(afterSkip.state().elapsedS == 55)

    original.endEarly()
    let afterEnd = try #require(TimerEngine.restore(clock: clock, store: store))
    #expect(afterEnd.state().phase == .finished(endedEarly: true))
    #expect(afterEnd.state().elapsedS == 55)
  }

  @Test func restoreWithNothingStoredIsNil() {
    #expect(TimerEngine.restore(clock: FakeClock(), store: MemoryStore()) == nil)
  }

  @Test func discardClearsThePersistedTimer() throws {
    var (engine, _, store) = try engine()
    engine.start()
    engine.discard()
    #expect(store.load() == nil)
    #expect(engine.state().phase == .notStarted)
  }

  @Test func clockMovingBackwardsNeverGoesNegative() throws {
    var (engine, clock, _) = try engine()
    engine.start()
    clock.advance(-60)
    #expect(engine.state().elapsedS == 0)
    #expect(engine.state().phase == .running)
  }
}

@Suite struct UserDefaultsTimerStateStoreTests {
  private let suite = "nextcup.tests.timer"

  @Test func roundTripsAndDiscardsCorruptData() throws {
    let store = UserDefaultsTimerStateStore(suiteName: suite, key: "snapshot")
    store.clear()
    #expect(store.load() == nil)

    let clock = FakeClock()
    var engine = TimerEngine(plan: try makePlan(), clock: clock, store: store)
    engine.start()
    clock.advance(12)
    engine.pause()
    let restored = try #require(TimerEngine.restore(clock: clock, store: store))
    #expect(restored.state().elapsedS == 12)

    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.set(Data("not json".utf8), forKey: "snapshot")
    #expect(store.load() == nil)
    #expect(defaults.data(forKey: "snapshot") == nil)
    defaults.removePersistentDomain(forName: suite)
  }
}
