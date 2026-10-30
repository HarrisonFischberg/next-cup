import NextCupKit
import SwiftUI
import UIKit

/// S05, the active brew: one screen that walks the schedule by itself. A slim music bar
/// and the step progress sit at the top; the ring counts down to the next step, the
/// instruction says what to do now, and the next step waits above Pause.
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
  @State private var laterError: String?
  /// The phone's volume is all the way down while the brew's sound is on.
  @State private var muted = false
  /// Bumped five seconds before each step change, for the get-ready haptic.
  @State private var readyCue = 0
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @AppStorage(SystemTimerHaptics.soundKey) private var sound = true
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.modelContext) private var context
  /// The app's tabs; with them, Rate after this cup lands on the Journal.
  @Environment(AppRouter.self) private var router: AppRouter?
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
    // The music and progress stay put and the rest scrolls under them; at accessibility
    // sizes they would fill the screen, so there everything scrolls together.
    VStack(alignment: .leading, spacing: DS.Space.md) {
      if !dts.isAccessibilitySize { header }
      ScrollView {
        VStack(spacing: DS.Space.lg) {
          if dts.isAccessibilitySize { header }
          if !sound, session.outcome == nil { soundPrompt }
          if muted, sound, session.outcome == nil {
            StateBanner(
              kind: .info,
              message: "Your volume is all the way down. Turn it up to hear the ticks and music."
            )
            .accessibilityIdentifier("timer.muted")
          }
          if let laterError {
            StateBanner(kind: .error, message: laterError).accessibilityIdentifier(
              "timer.laterError")
          }
          if session.outcome != nil {
            finishedBanner
          } else {
            dial
            instruction
          }
        }
        .padding(.vertical, DS.Space.sm)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.xs)
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
        .accessibilityHint("Plays a soft tick, a chime at each step, and music")
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
        muted = BrewAudio.isMuted
        try? await Task.sleep(for: .seconds(session.nextTickDelay()), tolerance: .milliseconds(5))
      }
    }
    // Coming back catches up without replaying the cues that were missed, and picks the
    // music back up if the system stopped it while the app was closed.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      session.tick(cues: false)
      if state.phase == .running { BrewAudio.shared.resume() }
    }
    .onChange(of: state.currentIndex) { _, index in announce(stepAt: index) }
    .onChange(of: state.targetReached) { _, reached in
      if reached, running { AccessibilityNotification.Announcement("Target time reached").post() }
    }
    // Five seconds out: a chime, a tap and a spoken heads-up, so no step arrives unannounced.
    .onChange(of: soon) { _, now in
      guard now, scenePhase == .active else { return }
      readyCue += 1
      BrewAudio.shared.chime()
      AccessibilityNotification.Announcement("Get ready: \(upcoming.action)").post()
    }
    .sensoryFeedback(.warning, trigger: readyCue)
    // A tick each running second; the music follows the brew: playing, paused, over.
    .onChange(of: Int(state.elapsedS)) { _, _ in
      if state.phase == .running { BrewAudio.shared.tick() }
    }
    .onChange(of: state.phase, initial: true) { _, phase in
      switch phase {
      case .running: BrewAudio.shared.playMusic()
      case .paused: BrewAudio.shared.pauseMusic()
      case .finished: BrewAudio.shared.stop()
      case .notStarted: break
      }
    }
    .onChange(of: sound) { _, on in
      if on, state.phase == .running {
        BrewAudio.shared.playMusic()
      } else if !on {
        BrewAudio.shared.stop()
      }
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      BrewAudio.shared.stop()
    }
  }

  private var header: some View {
    VStack(spacing: DS.Space.md) {
      if let song = BrewAudio.shared.nowPlaying, session.outcome == nil { musicBar(song) }
      progress
    }
  }

  /// The song playing in one slim row: title and artist, previous, play or pause, next,
  /// and how far into the song along the bottom edge.
  private func musicBar(_ song: String) -> some View {
    let audio = BrewAudio.shared
    let paused = audio.musicPaused || state.phase == .paused
    let parts = song.components(separatedBy: " · ")
    let artist = parts.dropFirst().joined(separator: " · ")
    return VStack(spacing: 0) {
      HStack(spacing: DS.Space.sm) {
        Equalizer(playing: !paused && !reduceMotion)
        Text(
          "\(Text(parts[0]).font(.footnote.weight(.semibold)).foregroundStyle(DS.ink))\(Text(artist.isEmpty ? "" : " · " + artist).font(.caption).foregroundStyle(DS.ink2))"
        )
        .lineLimit(1).truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Now playing: \(song)")
        .accessibilityIdentifier("timer.music.title")
        Group {
          Button("Previous song", systemImage: "backward.fill") { audio.skip(by: -1) }
            .accessibilityIdentifier("timer.music.previous")
          Button(
            paused ? "Play music" : "Pause music", systemImage: paused ? "play.fill" : "pause.fill"
          ) {
            audio.toggleMusic()
          }
          .foregroundStyle(DS.bg)
          .frame(width: 30, height: 30)
          .background(DS.accent, in: Circle())
          .accessibilityIdentifier("timer.music.pause")
          Button("Next song", systemImage: "forward.fill") { audio.skip(by: 1) }
            .accessibilityIdentifier("timer.music.next")
        }
        .labelStyle(.iconOnly).font(.footnote).foregroundStyle(DS.ink)
        .frame(width: DS.Size.minTap - 6, height: DS.Size.minTap).contentShape(Rectangle())
        .buttonStyle(.borderless)
      }
      .padding(.leading, DS.Space.md).padding(.trailing, DS.Space.xs)
      GeometryReader { g in
        ZStack(alignment: .leading) {
          Rectangle().fill(DS.line.opacity(0.35))
          Rectangle().fill(DS.accent).frame(width: g.size.width * audio.songProgress)
        }
      }
      .frame(height: 3)
      .accessibilityHidden(true)
    }
    .background(DS.paper)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .sensoryFeedback(.selection, trigger: song)
  }

  /// One press turns on the ticks, the step chimes and the music, even on silent.
  private var soundPrompt: some View {
    Button {
      sound = true
      BrewAudio.shared.chime()
    } label: {
      HStack(spacing: DS.Space.md) {
        Image(systemName: "speaker.wave.3.fill").font(.title.weight(.semibold))
          .foregroundStyle(DS.onSignal).frame(width: 56, height: 56)
          .background(DS.signal, in: Circle())
        VStack(alignment: .leading, spacing: 2) {
          Text("Tap for sound and music").font(DS.Font.headline).foregroundStyle(DS.ink)
          Text("A tick each second, a chime at each step, and soft music. Plays on silent too.")
            .font(.footnote).foregroundStyle(DS.ink2).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(DS.Space.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        DS.paper, in: RoundedRectangle(cornerRadius: max(DS.radius, 18), style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: max(DS.radius, 18), style: .continuous)
          .strokeBorder(DS.accent, lineWidth: 2)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Turns on timer sounds and music")
    .accessibilityIdentifier("timer.sound.prompt")
  }

  // MARK: Step timing

  /// When the current step group starts and when the next one does (or the target).
  private var span: (start: Double, end: Double)? {
    guard running, let group = currentGroup else { return nil }
    let start = Double(plan.steps[groups[group][0]].startOffsetS)
    let end =
      group + 1 < groups.count
      ? Double(plan.steps[groups[group + 1][0]].startOffsetS) : Double(plan.totalDurationS)
    return (start, end)
  }

  private var toNext: Double { span.map { max($0.end - state.elapsedS, 0) } ?? 0 }

  /// How far through the current step, 0...1.
  private var stepFraction: Double {
    guard let span, span.end > span.start else { return state.targetReached ? 1 : 0 }
    return min(max((state.elapsedS - span.start) / (span.end - span.start), 0), 1)
  }

  /// Each step as a plain command, with how long your hands are busy and the valve after it.
  private var cues: [StepCue] {
    StepCue.cues(
      plan: plan, kinds: setup.stepKinds, method: setup.methodKey, units: units)
  }

  private var cue: StepCue? {
    cues.indices.contains(currentGroup ?? 0) ? cues[currentGroup ?? 0] : nil
  }

  /// The hands-on start of the step (pouring, closing the valve, stirring); the rest is
  /// hands off.
  private var handsOn: Bool {
    guard let span, let cue, !state.targetReached else { return false }
    guard let doS = cue.doS else { return true }
    return state.elapsedS - span.start < min(doS, span.end - span.start)
  }

  /// The last five seconds before a step change or the target, once your hands are free:
  /// a short step (open the valve) says what to do before it says what comes next.
  private var soon: Bool {
    state.phase == .running && !state.targetReached && span != nil && toNext <= 5 && !handsOn
  }

  private var countdown: String { RecipeFormat.clock(Int(toNext.rounded(.up))) }

  // MARK: Progress

  /// One segment per step, as wide as the step is long; the step and the time below.
  private var progress: some View {
    let total = Double(plan.totalDurationS)
    let starts = groups.map { Double(plan.steps[$0[0]].startOffsetS) }
    let lengths = starts.indices.map {
      (starts.indices.contains($0 + 1) ? starts[$0 + 1] : total) - starts[$0]
    }
    let current = currentGroup ?? (state.phase == .notStarted ? -1 : groups.count)
    return VStack(spacing: DS.Space.xs) {
      GeometryReader { g in
        let gap: CGFloat = 4
        let width = max(g.size.width - gap * CGFloat(groups.count - 1), 0)
        HStack(spacing: gap) {
          ForEach(groups.indices, id: \.self) { group in
            let fill =
              session.outcome != nil || group < current
              ? 1 : group == current ? stepFraction : 0
            ZStack(alignment: .leading) {
              Capsule().fill(DS.line.opacity(0.35))
              Capsule().fill(DS.accent).frame(width: width * lengths[group] / total * fill)
            }
            .frame(width: width * lengths[group] / total)
          }
        }
      }
      .frame(height: 6)
      .animation(reduceMotion ? nil : .linear(duration: 0.25), value: state.elapsedS)
      .accessibilityHidden(true)
      HStack(alignment: .firstTextBaseline) {
        Text(statusLine).foregroundStyle(DS.ink2)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("timer.status")
        Spacer(minLength: DS.Space.sm)
        Text(
          "\(RecipeFormat.clock(Int(state.elapsedS))) / \(RecipeFormat.clock(plan.totalDurationS))"
        )
        .monospacedDigit().foregroundStyle(DS.ink2)
        .accessibilityLabel("Elapsed time")
        .accessibilityValue(RecipeFormat.spokenTime(Int(state.elapsedS)))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("timer.elapsed")
      }
      .font(.footnote.weight(.medium))
    }
  }

  /// Where the brew is, in words; the UI tests read it.
  private var statusLine: String {
    let count = groups.count
    switch state.phase {
    case .notStarted: return "Ready · \(count) steps"
    case .finished(let early): return early ? "Ended early" : "All \(count) steps done"
    case .running, .paused:
      var line =
        state.targetReached
        ? "Target reached · \(RecipeFormat.clock(Int(state.overtimeS))) over"
        : "Step \((currentGroup ?? 0) + 1) of \(count)"
      if state.phase == .paused { line += " · Paused" }
      return line
    }
  }

  // MARK: Ring and instruction

  /// The countdown to the next step on a ring that fills clockwise over the step.
  private var dial: some View {
    let active = handsOn || soon
    let chip: String =
      switch state.phase {
      case .notStarted: "Ready"
      case .paused: "Paused"
      default:
        state.targetReached
          ? "Target reached"
          : soon
            ? "Get ready" : handsOn ? cue?.nowChip ?? "Do it now" : "Hands off"
      }
    let number =
      state.phase == .notStarted
      ? RecipeFormat.clock(plan.totalDurationS)
      : state.targetReached ? "+" + RecipeFormat.clock(Int(state.overtimeS)) : countdown
    let caption =
      state.phase == .notStarted
      ? "total brew time"
      : state.targetReached
        ? "past the target"
        : (currentGroup ?? 0) + 1 < groups.count ? "until next step" : "until done"
    return ZStack {
      StepRing(fraction: stepFraction, color: active ? DS.accent : DS.ink2)
        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: stepFraction)
      VStack(spacing: 2) {
        Text(chip).font(.caption.weight(.bold))
          .foregroundStyle(active ? DS.bg : DS.ink2)
          .padding(.horizontal, DS.Space.sm).padding(.vertical, 3)
          .background(active ? DS.accent : DS.paper, in: Capsule())
          .contentTransition(.opacity)
        Text(number)
          .font(DS.flavor.timerReadout).monospacedDigit()
          .foregroundStyle(soon ? DS.accent : DS.ink)
          .minimumScaleFactor(0.5).lineLimit(1)
          .dynamicTypeSize(...DS.readoutCap)
          .contentTransition(.numericText(countsDown: true))
        Text(caption).font(.footnote).foregroundStyle(DS.ink2)
      }
      .padding(DS.Space.xl)
    }
    .frame(width: 230, height: 230)
    .frame(maxWidth: .infinity)
    .animation(motion, value: active)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(chip), \(caption)")
    .accessibilityValue(number)
    .accessibilityIdentifier("timer.countdown")
  }

  private var instruction: some View {
    // Ready and the hands-on part say what to do; after it, what to leave alone.
    let doing = state.phase == .notStarted || handsOn
    let title =
      state.targetReached
      ? "Let it finish draining" : (doing ? cue?.title : cue?.waitTitle) ?? ""
    let detail =
      state.targetReached
      ? "Finish brew when the last drops are through." : doing ? cue?.detail : cue?.waitDetail
    return VStack(spacing: DS.Space.sm) {
      Text(title)
        .font(DS.Font.instruction).foregroundStyle(handsOn ? DS.accent : DS.ink)
        .dynamicTypeSize(...DS.displayCap).minimumScaleFactor(0.7).lineLimit(3)
        .accessibilityAddTraits(.isHeader)
      if let detail {
        Text(detail).font(.body).foregroundStyle(DS.ink2)
      }
      if let open = cue?.valveOpen, !doing, !state.targetReached { valveBadge(open: open) }
    }
    .multilineTextAlignment(.center)
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity)
    .contentTransition(.opacity)
    .animation(textMotion, value: state.currentIndex)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("timer.current")
  }

  /// Where the valve stands, always in view on a brewer that has one.
  private func valveBadge(open: Bool) -> some View {
    Label(
      open ? "Valve open" : "Valve closed",
      systemImage: open ? "arrow.down.circle.fill" : "xmark.circle.fill"
    )
    .font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
    .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.xs)
    .background(DS.paper, in: Capsule())
    .contentTransition(.opacity)
    .accessibilityIdentifier("timer.valve")
  }

  /// What comes next, what to do, and the countdown to it.
  private var upcoming: (kicker: String, action: String, countdown: String?) {
    switch state.phase {
    case .notStarted: return ("First", cues.first?.title ?? "", nil)
    case .finished: return ("Done", "Reached \(RecipeFormat.clock(Int(state.elapsedS))).", nil)
    case .running, .paused:
      if state.targetReached { return ("Now", "Finish when it has drained.", nil) }
      if let group = currentGroup, group + 1 < groups.count {
        return (soon ? "Get ready" : "Next", cues[group + 1].title, countdown)
      }
      return ("Last step", "Finish at \(RecipeFormat.clock(plan.totalDurationS))", nil)
    }
  }

  /// The next step in advance; it turns accent in the last five seconds so the change
  /// never arrives unannounced.
  private var nextUp: some View {
    let next = upcoming
    let fg = soon ? DS.bg : DS.ink
    return HStack(alignment: .center, spacing: DS.Space.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(next.kicker.uppercased()).font(.caption.weight(.bold)).tracking(1.2)
          .foregroundStyle(soon ? DS.bg : DS.ink2)
        Text(next.action).font(DS.Font.headline).foregroundStyle(fg)
          .fixedSize(horizontal: false, vertical: true)
          .contentTransition(.opacity)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let countdown = next.countdown {
        Text(soon ? countdown : "in \(countdown)")
          .font(soon ? DS.Font.dataLarge : DS.Font.headline).monospacedDigit().foregroundStyle(fg)
          .contentTransition(.numericText(countsDown: true))
      }
    }
    .padding(DS.Space.md)
    .background(
      soon ? DS.accent : DS.paper,
      in: RoundedRectangle(cornerRadius: max(DS.radius, 16), style: .continuous)
    )
    .animation(motion, value: soon)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      [next.kicker, next.action, next.countdown.map { "in \($0)" }].compactMap { $0 }
        .joined(separator: ", ")
    )
    .accessibilityIdentifier("timer.next")
  }

  /// The finish is its own moment: the time reached, then one next step. Nothing moves
  /// on until the user taps it.
  private var finishedBanner: some View {
    let early = session.outcome?.endedEarly == true
    return VStack(spacing: DS.Space.xs) {
      Text(early ? "Brew ended" : "Brew finished").font(.headline).foregroundStyle(DS.accent)
        .accessibilityAddTraits(.isHeader)
      Text(RecipeFormat.clock(Int(state.elapsedS)))
        .font(DS.flavor.timerReadout).monospacedDigit().foregroundStyle(DS.ink)
        .minimumScaleFactor(0.5).lineLimit(1)
        .dynamicTypeSize(...DS.readoutCap)
        .accessibilityLabel(RecipeFormat.spokenTime(Int(state.elapsedS)))
      Text("Rate it after this cup, or while you sip.")
        .font(.subheadline).foregroundStyle(DS.ink2)
    }
    .multilineTextAlignment(.center)
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity)
    .panel(DS.paper)
    .scaleEffect(finishedShown || reduceMotion ? 1 : 0.94)
    .opacity(finishedShown ? 1 : 0)
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
      // Pinned above the controls, so the next step is always in view ahead of time.
      if session.outcome == nil { nextUp }
      SteelButton(title: primaryTitle, action: primaryAction)
        .disabled(logged)
        .accessibilityIdentifier("timer.primary")
      if session.outcome != nil, !logged {
        SteelButton(title: "Rate while sippin’", kind: .secondary, action: rateNow)
          .accessibilityIdentifier("timer.rateNow")
      }
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
    case .finished: logged ? "Brew logged" : "Rate after this cup"
    }
  }

  private func primaryAction() {
    switch state.phase {
    case .notStarted: session.start()
    case .running: state.targetReached ? session.finish() : session.pause()
    case .paused: state.targetReached ? session.finish() : session.resume()
    case .finished: rateLater()
    }
  }

  private var finishedSeed: BrewFormSeed? {
    session.outcome.map { setup.seed(elapsedS: $0.elapsedS, endedEarly: $0.endedEarly) }
  }

  private func rateNow() { seed = finishedSeed }

  /// Saves the brew as an unsaved brew in the Journal, the same draft the form
  /// would write, so rating it later opens with the time and amounts in place.
  private func rateLater() {
    guard let seed = finishedSeed else { return }
    let draftStore = BrewFormView.draft(for: seed) ?? .newBrew()
    let model = BrewFormModel(seed: seed, store: Store(context: context), draftStore: draftStore)
    if model.notice?.kind == .error {
      laterError = "This brew could not be saved for later. Rate it now to keep it."
      return
    }
    logged = true
    router?.showJournal(savedLater: draftStore.fileURL.deletingPathExtension().lastPathComponent)
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

/// The current step on a ring that fills clockwise from twelve, with a dot at the tip.
private struct StepRing: View {
  let fraction: Double
  let color: Color

  var body: some View {
    GeometryReader { g in
      let line: CGFloat = 12
      let r = min(g.size.width, g.size.height) / 2 - line
      let angle = (fraction * 360 - 90) * .pi / 180
      ZStack {
        Circle().stroke(DS.line.opacity(0.35), lineWidth: line)
        Circle().trim(from: 0, to: fraction)
          .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Circle().fill(DS.ink).frame(width: line * 1.6, height: line * 1.6)
          .offset(x: r * cos(angle), y: r * sin(angle))
      }
      .frame(width: r * 2, height: r * 2)
      .frame(width: g.size.width, height: g.size.height)
    }
    .accessibilityHidden(true)
  }
}

/// Four bars that bob while the music plays and rest when it is paused.
private struct Equalizer: View {
  let playing: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 12, paused: !playing)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(0..<4, id: \.self) { i in
          Capsule()
            .frame(
              width: 3,
              height: playing ? 4 + 10 * abs(sin(t * (2.5 + Double(i) * 0.7) + Double(i))) : 4)
        }
      }
      .frame(height: 14, alignment: .bottom)
    }
    .foregroundStyle(DS.accent)
    .accessibilityHidden(true)
  }
}
