import NextCupKit
import SwiftUI
import UIKit

/// S05: the guided timer. Big readout, the live step, and the controls in the
/// bottom thumb zone. Time is always derived from saved dates, so the screen
/// catches up the moment the app returns to the foreground.
struct TimerView: View {
  @State private var session: TimerSession
  @State private var seed: BrewFormSeed?
  /// Set once the brew from this run is saved, so it cannot be logged twice.
  @State private var logged = false
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
        // Step 1 stays put so the recipe header is not pushed under the bar.
        guard let index, index > 0 else { return }
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
    .navigationDestination(item: $seed) { seed in
      BrewFormView(seed: seed, onSaved: { logged = true })
    }
    .accessibilityIdentifier("timer.screen")
    .task {
      while !Task.isCancelled {
        session.tick()
        try? await Task.sleep(for: .milliseconds(250))
      }
    }
    .onChange(of: scenePhase) { _, phase in if phase == .active { session.tick() } }
    .onChange(of: state.currentIndex) { _, index in announce(stepAt: index) }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(setup.recipeName.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
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

  @ViewBuilder private var readout: some View {
    if DS.isBloom { bloomReadout } else { steelReadout }
  }

  /// Bloom: one large ring with a dot at each step change, the time in its centre,
  /// and the live step's target set large beneath it.
  private var bloomReadout: some View {
    let total = Double(setup.plan.totalDurationS)
    return VStack(spacing: DS.Space.lg) {
      ZStack {
        TimerRing(
          fraction: total > 0 ? state.elapsedS / total : 0,
          stepFractions: total > 0
            ? setup.plan.steps.dropFirst().map { Double($0.startOffsetS) / total } : [])
        VStack(spacing: 2) {
          Text(RecipeFormat.clock(Int(state.elapsedS)))
            .font(DS.Font.readout).foregroundStyle(DS.ink)
            .minimumScaleFactor(0.5).lineLimit(1)
            .dynamicTypeSize(...DS.readoutCap)
            .accessibilityLabel("Elapsed time")
            .accessibilityValue(RecipeFormat.spokenTime(Int(state.elapsedS)))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("timer.elapsed")
          Text("of \(RecipeFormat.clock(setup.plan.totalDurationS))")
            .font(.subheadline).foregroundStyle(DS.ink2)
        }
        .padding(DS.Space.xxl)
      }
      .frame(width: 290, height: 290)
      .frame(maxWidth: .infinity)
      VStack(spacing: DS.Space.xs) {
        Text(statusLine).font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(DS.signal)
          .multilineTextAlignment(.center)
          .accessibilityIdentifier("timer.status")
        if let step = state.current {
          Text(
            step.targetCumulativeWaterG.map { "to \(RecipeFormat.weight($0, units))" } ?? step.label
          )
          .font(.system(size: 46, design: .serif)).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap).minimumScaleFactor(0.6).lineLimit(1)
          if !step.instruction.isEmpty {
            Text(step.instruction).font(.body).foregroundStyle(DS.ink2)
              .multilineTextAlignment(.center)
          }
        }
      }
      .frame(maxWidth: .infinity)
    }
  }

  private var steelReadout: some View {
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

  /// The finish is its own moment: what was reached against the target, then one
  /// next step. Nothing moves on until the user taps it.
  private var finishedBanner: some View {
    let early = session.outcome?.endedEarly == true
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text((early ? "Brew ended" : "Brew complete").dsTitle).font(DS.Font.display)
        .foregroundStyle(DS.ink).dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      Text(
        "\(RecipeFormat.clock(Int(state.elapsedS))) · target \(RecipeFormat.clock(setup.plan.totalDurationS)). "
          + (early ? "Log it with the time reached." : "Taste it, then log how it was.")
      )
      .font(.body).foregroundStyle(DS.ink2)
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.crema.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.controlRadius))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("timer.finished")
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
        .disabled(logged)
        .accessibilityIdentifier("timer.primary")
      if showsSecondary {
        let layout =
          dts.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: DS.Space.sm))
          : AnyLayout(HStackLayout(spacing: DS.Space.sm))
        // One container so the two glass buttons sample the same backdrop.
        GlassEffectContainer(spacing: DS.Space.sm) {
          layout {
            SteelButton(title: "Skip step", kind: .secondary) { session.skipToNextStep() }
              .accessibilityIdentifier("timer.skip")
            SteelButton(title: "End early", kind: .secondary) { session.endEarly() }
              .accessibilityIdentifier("timer.end")
          }
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
    case .finished: logged ? "Brew logged" : "Taste and log"
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
