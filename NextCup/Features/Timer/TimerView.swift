import NextCupKit
import SwiftUI
import UIKit

/// S05, the active brew: one screen that walks the schedule by itself. The time and
/// progress stay put at the top; the current instruction, the countdown to the next
/// action, the brewer picture and the schedule sit below; Pause stays in reach.
/// Time is always derived from saved dates, so the screen catches up the moment the
/// app returns to the foreground. Past the target the brew keeps running until
/// Finish brew, which records the time actually reached.
struct TimerView: View {
  @State private var session: TimerSession
  @State private var seed: BrewFormSeed?
  /// Set once the brew from this run is saved, so it cannot be logged twice.
  @State private var logged = false
  @State private var confirmsEnd = false
  @State private var finishedShown = false
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @AppStorage(SystemTimerHaptics.soundKey) private var sound = true
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
  private var plan: TimerPlan { setup.plan }
  private var groups: [[Int]] { plan.displayGroups }
  private var currentGroup: Int? { state.currentIndex.flatMap { plan.groupIndex(ofStep: $0) } }
  private var running: Bool { state.phase == .running || state.phase == .paused }
  private var motion: Animation? { reduceMotion ? nil : DS.flavor.motion.transition }
  private var textMotion: Animation? { reduceMotion ? nil : DS.flavor.motion.text }

  var body: some View {
    // The readout stays put and the schedule scrolls under it; at accessibility sizes
    // the readout alone would fill the screen, so there everything scrolls together.
    VStack(alignment: .leading, spacing: DS.Space.md) {
      if !dts.isAccessibilitySize { readout }
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          if dts.isAccessibilitySize { readout }
          if session.outcome != nil { finishedBanner } else { currentStep }
          context
          schedule
        }
        .padding(.bottom, DS.Space.lg)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.sm)
    // A container, so the screen's identifier does not replace its children's.
    .accessibilityElement(children: .contain)
    .background(DS.bg)
    .safeAreaInset(edge: .bottom, spacing: 0) { controls }
    .navigationTitle("Brew")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarVisibility(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          sound.toggle()
        } label: {
          Label(
            sound ? "Sound on" : "Sound off",
            systemImage: sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .accessibilityHint("Plays a short tone when a step changes")
        .accessibilityIdentifier("timer.sound")
      }
    }
    .navigationDestination(item: $seed) { seed in
      BrewFormView(seed: seed, onSaved: { logged = true })
    }
    .confirmationDialog(
      "End this brew early?", isPresented: $confirmsEnd, titleVisibility: .visible
    ) {
      Button("End and log it", role: .destructive) { session.endEarly() }
      Button("Keep brewing", role: .cancel) {}
    } message: {
      Text("The time reached so far is kept and goes into the journal entry.")
    }
    .accessibilityIdentifier("timer.screen")
    .task {
      while !Task.isCancelled {
        session.tick()
        try? await Task.sleep(for: .milliseconds(250))
      }
    }
    // Coming back catches up without replaying the cues that were missed.
    .onChange(of: scenePhase) { _, phase in if phase == .active { session.tick(cues: false) } }
    .onChange(of: state.currentIndex) { _, index in announce(stepAt: index) }
    .onChange(of: state.targetReached) { _, reached in
      if reached, running { AccessibilityNotification.Announcement("Target time reached").post() }
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }

  // MARK: Readout

  /// Elapsed time, remaining against the target, and progress. The digits never move.
  private var readout: some View {
    let ring = DS.flavor.control == .square && !dts.isAccessibilitySize
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      VStack(alignment: .leading, spacing: 2) {
        Text(setup.recipeName.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
          .lineLimit(1).minimumScaleFactor(0.8)
          .accessibilityAddTraits(.isHeader)
        if let method = setup.methodName, !dts.isAccessibilitySize {
          Text(method).font(.footnote).foregroundStyle(DS.ink2)
        }
      }
      .padding(.bottom, DS.Space.sm)
      if ring {
        ZStack {
          TimerRing(
            fraction: state.progress, stepFractions: stepFractions, color: DS.signal,
            track: DS.line.opacity(0.35)
          )
          .animation(reduceMotion ? nil : .linear(duration: 0.25), value: state.progress)
          VStack(spacing: 0) {
            Kicker("Elapsed")
            elapsed
            remaining
          }
          .padding(DS.Space.xl)
        }
        .frame(width: 250, height: 250).frame(maxWidth: .infinity)
      } else {
        Kicker("Elapsed")
        elapsed
        remaining
        bar
      }
      Text(statusLine).font(DS.Font.label).tracking(0.8).foregroundStyle(DS.ink2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("timer.status")
    }
    .padding(.top, DS.Space.xs)
  }

  private var elapsed: some View {
    Text(RecipeFormat.clock(Int(state.elapsedS)))
      .font(DS.flavor.timerReadout).foregroundStyle(DS.ink)
      .minimumScaleFactor(0.5).lineLimit(1)
      .dynamicTypeSize(...DS.readoutCap)
      .accessibilityLabel("Elapsed time")
      .accessibilityValue(RecipeFormat.spokenTime(Int(state.elapsedS)))
      .accessibilityAddTraits(.updatesFrequently)
      .accessibilityIdentifier("timer.elapsed")
  }

  private var remaining: some View {
    let total = RecipeFormat.clock(plan.totalDurationS)
    let line: String =
      switch state.phase {
      case .notStarted: "Ready · \(total) target"
      case .finished: "Finished · \(total) target"
      case .running, .paused:
        state.targetReached
          ? "Target reached · \(RecipeFormat.clock(Int(state.overtimeS))) over"
          : "\(RecipeFormat.clock(Int(state.remainingS.rounded(.up)))) remaining · \(total) total"
      }
    return Text(line).font(.subheadline.weight(.medium))
      .fixedSize(horizontal: false, vertical: true)
      .foregroundStyle(state.targetReached && running ? DS.signal : DS.ink2)
      .accessibilityIdentifier("timer.remaining")
  }

  private var bar: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(DS.line.opacity(0.3))
        Capsule().fill(DS.signal).frame(width: g.size.width * state.progress)
          .animation(reduceMotion ? nil : .linear(duration: 0.25), value: state.progress)
      }
    }
    .frame(height: 8).padding(.vertical, DS.Space.xs)
    .accessibilityHidden(true)
  }

  private var stepFractions: [Double] {
    let total = Double(plan.totalDurationS)
    return total > 0 ? plan.steps.dropFirst().map { Double($0.startOffsetS) / total } : []
  }

  /// Short and machine-readable: the UI tests read it.
  private var statusLine: String {
    let count = groups.count
    switch state.phase {
    case .notStarted:
      return "READY · \(count) STEPS · \(RecipeFormat.clock(plan.totalDurationS))"
    case .finished(let early):
      return (early ? "ENDED EARLY · " : "DONE · ") + RecipeFormat.clock(Int(state.elapsedS))
    case .running, .paused:
      var parts = ["STEP \((currentGroup ?? -1) + 1) OF \(count)"]
      if state.phase == .paused { parts.append("PAUSED") }
      if state.targetReached {
        parts.append("TARGET REACHED")
      } else if let seconds = state.secondsToNextChange {
        parts.append(
          (state.next == nil ? "TARGET IN " : "NEXT IN ")
            + RecipeFormat.clock(Int(seconds.rounded(.up))))
      }
      return parts.joined(separator: " · ")
    }
  }

  // MARK: Current step

  /// The step the schedule is on, the next action and its countdown, and the brewer doing it.
  private var currentStep: some View {
    let stacked = dts.isAccessibilitySize
    let layout =
      stacked
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.md))
      : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
    return layout {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        HStack(spacing: DS.Space.sm) {
          Kicker(stepKicker)
          if state.phase == .paused {
            Text("Paused").font(.caption.weight(.bold)).foregroundStyle(DS.onSignal)
              .padding(.horizontal, DS.Space.sm).padding(.vertical, 3)
              .background(DS.ink, in: Capsule())
              .transition(.opacity)
          }
        }
        Text(headline).font(DS.Font.instruction).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap).minimumScaleFactor(0.7).lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .contentTransition(.opacity)
          .accessibilityAddTraits(.isHeader)
        if let detail {
          Text(detail).font(.body).foregroundStyle(DS.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
        }
        Text(nextLine).font(.subheadline.weight(.semibold)).foregroundStyle(DS.signal)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("timer.next")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if !stacked { scene.frame(width: 104, height: 104) }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .colorBlock()
    .animation(textMotion, value: state.currentIndex)
    .animation(motion, value: state.phase)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("timer.current")
  }

  /// The brewer at this stage of the brew. Stage-based and illustrative; it shows the
  /// schedule, not what is in the cup.
  private var scene: some View {
    let frame = BrewScene.frame(
      setup.sceneKind, steps: setup.sceneSteps, totalS: Double(plan.totalDurationS),
      elapsedS: state.elapsedS)
    return BrewMedallion {
      BrewSceneView(
        kind: setup.sceneKind, glyph: setup.glyph, frame: frame, running: state.phase == .running)
    }
  }

  private var stepKicker: String {
    switch state.phase {
    case .notStarted: return "Ready"
    case .finished(let early): return early ? "Ended early" : "Finished"
    case .running, .paused:
      guard let group = currentGroup else { return "Starting" }
      let names = groups[group].map { plan.steps[$0].label }.joined(separator: " & ")
      return String(format: "%02d / ", group + 1) + names
    }
  }

  /// The instruction, large. Steps that start together read as one line.
  private var headline: String {
    switch state.phase {
    case .notStarted: return "Ready when you are."
    case .finished(let early): return early ? "Brew ended." : "Brew finished."
    case .running, .paused:
      guard let group = currentGroup else { return "Starting…" }
      let steps = groups[group].map { plan.steps[$0] }
      if steps.count == 1 {
        let step = steps[0]
        return step.instruction.isEmpty ? step.label + "." : step.instruction
      }
      return steps.map { $0.label.lowercased() }.joined(separator: ", then ")
        .prefix(1).uppercased()
        + steps.map { $0.label.lowercased() }
        .joined(separator: ", then ").dropFirst() + "."
    }
  }

  /// Instructions that did not fit the headline: the water target, or each grouped step's words.
  private var detail: String? {
    guard running, let group = currentGroup else {
      return state.phase == .notStarted
        ? "Start runs the \(groups.count) steps on their own schedule. No tapping between steps."
        : nil
    }
    let steps = groups[group].map { plan.steps[$0] }
    var lines: [String] = []
    if steps.count > 1 { lines = steps.map(\.instruction).filter { !$0.isEmpty } }
    if let target = steps.compactMap(\.targetCumulativeWaterG).last {
      lines.append("Recipe water to here: \(RecipeFormat.weight(target, units)).")
    }
    return lines.isEmpty ? nil : lines.joined(separator: " ")
  }

  /// "Open valve in 1:18 · at 2:00", or the target when this is the last step.
  private var nextLine: String {
    switch state.phase {
    case .notStarted: return "First: \(groups.first.map { stepNames($0) } ?? "")"
    case .finished: return "Reached \(RecipeFormat.clock(Int(state.elapsedS)))."
    case .running, .paused:
      if state.targetReached { return "Target time passed. Finish when it has drained." }
      guard let seconds = state.secondsToNextChange else { return "" }
      let countdown = RecipeFormat.clock(Int(seconds.rounded(.up)))
      if let group = currentGroup, group + 1 < groups.count {
        let next = groups[group + 1]
        let at = RecipeFormat.clock(plan.steps[next[0]].startOffsetS)
        return "\(stepNames(next)) in \(countdown) · at \(at)"
      }
      return "Target in \(countdown) · at \(RecipeFormat.clock(plan.totalDurationS))"
    }
  }

  private func stepNames(_ group: [Int]) -> String {
    group.map { plan.steps[$0].label }.joined(separator: " & ")
  }

  // MARK: Context and schedule

  /// The recipe's numbers. Water is the recipe's target: nothing here is measured.
  private var context: some View {
    HStack(alignment: .top, spacing: DS.Space.md) {
      Image(systemName: "drop.fill").font(.title3.weight(.semibold)).foregroundStyle(DS.signal)
        .frame(width: 28).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(RecipeFormat.weight(setup.scaled.totalWaterG, units)).font(DS.Font.dataLarge)
          .foregroundStyle(DS.ink)
        Text("Recipe water").font(.footnote).foregroundStyle(DS.ink2)
        Text(
          [
            RecipeFormat.weight(setup.scaled.doseG, units) + " coffee",
            setup.tempC.map { RecipeFormat.temperature($0, units) },
          ].compactMap { $0 }.joined(separator: " · ")
        )
        .font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: 0)
    }
    .padding(DS.Space.md)
    .panel(DS.paper)
    .accessibilityElement(children: .combine)
  }

  /// What is still to come, then what the schedule has already passed.
  private var schedule: some View {
    let current = currentGroup ?? (state.phase == .notStarted ? -1 : groups.count)
    let upcoming = groups.indices.filter { $0 > current }
    let earlier = groups.indices.filter { $0 < current }
    return VStack(alignment: .leading, spacing: DS.Space.lg) {
      if !upcoming.isEmpty {
        VStack(alignment: .leading, spacing: DS.Space.md) {
          SectionRule("Up next")
          ForEach(upcoming, id: \.self) { group in
            row(group, state: .upcoming, isLast: group == upcoming.last)
          }
        }
      }
      if !earlier.isEmpty {
        VStack(alignment: .leading, spacing: DS.Space.md) {
          SectionRule("Earlier in the schedule")
          ForEach(earlier, id: \.self) { group in
            row(group, state: .done, isLast: group == earlier.last)
          }
        }
        .accessibilityHint("Steps the schedule has passed, not steps confirmed done")
      }
    }
    .animation(motion, value: current)
  }

  private func row(_ group: Int, state rowState: RowState, isLast: Bool) -> some View {
    let steps = groups[group].map { plan.steps[$0] }
    let instructions = steps.map(\.instruction).filter { !$0.isEmpty }.joined(separator: " ")
    return TimelineRow(
      time: RecipeFormat.clock(steps[0].startOffsetS), name: stepNames(groups[group]),
      detail: rowState == .upcoming && !instructions.isEmpty ? instructions : nil,
      trailing: steps.compactMap(\.targetCumulativeWaterG).last.map {
        RecipeFormat.weight($0, units)
      },
      state: rowState, isLast: isLast
    )
    .accessibilityIdentifier("timer.step.\(groups[group][0])")
  }

  /// The finish is its own moment: what was reached against the target, then one
  /// next step. Nothing moves on until the user taps it.
  private var finishedBanner: some View {
    let early = session.outcome?.endedEarly == true
    return HStack(alignment: .top, spacing: DS.Space.md) {
      Image(systemName: early ? "stop.circle.fill" : "checkmark.circle.fill").font(.title)
        .foregroundStyle(DS.signal).accessibilityHidden(true)
        .scaleEffect(finishedShown || reduceMotion ? 1 : 0.6)
        .opacity(finishedShown ? 1 : 0)
      VStack(alignment: .leading, spacing: 2) {
        Text(early ? "Brew ended" : "Brew finished").font(.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(
          "\(RecipeFormat.clock(Int(state.elapsedS))) reached, \(RecipeFormat.clock(plan.totalDurationS)) target. "
            + (early ? "Log it with the time you reached." : "Taste it, then log how it was.")
        )
        .font(.subheadline).foregroundStyle(DS.ink2)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper, border: DS.signal)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("timer.finished")
    .onAppear {
      withAnimation(reduceMotion ? .easeOut(duration: 0.2) : DS.flavor.motion.transition) {
        finishedShown = true
      }
    }
  }

  // MARK: Controls

  private var controls: some View {
    VStack(spacing: DS.Space.sm) {
      SteelButton(title: primaryTitle, action: primaryAction)
        .disabled(logged)
        .accessibilityIdentifier("timer.primary")
      if running {
        let layout =
          dts.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: DS.Space.sm))
          : AnyLayout(HStackLayout(spacing: DS.Space.sm))
        layout {
          if state.targetReached {
            textButton(state.phase == .paused ? "Resume" : "Pause", id: "timer.pause") {
              state.phase == .paused ? session.resume() : session.pause()
            }
          } else {
            textButton("Skip step", id: "timer.skip") { session.skipToNextStep() }
            textButton("End brew", id: "timer.end") { confirmsEnd = true }
          }
        }
      }
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
    .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) { Hairline().opacity(0.5) }
    .animation(motion, value: state.targetReached)
  }

  private func textButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .font(.body.weight(.semibold)).foregroundStyle(DS.ink)
      .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
      .accessibilityIdentifier(id)
  }

  private var primaryTitle: String {
    switch state.phase {
    case .notStarted: "Start"
    case .running: state.targetReached ? "Finish brew" : "Pause"
    case .paused: state.targetReached ? "Finish brew" : "Resume"
    case .finished: logged ? "Brew logged" : "Taste and log"
    }
  }

  private func primaryAction() {
    switch state.phase {
    case .notStarted: session.start()
    case .running: state.targetReached ? session.finish() : session.pause()
    case .paused: state.targetReached ? session.finish() : session.resume()
    case .finished:
      if let outcome = session.outcome {
        seed = setup.seed(elapsedS: outcome.elapsedS, endedEarly: outcome.endedEarly)
      }
    }
  }

  // MARK: Accessibility

  /// Tells VoiceOver which step began, since the screen changes without a tap.
  private func announce(stepAt index: Int?) {
    guard let index, index < plan.steps.count, state.phase == .running else { return }
    let step = plan.steps[index]
    var words = step.label
    if let target = step.targetCumulativeWaterG {
      let unit = units.weight == .grams ? "grams" : "ounces"
      words += ", to \(RecipeFormat.weight(target, units, withSymbol: false)) \(unit)"
    }
    AccessibilityNotification.Announcement(words).post()
  }
}
