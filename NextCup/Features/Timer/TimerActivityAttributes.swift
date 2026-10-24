import ActivityKit
import Foundation

/// What the Lock Screen and Dynamic Island show for a running brew. This file is
/// compiled into both the app and the `NextCupLiveActivity` extension, so it
/// imports nothing from the app: the extension gets timer state only (blueprint §2).
struct TimerActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var stepLabel: String
    var nextLabel: String?
    /// One-based position of the current step.
    var stepNumber: Int
    /// The brew's virtual start (now minus elapsed), so `Text(timerInterval:)` counts the clock.
    var startDate: Date
    var endDate: Date
    /// Set while paused; the clock freezes at this moment.
    var pausedAt: Date?
  }

  var recipeName: String
  var methodName: String?
  var stepCount: Int
  /// Tapping the activity opens the running timer.
  var linkURL: URL
}
