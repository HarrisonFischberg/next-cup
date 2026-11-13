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
  let id: String
  let linkURL: URL
  /// Still on screen and updatable (`active` or `stale`), not ended or swiped away.
  let isLive: Bool
}

enum ActivityAdoption {
  /// Which activity a run keeps (`nil`: request a new one) and which to end. Only a live
  /// activity with this run's link that was not already asked to end is kept: an end
  /// lands later, so one still listed after `end()` (the same recipe started again, a
  /// relaunch) would otherwise be adopted and then die under the new run. The held one
  /// wins over another match. Every other one is from a run no longer saved (only one is).
  static func plan(
    held: String?, link: URL, listed: [ActivityCandidate], ending: Set<String>
  ) -> (keep: String?, end: [String]) {
    let usable = listed.filter { $0.isLive && $0.linkURL == link && !ending.contains($0.id) }
    let keep = (usable.first { $0.id == held } ?? usable.first)?.id
    return (keep, listed.map(\.id).filter { $0 != keep && !ending.contains($0) })
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
    // second; a held one that ended (swiped away, Delete all) is replaced.
    var all = Activity<TimerActivityAttributes>.activities
    if let held = activity, !all.contains(where: { $0.id == held.id }) { all.append(held) }
    ending.formIntersection(all.map(\.id))
    let plan = ActivityAdoption.plan(
      held: activity?.id, link: attributes.linkURL,
      listed: all.map {
        ActivityCandidate(
          id: $0.id, linkURL: $0.attributes.linkURL,
          isLive: $0.activityState == .active || $0.activityState == .stale)
      }, ending: ending)
    activity = all.first { $0.id == plan.keep }
    for other in all where plan.end.contains(other.id) { end(other) }
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
    let running = activity.map { [$0] } ?? Activity<TimerActivityAttributes>.activities
    activity = nil
    for each in running { end(each) }
  }

  private func end(_ activity: Activity<TimerActivityAttributes>) {
    ending.insert(activity.id)
    let handle = ActivityHandle(activity: activity)
    Task { await handle.activity.end(nil, dismissalPolicy: .immediate) }
  }
}
