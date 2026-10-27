import Foundation

/// Source of wall-clock time. Injected so tests can drive the timer without waiting.
public protocol TimerClock: Sendable {
  func now() -> Date
}

public struct SystemTimerClock: TimerClock {
  public init() {}
  public func now() -> Date { Date() }
}

/// One timeline step as the timer sees it. A step runs from its own offset to the next step's offset.
public struct TimerStep: Codable, Equatable, Sendable {
  public var order: Int
  public var label: String
  public var instruction: String
  public var startOffsetS: Int
  public var targetCumulativeWaterG: Double?

  public init(
    order: Int, label: String, instruction: String = "", startOffsetS: Int,
    targetCumulativeWaterG: Double? = nil
  ) {
    self.order = order
    self.label = label
    self.instruction = instruction
    self.startOffsetS = startOffsetS
    self.targetCumulativeWaterG = targetCumulativeWaterG
  }
}

public enum TimerPlanError: Error, Equatable, Sendable {
  case noSteps
  case negativeOffset
  case totalNotAfterLastStep
}

/// The steps of a recipe plus the moment the brew ends.
public struct TimerPlan: Codable, Equatable, Sendable {
  public let steps: [TimerStep]
  public let totalDurationS: Int

  public init(steps: [TimerStep], totalDurationS: Int) throws {
    guard !steps.isEmpty else { throw TimerPlanError.noSteps }
    let ordered = steps.sorted { ($0.startOffsetS, $0.order) < ($1.startOffsetS, $1.order) }
    guard ordered[0].startOffsetS >= 0 else { throw TimerPlanError.negativeOffset }
    guard totalDurationS > ordered[ordered.count - 1].startOffsetS else {
      throw TimerPlanError.totalNotAfterLastStep
    }
    self.steps = ordered
    self.totalDurationS = totalDurationS
  }
}

/// A pause interval; `end == nil` while still paused.
public struct TimerPause: Codable, Equatable, Sendable {
  public var start: Date
  public var end: Date?
}

/// Everything needed to rebuild a running timer after termination: dates and spans, never a counter.
public struct TimerSnapshot: Codable, Equatable, Sendable {
  public var plan: TimerPlan
  public var startedAt: Date
  public var pauses: [TimerPause]
  /// Seconds added by skipping ahead, so elapsed time jumps to the next step's offset.
  public var skippedS: Double
  /// Set when the brew was ended before the plan ran out.
  public var endedElapsedS: Double?
  public var endedEarly: Bool
}

/// Persistence for the one running timer. Saving is best effort: a failed write never stops the brew.
public protocol TimerStateStore: Sendable {
  func save(_ snapshot: TimerSnapshot)
  /// `nil` when nothing is stored or the stored data is unreadable (unreadable data is discarded).
  func load() -> TimerSnapshot?
  func clear()
}

/// Keeps the snapshot in `UserDefaults` as JSON (blueprint §5).
public struct UserDefaultsTimerStateStore: TimerStateStore {
  private let suiteName: String?
  private let key: String

  public init(suiteName: String? = nil, key: String = "nextcup.timer.snapshot") {
    self.suiteName = suiteName
    self.key = key
  }

  private var defaults: UserDefaults {
    suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
  }

  public func save(_ snapshot: TimerSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults.set(data, forKey: key)
  }

  public func load() -> TimerSnapshot? {
    guard let data = defaults.data(forKey: key) else { return nil }
    guard let snapshot = try? JSONDecoder().decode(TimerSnapshot.self, from: data) else {
      defaults.removeObject(forKey: key)
      return nil
    }
    return snapshot
  }

  public func clear() {
    defaults.removeObject(forKey: key)
  }
}

public enum TimerPhase: Equatable, Sendable {
  case notStarted
  case running
  case paused
  case finished(endedEarly: Bool)
}

/// What the screen shows at one instant.
public struct TimerState: Equatable, Sendable {
  public var phase: TimerPhase
  public var elapsedS: Double
  public var currentIndex: Int?
  public var current: TimerStep?
  public var next: TimerStep?
  public var secondsIntoStep: Double
  /// Seconds until the next step starts, or until the brew ends on the last step.
  public var secondsToNextChange: Double?
  public var totalDurationS: Int

  /// The recipe's target time has passed; the brew keeps running until the user finishes it.
  public var targetReached: Bool { elapsedS >= Double(totalDurationS) }
  /// Share of the target time elapsed, clamped to 0...1.
  public var progress: Double {
    totalDurationS > 0 ? min(max(elapsedS / Double(totalDurationS), 0), 1) : 0
  }
  public var remainingS: Double { max(Double(totalDurationS) - elapsedS, 0) }
  public var overtimeS: Double { max(elapsedS - Double(totalDurationS), 0) }
}

/// Runs recipe steps against an injectable clock. All state is derived from persisted dates.
public struct TimerEngine: Sendable {
  public let plan: TimerPlan
  private let clock: any TimerClock
  private let store: any TimerStateStore
  private var snapshot: TimerSnapshot?

  public init(plan: TimerPlan, clock: any TimerClock, store: any TimerStateStore) {
    self.plan = plan
    self.clock = clock
    self.store = store
    self.snapshot = nil
  }

  /// Rebuilds the timer that was running when the app last stopped, or `nil` if none.
  public static func restore(clock: any TimerClock, store: any TimerStateStore) -> TimerEngine? {
    guard let saved = store.load() else { return nil }
    var engine = TimerEngine(plan: saved.plan, clock: clock, store: store)
    engine.snapshot = saved
    return engine
  }

  // MARK: Controls

  public mutating func start() {
    guard snapshot == nil else { return }
    commit(
      TimerSnapshot(
        plan: plan, startedAt: clock.now(), pauses: [], skippedS: 0, endedElapsedS: nil,
        endedEarly: false))
  }

  public mutating func pause() {
    guard var saved = snapshot, case .running = state().phase else { return }
    saved.pauses.append(TimerPause(start: clock.now(), end: nil))
    commit(saved)
  }

  public mutating func resume() {
    guard var saved = snapshot, case .paused = state().phase, let last = saved.pauses.indices.last
    else { return }
    saved.pauses[last].end = max(clock.now(), saved.pauses[last].start)
    commit(saved)
  }

  /// Ends the brew at the time reached, early or not. Past the target this is the normal finish.
  public mutating func finish() {
    guard var saved = snapshot else { return }
    let current = state()
    switch current.phase {
    case .notStarted, .finished: return
    case .running, .paused: break
    }
    saved.endedElapsedS = current.elapsedS
    saved.endedEarly = !current.targetReached
    commit(saved)
  }

  /// Jumps to the start of the next step; on the last step it finishes the brew normally.
  public mutating func skipToNextStep() {
    guard var saved = snapshot else { return }
    let current = state()
    switch current.phase {
    case .notStarted, .finished: return
    case .running, .paused: break
    }
    if let next = current.next {
      saved.skippedS += Double(next.startOffsetS) - current.elapsedS
    } else {
      saved.endedElapsedS = Double(plan.totalDurationS)
      saved.endedEarly = false
    }
    commit(saved)
  }

  /// Stops the brew now and keeps the elapsed time reached.
  public mutating func endEarly() {
    guard var saved = snapshot else { return }
    let current = state()
    switch current.phase {
    case .notStarted, .finished: return
    case .running, .paused: break
    }
    saved.endedElapsedS = current.elapsedS
    saved.endedEarly = true
    commit(saved)
  }

  /// Forgets the persisted timer, e.g. after the brew form has taken its values.
  public mutating func discard() {
    snapshot = nil
    store.clear()
  }

  // MARK: State

  public func state() -> TimerState {
    guard let saved = snapshot else { return derive(phase: .notStarted, elapsed: 0) }
    if let ended = saved.endedElapsedS {
      return derive(phase: .finished(endedEarly: saved.endedEarly), elapsed: ended)
    }
    let paused = saved.pauses.last.map { $0.end == nil } ?? false
    let reference = paused ? (saved.pauses.last?.start ?? clock.now()) : clock.now()
    let pausedS = saved.pauses.reduce(0.0) { total, pause in
      guard let end = pause.end else { return total }
      return total + max(end.timeIntervalSince(pause.start), 0)
    }
    let elapsed = max(reference.timeIntervalSince(saved.startedAt) - pausedS + saved.skippedS, 0)
    // Past the target the brew keeps running (the coffee may still be draining) until finished.
    return derive(phase: paused ? .paused : .running, elapsed: elapsed)
  }

  private func derive(phase: TimerPhase, elapsed: Double) -> TimerState {
    let steps = plan.steps
    let total = Double(plan.totalDurationS)
    guard phase != .notStarted else {
      return TimerState(
        phase: phase, elapsedS: 0, currentIndex: nil, current: nil, next: steps.first,
        secondsIntoStep: 0, secondsToNextChange: nil, totalDurationS: plan.totalDurationS)
    }
    if case .finished = phase {
      return TimerState(
        phase: phase, elapsedS: elapsed, currentIndex: nil, current: nil, next: nil,
        secondsIntoStep: 0, secondsToNextChange: nil, totalDurationS: plan.totalDurationS)
    }
    let index = steps.lastIndex { Double($0.startOffsetS) <= elapsed }
    let next = index.flatMap { $0 + 1 < steps.count ? steps[$0 + 1] : nil }
    let boundary = next.map { Double($0.startOffsetS) } ?? total
    return TimerState(
      phase: phase, elapsedS: elapsed, currentIndex: index, current: index.map { steps[$0] },
      next: index == nil ? steps.first : next,
      secondsIntoStep: index.map { elapsed - Double(steps[$0].startOffsetS) } ?? 0,
      secondsToNextChange: index == nil
        ? Double(steps[0].startOffsetS) - elapsed : (boundary > elapsed ? boundary - elapsed : nil),
      totalDurationS: plan.totalDurationS)
  }

  private mutating func commit(_ saved: TimerSnapshot) {
    snapshot = saved
    store.save(saved)
  }
}

extension TimerPlan {
  /// Step indices grouped by start time, so steps that begin together (close the valve,
  /// then pour, both at 0:00) show as one displayed step in their original order.
  public var displayGroups: [[Int]] {
    var groups: [[Int]] = []
    for (index, step) in steps.enumerated() {
      if let last = groups.last?.last, steps[last].startOffsetS == step.startOffsetS {
        groups[groups.count - 1].append(index)
      } else {
        groups.append([index])
      }
    }
    return groups
  }

  /// The displayed group holding step `index`.
  public func groupIndex(ofStep index: Int) -> Int? {
    displayGroups.firstIndex { $0.contains(index) }
  }
}
