import SwiftUI
import UIKit

// The app's shared feel: how long things take, how a card answers a press, and the few
// haptics, each named for what happened rather than how it buzzes. Look-level character
// (a spring or a fade) stays in `Flavor.motion`; these are the numbers every look shares.

extension DS {
  enum Motion {
    /// A press or a small state flip.
    static let quick = 0.12
    /// A toast, a row leaving, a local change. Exits use this; entrances take `enter`.
    static let local = 0.2
    /// Something arriving: a new step, a banner.
    static let enter = 0.25
    /// How far a pressed card shrinks.
    static let pressScale = 0.97

    /// Arrives promptly and settles; nil under Reduce Motion, so the change is immediate.
    static func enter(_ reduceMotion: Bool) -> Animation? {
      reduceMotion ? nil : .easeOut(duration: enter)
    }
    /// Leaves a little faster than it came.
    static func exit(_ reduceMotion: Bool) -> Animation? {
      reduceMotion ? nil : .easeOut(duration: local)
    }
  }
}

/// One haptic per meaningful event, never per tap. They add to what the screen and
/// VoiceOver already say; nothing is told by a haptic alone.
@MainActor
enum Feedback {
  /// A value or choice moved one notch.
  static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
  /// A small confirmed change: favorite, undo, status.
  static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  /// Something was picked up or taken away (and can be put back).
  static func lift() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
  /// The brew wants your hands. Two firm beats, so it cannot be taken for a button's tap.
  static func stepChange() {
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.impactOccurred()
    Task {
      try? await Task.sleep(for: .milliseconds(140))
      generator.impactOccurred()
    }
  }
  /// Saved, finished, done; only once it is known.
  static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
  static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// A card or tile that opens something: it shrinks a little and dims under the finger and
/// springs back when the press ends or is cancelled by a scroll. Reduce Motion only dims.
struct PressableStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? DS.Motion.pressScale : 1)
      .opacity(configuration.isPressed ? 0.75 : 1)
      .animation(
        reduceMotion ? nil : .easeOut(duration: DS.Motion.quick), value: configuration.isPressed)
  }
}

extension AccessibilityNotification.Announcement {
  /// An announcement VoiceOver speaks now, ahead of whatever it was reading: a brew step
  /// that changed, or an Undo that will be gone in a few seconds.
  @MainActor
  static func urgent(_ words: String) {
    var text = AttributedString(words)
    text.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(text).post()
  }
}
