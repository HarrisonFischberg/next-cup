import NextCupKit
import Observation
import SwiftUI
import UIKit

enum TimerHaptic: Equatable {
  case start
  case stepChange
  case targetReached
  case pauseToggle
  case finish
}

@MainActor
protocol TimerHaptics {
  func play(_ haptic: TimerHaptic)
}

/// Haptics only for events that matter: start, a step change, pause or resume, and the end.
/// A step change or the target time also plays a short sound when the brew's sound is on;
/// both are reminders of the schedule, never confirmation that anything was done.
@MainActor
struct SystemTimerHaptics: TimerHaptics {
  static let soundKey = "nextcup.timer.sound"

  func play(_ haptic: TimerHaptic) {
    switch haptic {
    case .start, .pauseToggle: Feedback.tap()
    case .stepChange, .targetReached:
      Feedback.stepChange()
      BrewAudio.shared.chime()
    case .finish: Feedback.success()
    }
  }
}

/// Clock and storage for the running timer. UI tests can speed the clock up with
/// `-timerSpeed <n>` in debug builds, so a three-minute recipe finishes in seconds;
/// screenshots hold it still at a chosen second with `-timerHoldAt <s>`.
@MainActor
enum TimerEnvironment {
  static let clock: any TimerClock = {
    #if DEBUG
      if HeldTimerClock.holdAt != nil { return HeldTimerClock() }
      let arguments = ProcessInfo.processInfo.arguments
      if let index = arguments.firstIndex(of: "-timerSpeed"), index + 1 < arguments.count,
        let speed = Double(arguments[index + 1]), speed > 0
      {
        return AcceleratedTimerClock(speed: speed)
      }
    #endif
    return SystemTimerClock()
  }()

  /// UI tests never start a real Live Activity.
  static let activity: any TimerActivityControlling = {
    AppBootstrap.usesInMemoryStore
      ? NoTimerActivity() as any TimerActivityControlling : LiveTimerActivity()
  }()

  /// An in-memory run (UI tests) never touches the real saved timer.
  static let stateStore: any TimerStateStore = {
    AppBootstrap.usesInMemoryStore
      ? UserDefaultsTimerStateStore(suiteName: "nextcup.inmemory.timer.\(UUID().uuidString)")
      : UserDefaultsTimerStateStore()
  }()
}

#if DEBUG
  /// A clock that stands still, so a screenshot shows the same second every time.
  struct HeldTimerClock: TimerClock {
    static let holdAt: Double? = {
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "-timerHoldAt"), index + 1 < arguments.count
      else { return nil }
      return Double(arguments[index + 1])
    }()
    nonisolated(unsafe) static var offset = 0.0
    private let origin = Date()
    func now() -> Date { origin.addingTimeInterval(Self.offset) }
  }

  struct AcceleratedTimerClock: TimerClock {
    let speed: Double
    private let origin = Date()
    init(speed: Double) { self.speed = speed }
    func now() -> Date { origin.addingTimeInterval(Date().timeIntervalSince(origin) * speed) }
  }
#endif

/// How a run ended: the elapsed time reached and whether it was cut short.
struct TimerOutcome: Equatable {
  let elapsedS: Double
  let endedEarly: Bool
}

/// Drives one `TimerEngine` for the screen. All time comes from the engine's
/// persisted dates, so coming back from the background needs only a `tick()`.
@MainActor
@Observable
final class TimerSession {
  let setup: TimerSetup
  private(set) var state: TimerState
  private(set) var outcome: TimerOutcome?

  @ObservationIgnored private var engine: TimerEngine
  @ObservationIgnored private let haptics: any TimerHaptics
  /// The displayed step last cued. Short steps joined into one on screen cue once, when
  /// the screen changes, not again as each passes inside it.
  @ObservationIgnored private var lastIndex: Int?
  @ObservationIgnored private let activity: any TimerActivityControlling
  /// A run of another plan was saved when this one opened: its Live Activity goes when this
  /// run starts, not before, so backing out without starting leaves that brew on the Lock Screen.
  @ObservationIgnored private var replacesOtherRun = false
  /// Where each start records its Start brew choices for a reopened timer.
  @ObservationIgnored private let defaults: UserDefaults

  /// A run begun over an hour past its target ago was left behind (screen left, app
  /// killed), not paused for a moment: the same recipe today is a new brew.
  nonisolated static func isStale(_ run: TimerSnapshot, now: Date) -> Bool {
    now.timeIntervalSince(run.startedAt) > Double(run.plan.totalDurationS) + 3600
  }

  /// Picks up the saved timer when it belongs to this same plan; otherwise starts clean.
  init(
    setup: TimerSetup, clock: any TimerClock = TimerEnvironment.clock,
    store: any TimerStateStore = TimerEnvironment.stateStore,
    haptics: any TimerHaptics = SystemTimerHaptics(),
    activity: any TimerActivityControlling = TimerEnvironment.activity,
    defaults: UserDefaults = .standard
  ) {
    self.setup = setup
    self.haptics = haptics
    self.activity = activity
    self.defaults = defaults
    let saved = store.load()
    let stale = saved.map { Self.isStale($0, now: clock.now()) } ?? false
    if saved?.plan == setup.plan, !stale,
      let restored = TimerEngine.restore(clock: clock, store: store)
    {
      engine = restored
    } else {
      if stale {
        store.clear()
        activity.end()
      } else {
        replacesOtherRun = saved != nil
      }
      engine = TimerEngine(plan: setup.plan, clock: clock, store: store)
    }
    state = engine.state()
    lastIndex = group(state)
    if case .finished = state.phase {
      complete(state)
    } else if state.phase != .notStarted {
      activity.update(setup: setup, state: state)
    }
  }

  // MARK: Controls

  func start() {
    guard state.phase == .notStarted else { return }
    if replacesOtherRun {
      activity.end()
      replacesOtherRun = false
    }
    engine.start()
    // Every start overwrites, so a run begun without choices never inherits older ones.
    setup.rememberChoices(in: defaults)
    haptics.play(.start)
    refresh()
    lastIndex = group(state)
  }

  func pause() {
    guard state.phase == .running else { return }
    engine.pause()
    haptics.play(.pauseToggle)
    refresh()
  }

  func resume() {
    guard state.phase == .paused else { return }
    engine.resume()
    haptics.play(.pauseToggle)
    refresh()
  }

  func skipToNextStep() {
    engine.skipToNextStep()
    tick()
  }

  func endEarly() {
    engine.endEarly()
    tick()
  }

  /// Ends the brew at the time reached, so the journal gets the actual duration.
  func finish() {
    engine.finish()
    tick()
  }

  /// Re-derives the state from the clock. Called on a short timer and on returning to the
  /// foreground; `cues: false` catches up without replaying the cues that were missed.
  func tick(cues: Bool = true) {
    guard outcome == nil else { return }
    let latest = engine.state()
    if case .finished = latest.phase {
      complete(latest)
      return
    }
    if cues, state.phase != .notStarted {
      if let index = group(latest), index != lastIndex, lastIndex != nil {
        haptics.play(.stepChange)
      } else if latest.targetReached, !state.targetReached {
        haptics.play(.targetReached)
      }
    }
    lastIndex = group(latest)
    publish(latest)
  }

  /// How long the screen waits before its next `tick()`: a quarter second at most, but never
  /// past the start of the brew's next whole second, so each second shows the moment it
  /// begins and stays up a full second.
  func nextTickDelay() -> Double {
    let latest = engine.state()
    return latest.phase == .running ? Self.delay(toNextSecondFrom: latest.elapsedS) : 0.25
  }

  /// A few milliseconds past the boundary, so the tick lands on the new second, not just before it.
  nonisolated static func delay(toNextSecondFrom elapsedS: Double) -> Double {
    min(elapsedS.rounded(.down) + 1 - elapsedS + 0.005, 0.25)
  }

  // MARK: Private

  private func group(_ state: TimerState) -> Int? {
    state.currentIndex.flatMap { setup.plan.groupIndex(ofStep: $0) }
  }

  private func refresh() {
    let latest = engine.state()
    if case .finished = latest.phase { complete(latest) } else { publish(latest) }
  }

  /// Only whole-second, step and phase changes reach the view, so it redraws once a second.
  /// The Live Activity hears only about phase and step changes; its clock runs itself.
  private func publish(_ latest: TimerState) {
    let moved =
      latest.phase != state.phase || latest.currentIndex != state.currentIndex
      || latest.targetReached != state.targetReached
    if moved || Int(latest.elapsedS) != Int(state.elapsedS) { state = latest }
    if moved { activity.update(setup: setup, state: latest) }
  }

  private func complete(_ finished: TimerState) {
    guard outcome == nil else { return }
    var early = false
    if case .finished(let endedEarly) = finished.phase { early = endedEarly }
    state = finished
    outcome = TimerOutcome(elapsedS: finished.elapsedS, endedEarly: early)
    haptics.play(.finish)
    activity.end()
    engine.discard()
  }
}
