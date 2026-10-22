import NextCupKit
import SwiftUI
import UIKit

/// S05: the guided timer. Big readout, the live step, and the controls in the
/// bottom thumb zone. Time is always derived from saved dates, so the screen
/// catches up the moment the app returns to the foreground.
struct TimerView: View {
  @State private var session: TimerSession
  @State private var seed: BrewFormSeed?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dts
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(setup: TimerSetup) {
    _session = State(initialValue: TimerSession(setup: setup))
  }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var state: TimerState { session.state }
  private var setup: TimerSetup { session.setup }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          header
          readout
          if session.outcome != nil { finishedBanner }
          steps
        }
        .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
      }
      .onChange(of: state.currentIndex) { _, index in
        guard let index else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
          proxy.scrollTo(index, anchor: .center)
        }
      }
    }
    .background(DS.bg)
    .safeAreaInset(edge: .bottom, spacing: 0) { controls }
    .navigationTitle("Brew")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarVisibility(.hidden, for: .tabBar)
    .navigationDestination(item: $seed) { BrewFormPlaceholder(seed: $0) }
    .accessibilityIdentifier("timer.screen")
    .task {
      while !Task.isCancelled {
        session.tick()
        try? await Task.sleep(for: .milliseconds(250))
      }
    }
    .onChange(of: scenePhase) { _, phase in if phase == .active { session.tick() } }
    .onChange(of: state.currentIndex) { _, index in announce(stepAt: index) }
    .onChange(of: session.outcome) { _, outcome in
      guard let outcome else { return }
      seed = setup.seed(elapsedS: outcome.elapsedS, endedEarly: outcome.endedEarly)
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(setup.recipeName.uppercased()).font(DS.Font.display).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      Text(
        [
          setup.methodName, RecipeFormat.weight(setup.scaled.doseG, units) + " dose",
          RecipeFormat.weight(setup.scaled.totalWaterG, units) + " water",
        ].compactMap { $0 }.joined(separator: " · ")
      )
      .font(.subheadline).foregroundStyle(DS.ink2)
    }
  }

  private var readout: some View {
    let total = Double(setup.plan.totalDurationS)
    return InstrumentPanel {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text(RecipeFormat.clock(Int(state.elapsedS)))
          .font(DS.Font.readout).foregroundStyle(DS.onSteel)
          .minimumScaleFactor(0.5).lineLimit(1)
          .dynamicTypeSize(...DS.readoutCap)
          .accessibilityLabel("Elapsed time")
          .accessibilityValue(RecipeFormat.spokenTime(Int(state.elapsedS)))
          .accessibilityAddTraits(.updatesFrequently)
          .accessibilityIdentifier("timer.elapsed")
        ReadoutBar(fraction: total > 0 ? state.elapsedS / total : 0)
        Text(statusLine).font(DS.Font.mono(.footnote, .bold)).foregroundStyle(DS.onSteel)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("timer.status")
      }
    }
  }

  private var statusLine: String {
    let count = setup.plan.steps.count
    switch state.phase {
    case .notStarted:
      return "READY · \(count) STEPS · \(RecipeFormat.clock(setup.plan.totalDurationS))"
    case .finished(let early): return early ? "ENDED EARLY" : "BREW COMPLETE"
    case .running, .paused:
      var parts = ["STEP \((state.currentIndex ?? -1) + 1) OF \(count)"]
      if state.phase == .paused { parts.append("PAUSED") }
      if let seconds = state.secondsToNextChange {
        parts.append(
          (state.next == nil ? "ENDS IN " : "NEXT IN ")
            + RecipeFormat.clock(Int(seconds.rounded(.up))))
      }
      return parts.joined(separator: " · ")
    }
  }

  private var finishedBanner: some View {
    StateBanner(
      kind: .info,
      message: session.outcome?.endedEarly == true
        ? "Brew ended at \(RecipeFormat.clock(Int(state.elapsedS))). Log it with the time reached."
        : "Brew complete at \(RecipeFormat.clock(Int(state.elapsedS))). Log how it tasted.")
  }

  private var steps: some View {
    VStack(alignment: .leading, spacing: 0) {
      ColumnHeader(leading: "T+", middle: "Step", trailing: "Water")
      PaperBox {
        VStack(spacing: 0) {
          ForEach(Array(setup.plan.steps.enumerated()), id: \.offset) { index, step in
            OperationRow(
              time: RecipeFormat.clock(step.startOffsetS), name: step.label,
              instruction: step.instruction.isEmpty ? nil : step.instruction,
              scale: step.targetCumulativeWaterG.map { RecipeFormat.weight($0, units) },
              state: rowState(index)
            )
            .id(index)
            .accessibilityIdentifier("timer.step.\(index)")
          }
        }
      }
    }
  }

  private func rowState(_ index: Int) -> RowState {
    switch state.phase {
    case .notStarted: return .upcoming
    case .finished: return .done
    case .running, .paused:
      guard let current = state.currentIndex else { return .upcoming }
      return index < current ? .done : (index == current ? .live : .upcoming)
    }
  }

  // MARK: Controls

  private var controls: some View {
    VStack(spacing: DS.Space.sm) {
      SteelButton(title: primaryTitle, action: primaryAction)
        .accessibilityIdentifier("timer.primary")
      if showsSecondary {
        let layout =
          dts.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: DS.Space.sm))
          : AnyLayout(HStackLayout(spacing: DS.Space.sm))
        layout {
          SteelButton(title: "Skip step", kind: .secondary) { session.skipToNextStep() }
            .accessibilityIdentifier("timer.skip")
          SteelButton(title: "End early", kind: .secondary) { session.endEarly() }
            .accessibilityIdentifier("timer.end")
        }
      }
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
    .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) { Hairline() }
  }

  private var showsSecondary: Bool {
    state.phase == .running || state.phase == .paused
  }

  private var primaryTitle: String {
    switch state.phase {
    case .notStarted: "Start"
    case .running: "Pause"
    case .paused: "Resume"
    case .finished: "Log this brew"
    }
  }

  private func primaryAction() {
    switch state.phase {
    case .notStarted: session.start()
    case .running: session.pause()
    case .paused: session.resume()
    case .finished:
      if let outcome = session.outcome {
        seed = setup.seed(elapsedS: outcome.elapsedS, endedEarly: outcome.endedEarly)
      }
    }
  }

  // MARK: Accessibility

  /// Tells VoiceOver which step began, since the screen changes without a tap.
  private func announce(stepAt index: Int?) {
    guard let index, index < setup.plan.steps.count, state.phase == .running else { return }
    let step = setup.plan.steps[index]
    var words = step.label
    if let target = step.targetCumulativeWaterG {
      let unit = units.weight == .grams ? "grams" : "ounces"
      words += ", to \(RecipeFormat.weight(target, units, withSymbol: false)) \(unit)"
    }
    AccessibilityNotification.Announcement(words).post()
  }
}
