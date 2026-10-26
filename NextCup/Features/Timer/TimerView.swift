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
    // The readout stays put; only the step list scrolls, so starting or moving to the
    // next step never pushes the time under the navigation bar.
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      header
      readout
      if session.outcome != nil { finishedBanner }
      ScrollViewReader { proxy in
        ScrollView {
          steps.padding(.bottom, DS.Space.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: state.currentIndex) { _, index in
          guard let index, index > 0 else { return }
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(index, anchor: .center)
          }
        }
      }
    }
    .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.lg)
    // A container, so the screen's identifier does not replace its children's.
    .accessibilityElement(children: .contain)
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

  /// The brewer doing the current step inside the progress ring, the time beneath it,
  /// and the live step's target. Same layout in every style; the style sets the colors,
  /// the medallion shape and the numerals.
  private var readout: some View {
    let total = Double(setup.plan.totalDurationS)
    let frame = BrewScene.frame(
      setup.sceneKind, steps: setup.sceneSteps, totalS: total, elapsedS: state.elapsedS)
    return VStack(spacing: DS.Space.sm) {
      ZStack {
        TimerRing(
          fraction: total > 0 ? state.elapsedS / total : 0,
          stepFractions: total > 0
            ? setup.plan.steps.dropFirst().map { Double($0.startOffsetS) / total } : [])
        BrewMedallion {
          BrewSceneView(
            kind: setup.sceneKind, glyph: setup.glyph, frame: frame,
            running: state.phase == .running)
        }
        .padding(26)
      }
      .frame(width: 250, height: 250)
      .frame(maxWidth: .infinity)
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
        Text(RecipeFormat.clock(Int(state.elapsedS)))
          .font(DS.flavor.timerReadout)
          .foregroundStyle(DS.ink)
          .minimumScaleFactor(0.5).lineLimit(1)
          .dynamicTypeSize(...DS.readoutCap)
          .accessibilityLabel("Elapsed time")
          .accessibilityValue(RecipeFormat.spokenTime(Int(state.elapsedS)))
          .accessibilityAddTraits(.updatesFrequently)
          .accessibilityIdentifier("timer.elapsed")
        Text("of \(RecipeFormat.clock(setup.plan.totalDurationS))")
          .font(.subheadline).foregroundStyle(DS.ink2)
      }
      .padding(.top, DS.Space.md)
      Text(statusLine).font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(DS.signal)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("timer.status")
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
    return HStack(alignment: .top, spacing: DS.Space.md) {
      Image(systemName: early ? "stop.circle" : "checkmark.circle").font(.title2)
        .foregroundStyle(DS.signal).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(early ? "Brew ended" : "Brew complete").font(.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(
          "\(RecipeFormat.clock(Int(state.elapsedS))) of \(RecipeFormat.clock(setup.plan.totalDurationS)). "
            + (early ? "Log it with the time you reached." : "Taste it, then log how it was.")
        )
        .font(.subheadline).foregroundStyle(DS.ink2)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
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
              state: rowState(index), showsDivider: index < setup.plan.steps.count - 1
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
