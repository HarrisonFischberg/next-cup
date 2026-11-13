import ActivityKit
import Foundation
import NextCupKit

extension TimerActivityAttributes.ContentState {
  /// `nil` when there is nothing to show: before the start and after the end.
  /// With `plan`, steps that start together count as one, as on the timer screen.
  init?(state: TimerState, plan: TimerPlan? = nil, now: Date) {
    switch state.phase {
    case .notStarted, .finished: return nil
    case .running, .paused: break
    }
    let start = now.addingTimeInterval(-state.elapsedS)
    self.init(
      stepLabel: state.current?.label ?? "Ready",
      nextLabel: (plan.map { $0.nextDisplayedStep(after: state) } ?? state.next)?.label,
      stepNumber: (state.currentIndex.map { plan?.groupIndex(ofStep: $0) ?? $0 } ?? -1) + 1,
      startDate: start,
      endDate: start.addingTimeInterval(Double(state.totalDurationS)),
      pausedAt: state.phase == .paused ? now : nil)
  }
}

extension TimerActivityAttributes {
  init(setup: TimerSetup) {
    self.init(
      recipeName: setup.recipeName, methodName: setup.methodName,
      stepCount: setup.plan.displayGroups.count,
      linkURL: DeepLink.timer(recipeID: setup.recipeID, doseG: setup.scaled.doseG).url)
  }
}

/// Mirrors the running timer to a Live Activity. Failures never stop the brew.
@MainActor
protocol TimerActivityControlling {
  func update(setup: TimerSetup, state: TimerState)
  func end()
}

/// UI tests and previews: no activity.
@MainActor
struct NoTimerActivity: TimerActivityControlling {
  func update(setup: TimerSetup, state: TimerState) {}
  func end() {}
}

/// One Live Activity as the adopt decision sees it: no ActivityKit, so it can be tested.
struct ActivityCandidate: Equatable {
  enum State: Equatable {
    /// On screen and updatable (`active` or `stale`).
    case live
    /// Removed from the screen (`dismissed`): by the person, or after an end with
    /// immediate dismissal. Which one is told apart by `ending`.
    case dismissed
    /// Ended but maybe still shown (`ended`), e.g. by the system's time limit.
    case ended
  }

  let id: String
  let linkURL: URL
  let state: State
}

enum ActivityAdoption {
  struct Plan: Equatable {
    /// The activity the run keeps updating.
    var keep: String?
    var end: [String] = []
    /// No activity kept, and the run should get a new one.
    var request: Bool { keep == nil && !declined }
    /// The person swiped this run's activity away: none comes back until the run ends.
    var declined = false
  }

  /// Which activity a run keeps and which to end. Only a live activity with this run's
  /// link that was not already asked to end is kept: an end lands later, so one still
  /// listed after `end()` (the same recipe started again, a relaunch) would otherwise be
  /// adopted and then die under the new run. The held one wins over another match. Every
  /// other one is from a run no longer saved (only one is). A held activity dismissed
  /// without this app asking means the person removed it, and that sticks for the run.
  static func plan(
    held: String?, link: URL, listed: [ActivityCandidate], ending: Set<String>,
    declined: Bool = false
  ) -> Plan {
    let heldState = listed.first { $0.id == held }?.state
    if declined || (heldState == .dismissed && !ending.contains(held ?? "")) {
      return Plan(keep: nil, declined: true)
    }
    let usable = listed.filter {
      $0.state == .live && $0.linkURL == link && !ending.contains($0.id)
    }
    let keep = (usable.first { $0.id == held } ?? usable.first)?.id
    return Plan(keep: keep, end: listed.map(\.id).filter { $0 != keep && !ending.contains($0) })
  }
}

/// ActivityKit's `Activity` is not `Sendable` in this SDK, yet only its own async calls
/// touch it, and this class is its only user.
private struct ActivityHandle: @unchecked Sendable {
  let activity: Activity<TimerActivityAttributes>
}

@MainActor
final class LiveTimerActivity: TimerActivityControlling {
  private var activity: Activity<TimerActivityAttributes>?
  /// Activities this instance asked to end; they stay listed until the end lands.
  private var ending: Set<String> = []
  /// The person swiped the run's activity away; cleared when the app ends the run.
  private var declined = false

  func update(setup: TimerSetup, state: TimerState) {
    guard
      let content = TimerActivityAttributes.ContentState(
        state: state, plan: setup.plan, now: Date())
    else {
      end()
      return
    }
    let attributes = TimerActivityAttributes(setup: setup)
    // A relaunch adopts this run's activity from the last process instead of stacking a
    // second; a held one the app ended is replaced, one the person swiped away is not.
    var all = Activity<TimerActivityAttributes>.activities
    if let held = activity, !all.contains(where: { $0.id == held.id }) { all.append(held) }
    ending.formIntersection(all.map(\.id))
    let plan = ActivityAdoption.plan(
      held: activity?.id, link: attributes.linkURL,
      listed: all.map {
        ActivityCandidate(id: $0.id, linkURL: $0.attributes.linkURL, state: Self.state($0))
      }, ending: ending, declined: declined)
    declined = plan.declined
    activity = all.first { $0.id == plan.keep }
    for other in all where plan.end.contains(other.id) { end(other) }
    guard !declined else { return }
    // Not stale at the target: the clock counts overtime, like the app, for up to an hour.
    let activityContent = ActivityContent(
      state: content, staleDate: content.endDate.addingTimeInterval(3600))
    if let activity {
      let handle = ActivityHandle(activity: activity)
      Task { await handle.activity.update(activityContent) }
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    activity = try? Activity.request(attributes: attributes, content: activityContent)
  }

  func end() {
    declined = false
    let running = activity.map { [$0] } ?? Activity<TimerActivityAttributes>.activities
    activity = nil
    for each in running { end(each) }
  }

  private static func state(_ activity: Activity<TimerActivityAttributes>)
    -> ActivityCandidate.State
  {
    switch activity.activityState {
    case .dismissed: .dismissed
    case .ended: .ended
    default: .live
    }
  }

  private func end(_ activity: Activity<TimerActivityAttributes>) {
    ending.insert(activity.id)
    let handle = ActivityHandle(activity: activity)
    Task { await handle.activity.end(nil, dismissalPolicy: .immediate) }
  }
}
