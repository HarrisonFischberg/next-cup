import SwiftUI
import UIKit

// Progress pieces shared by onboarding, the Getting started card and the
// moments where the user has to trust a result (scan, import, export).

/// "Step 2 of 3" over a bar. The bar is decorative; the words carry the value.
struct StepProgress: View {
  let step: Int
  let total: Int

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text("Step \(step) of \(total)").font(.footnote.weight(.semibold)).foregroundStyle(DS.ink2)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(DS.ringTrack)
          Capsule().fill(DS.crema)
            .frame(width: proxy.size.width * Double(step) / Double(max(total, 1)))
        }
      }
      .frame(height: 6)
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("progress.step")
  }
}

/// A short list of real stages: done ones ticked, the live one in ink, later ones
/// quiet. Each stage change is announced to VoiceOver.
struct StagedProgress: View {
  let stages: [String]
  /// Index of the stage running now; `stages.count` means all done.
  let current: Int

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
        HStack(spacing: DS.Space.sm) {
          Group {
            if index < current {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.sage)
            } else if index == current {
              ProgressView().controlSize(.small)
            } else {
              Image(systemName: "circle").foregroundStyle(DS.line)
            }
          }
          .frame(width: 22)
          .accessibilityHidden(true)
          Text(stage).font(.callout.weight(index == current ? .semibold : .regular))
            .foregroundStyle(index <= current ? DS.ink : DS.ink2)
        }
        .frame(minHeight: 28, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(current < stages.count ? stages[current] : "Done")
    .accessibilityIdentifier("progress.staged")
    .onChange(of: current) { _, index in
      guard index < stages.count else { return }
      UIAccessibility.post(notification: .announcement, argument: stages[index])
    }
  }

  /// Keeps a stage on screen long enough to read (400 ms) when the real work was
  /// quicker. Never used on routine actions.
  static func hold(since start: Date) async {
    let left = 0.4 - Date().timeIntervalSince(start)
    if left > 0 { try? await Task.sleep(for: .seconds(left)) }
  }
}

/// A finished flow: the rings fill to the moment's own numbers, then the copy and
/// the next step. Reduce Motion swaps the fill for a short fade.
struct SuccessView<Detail: View>: View {
  let title: String
  let message: String
  /// Up to three ring fractions, outermost first; empty draws a single full ring.
  var rings: [(fraction: Double, color: Color)] = []
  var primaryTitle: String
  var primary: () -> Void
  var secondaryTitle: String?
  var secondary: (() -> Void)?
  /// Fire `.success` here only when the action behind it did not already.
  var playsHaptic = false
  @ViewBuilder var detail: Detail

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      BrewRings(
        rings: (rings.isEmpty ? [(1, DS.crema)] : rings).map { (shown ? $0.fraction : 0, $0.color) }
      )
      .frame(width: 132, height: 132)
      .frame(maxWidth: .infinity)
      .opacity(reduceMotion && !shown ? 0 : 1)
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        Text(title.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap)
          .accessibilityAddTraits(.isHeader)
        Text(message).font(.body).foregroundStyle(DS.ink2)
      }
      detail
      SteelButton(title: primaryTitle, action: primary)
        .accessibilityIdentifier("success.primary")
      if let secondaryTitle, let secondary {
        Button(secondaryTitle, action: secondary)
          .font(.body.weight(.semibold)).foregroundStyle(DS.ink)
          .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
          .accessibilityIdentifier("success.secondary")
      }
    }
    .padding(DS.Space.xl)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .onAppear {
      if playsHaptic { Feedback.success() }
      withAnimation(
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8)
      ) { shown = true }
    }
  }
}

extension SuccessView where Detail == EmptyView {
  init(
    title: String, message: String, rings: [(fraction: Double, color: Color)] = [],
    primaryTitle: String, primary: @escaping () -> Void, secondaryTitle: String? = nil,
    secondary: (() -> Void)? = nil, playsHaptic: Bool = false
  ) {
    self.init(
      title: title, message: message, rings: rings, primaryTitle: primaryTitle,
      primary: primary, secondaryTitle: secondaryTitle, secondary: secondary,
      playsHaptic: playsHaptic
    ) { EmptyView() }
  }
}
