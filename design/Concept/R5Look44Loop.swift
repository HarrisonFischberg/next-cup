import SwiftUI
@preconcurrency import UserNotifications

// 44. Daily loop (look 43's clean style, Harold's functionality brief). One loop a day:
// 1. Today's brew: bean (scan the bag, or type roaster, name, roast), method, grams of beans and water.
// 2. Brew with the gauge timer.
// 3. "Done" schedules a reminder 20 minutes later to taste.
// 4. Taste: pick what you notice, rate it.
// 5. Next cup: one change for tomorrow, with the reason, and what to keep.
//
// Signature: the loop strip (Brew, Rest, Taste, Next) that tells you where today's cup is.
// Display moments are set in New York; everything you operate stays SF and system controls.
// Liquid Glass only on the floating action bars, grouped in a GlassEffectContainer.

private enum C {
    static let bg = Color(0xF7F5F1, 0x0F0F10)
    static let card = Color(0xFFFFFF, 0x1C1C1E)
    static let line = Color(0xE6E1D9, 0x2E2E31)
    /// Accent dark enough for white label text in light (5.1:1); light enough for dark text in dark.
    static let accent = Color(0x93591A, 0xE3A75C)
    static let onAccent = Color(0xFFFFFF, 0x1A1208)
    static let wash = Color(0xF3E9DC, 0x2A2117)
    static let night = Color(0x0F0F10, 0x0F0F10)
    static let nightRing = Color(0x29292D, 0x29292D)
    static let gauge = Color(0xE3A75C, 0xE3A75C)
}

private let tasteDelayMin = 20
/// The grinder saved with this bean (per bean in the real app, so each bag keeps its own setting).
private let beanGrinder = "Comandante C40 MK4"

private extension Font {
    static func display(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font { .system(style, design: .serif, weight: weight) }
}

/// One change for the next cup from how it tasted (the same direction as DialInRules in the app).
private func nextCupTip(_ v: Verdict?, grind: Int, dose: Double, water: Double) -> (title: String, unit: String, from: String, to: String, why: String) {
    switch v {
    case .sour: ("Grind one click finer", "Clicks", "\(grind)", "\(grind - 1)", "Sour and thin means the water ran through too fast. Finer grounds slow it down and pull out more sweetness.")
    case .bitter: ("Grind one click coarser", "Clicks", "\(grind)", "\(grind + 1)", "Bitter and dry means too much was pulled out. Coarser grounds let the water through sooner.")
    case .weak: ("Use a little more coffee", "Beans", Fmt.num(dose), Fmt.num(dose + 1), "Weak means too much water for the coffee. One more gram fills the cup out without touching the grind.")
    case .strong: ("Add a little more water", "Water", Fmt.num(water), Fmt.num(water + 20), "Strong and heavy means the cup is too concentrated. A little more water opens it up.")
    default: ("Brew it the same way", "", "", "", "It tasted balanced. Make it the same way tomorrow to see that it repeats.")
    }
}

/// Asks once, in context (right after the first brew), then schedules the taste reminder.
private func scheduleTasteReminder(bean: String) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "How's your \(bean)?"
        content.body = "Take a sip and note how it tastes. It takes ten seconds."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(tasteDelayMin * 60), repeats: false)
        center.add(UNNotificationRequest(identifier: "taste-reminder", content: content, trigger: trigger))
    }
}

// MARK: Signature: the loop strip

private enum Station: Int, CaseIterable {
    case brew, rest, taste, next
    var label: String { ["Brew", "Rest", "Taste", "Next"][rawValue] }
}

/// Four stations on a hairline; done ones filled, the current one ringed and labelled in the accent.
private struct LoopStrip: View {
    let at: Station
    var detail: String?
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Station.allCases, id: \.self) { s in
                    let done = s.rawValue < at.rawValue, now = s == at
                    HStack(spacing: 0) {
                        ZStack {
                            Circle().fill(done ? tint : .clear).frame(width: 9, height: 9)
                            Circle().stroke(done || now ? tint : rule, lineWidth: 1.5).frame(width: now ? 15 : 9, height: now ? 15 : 9)
                        }
                        .frame(width: 16)
                        if s != .next { Rectangle().fill(done ? tint : rule).frame(height: 1.5) }
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Station.allCases, id: \.self) { s in
                    Text(s.label).font(.caption.weight(s == at ? .semibold : .regular))
                        .foregroundStyle(s == at ? tint : .secondary)
                        .frame(maxWidth: s == .next ? nil : .infinity, alignment: .leading)
                }
            }
            if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary).padding(.top, 2) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's cup: \(at.label) step\(detail.map { ". \($0)" } ?? "")")
    }

    private var tint: Color { dark ? C.gauge : C.accent }
    private var rule: Color { dark ? C.nightRing : C.line }
}

/// A glass bar of actions floating above content; Reduce Transparency gets solid buttons from the system styles.
private struct ActionBar<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            ViewThatFits(in: .horizontal) { HStack(spacing: 12) { content }; VStack(spacing: 10) { content } }
        }
            .padding(.horizontal, 20).padding(.bottom, 8)
    }
}

struct Look44: View {
    var body: some View {
        ConceptShell(tint: C.accent) { Today44(model: $0) } timer: { Timer44(model: $0) }
            log: { Taste44(model: $0) } journal: { Home44(model: $0) }
    }
}

// MARK: Home: where today's cup is, tomorrow's change, then the journal

private struct Home44: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                today
                if let last = model.journal.first { tomorrow(last) }
                journal
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(C.bg)
        .navigationTitle("Next Cup")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Start today's brew", systemImage: "plus") { model.tab = .recipes }
            }
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Kenya Kiambu AA").font(.display(.title, .medium))
                Text("Brewed at 9:41 on the cone dripper").font(.subheadline).foregroundStyle(.secondary)
            }
            LoopStrip(at: .rest, detail: "Resting so the flavours open up. We'll ask how it tastes at 10:01.")
            Button("Taste it now") { model.prefillFromRecipe(measuredS: 184); model.showLog = true }
                .buttonStyle(.glassProminent).tint(C.accent).foregroundStyle(C.onAccent).controlSize(.large)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(C.card, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func tomorrow(_ last: JournalEntry) -> some View {
        let tip = nextCupTip(.sour, grind: last.grind, dose: last.doseG, water: last.waterG)
        return ViewThatFits(in: .horizontal) { tomorrowRow(tip, stacked: false); tomorrowRow(tip, stacked: true) }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
    }

    private func tomorrowRow(_ tip: (title: String, unit: String, from: String, to: String, why: String), stacked: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tomorrow, \(tip.title.prefix(1).lowercased() + tip.title.dropFirst())").font(.display(.title3))
                Text("On your \(beanGrinder)").font(.footnote).foregroundStyle(.secondary)
                
            }
            if !stacked { Spacer(minLength: 12) }
            if !tip.from.isEmpty {
                (Text(tip.from).foregroundStyle(.secondary) + Text(" → ").foregroundStyle(.tertiary) + Text(tip.to).foregroundStyle(C.accent))
                    .font(.title2.weight(.medium)).monospacedDigit()
            }
        }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Journal").font(.display(.title3)).padding(.bottom, 6)
            ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(e.date.formatted(.dateTime.day())).font(.display(.title3)).foregroundStyle(C.accent).monospacedDigit()
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.bean).font(.body)
                        Text("\(e.method) · \(Fmt.num(e.doseG)) g in \(Fmt.num(e.waterG)) g").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(e.verdict?.label ?? "").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { if i < model.journal.count - 1 { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 42) } }
                .accessibilityElement(children: .combine).assemble(i)
            }
        }
    }
}

// MARK: 1. Today's brew

private struct Today44: View {
    let model: FlowModel
    @State private var roaster = "Kiambu Estate"
    @State private var bean = "Kenya Kiambu AA"
    @State private var roast = "Light"
    @State private var method = "Cone"
    @State private var dose = 20.0
    @State private var water = 320.0
    @State private var grinder = beanGrinder
    @State private var setting = "22"
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                LoopStrip(at: .brew, detail: "Yesterday's brew, with tomorrow's change already in.")
                beanCard
                grams
                methods
                grind
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
        }
        .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("-grind") ? .bottom : .top) // screenshots of the grind card
        .background(C.bg)
        .navigationTitle("Today's brew")
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button { model.showTimer = true } label: {
                    Label("Start brewing", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.glassProminent).tint(C.accent).foregroundStyle(C.onAccent).controlSize(.large)
            }
        }
    }

    private var beanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            (dts.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top))) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Roaster", text: $roaster).font(.subheadline).foregroundStyle(.secondary)
                    TextField("Coffee", text: $bean, axis: .vertical).font(.display(.title2, .medium))
                }
                Button("Scan the bag", systemImage: "camera.viewfinder") { }
                    .labelStyle(.iconOnly).font(.title3).buttonStyle(.glass).controlSize(.large)
            }
            Picker("Roast", selection: $roast) { ForEach(["Light", "Medium", "Dark"], id: \.self) { Text($0) } }
                .pickerStyle(.segmented)
            Text("Scan the bag to fill these in. Apple Intelligence reads it on your iPhone; your own AI key works too.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20).background(C.card, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private var methods: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method").font(.display(.title3))
            ScrollView(.horizontal) {
                HStack(spacing: 18) {
                    ForEach(MethodIcons.all, id: \.0) { name, symbol in
                        let on = method == name
                        Button { method = name } label: {
                            VStack(spacing: 8) {
                                Image(systemName: symbol).font(.title2.weight(.light)).frame(width: 60, height: 60)
                                    .foregroundStyle(on ? C.onAccent : .primary)
                                    .background(on ? C.accent : C.card, in: .circle)
                                    .overlay(Circle().stroke(on ? .clear : C.line, lineWidth: 1))
                                Text(name).font(.caption).foregroundStyle(on ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(PressScale()).accessibilityLabel(name).accessibilityAddTraits(on ? .isSelected : [])
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden).padding(.horizontal, -20)
        }
    }

    private var grams: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Grams").font(.display(.title3))
                Spacer()
                Text("1 : \(Fmt.num((water / dose * 10).rounded() / 10))").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 12) {
                amount("Beans", $dose, 0.5)
                amount("Water", $water, 5)
            }
        }
    }

    private var grind: some View {
        let g = GrinderGuide.all.first { $0.name == grinder }
        let range = g?.range(for: method)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Grind").font(.display(.title3))
            VStack(alignment: .leading, spacing: 14) {
                Menu {
                    Picker("Grinder", selection: $grinder) {
                        Section("Hand") { ForEach(GrinderGuide.all.filter { $0.kind == "Hand" }) { Text($0.name).tag($0.name) } }
                        Section("Electric") { ForEach(GrinderGuide.all.filter { $0.kind == "Electric" }) { Text($0.name).tag($0.name) } }
                    }
                } label: {
                    HStack {
                        Text(grinder).font(.body).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44).contentShape(.rect)
                }
                .accessibilityLabel("Grinder, \(grinder)")
                Rectangle().fill(C.line).frame(height: 1)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("For this bean").font(.subheadline).foregroundStyle(.secondary)
                        Text("One click finer than yesterday").font(.footnote).foregroundStyle(C.accent)
                    }
                    Spacer()
                    if g?.notation == "clicks" || g?.notation == "dial" {
                        let n = Int(setting) ?? 0
                        Button("Finer", systemImage: "minus") { setting = String(max(0, n - 1)) }.frame(width: 44, height: 44).background(C.bg, in: .circle)
                        Text(setting).font(.display(.title)).monospacedDigit().frame(minWidth: 44).contentTransition(.numericText())
                        Button("Coarser", systemImage: "plus") { setting = String(n + 1) }.frame(width: 44, height: 44).background(C.bg, in: .circle)
                    } else {
                        TextField("Setting", text: $setting).font(.display(.title)).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                }
                .labelStyle(.iconOnly).foregroundStyle(.primary).animation(.snappy(duration: 0.2), value: setting)
                if let g {
                    Text(range.map { "Starting range for \(method.lowercased()): \($0) \(g.unitLabel). A starting point only; every grinder and bean differs, so dial in by taste." }
                         ?? "\(g.name) is made for brewed coffee, not \(method.lowercased()).")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Source: Honest Coffee Guide", destination: URL(string: g.source)!).font(.footnote)
                }
            }
            .padding(16).background(C.card, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private func amount(_ k: String, _ b: Binding<Double>, _ step: Double) -> some View {
        let st = b.stepped(by: step, in: 1...1000)
        return VStack(alignment: .leading, spacing: 10) {
            Text(k).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Fmt.num(b.wrappedValue)).font(.display(.largeTitle)).monospacedDigit().contentTransition(.numericText())
                Text("g").font(.headline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button("Less \(k.lowercased())", systemImage: "minus", action: st.down).frame(maxWidth: .infinity, minHeight: 44)
                    .background(C.bg, in: .capsule)
                Button("More \(k.lowercased())", systemImage: "plus", action: st.up).frame(maxWidth: .infinity, minHeight: 44)
                    .background(C.bg, in: .capsule)
            }
            .labelStyle(.iconOnly).font(.headline).foregroundStyle(.primary).buttonStyle(PressScale(scale: 0.92))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(C.card, in: .rect(cornerRadius: 22, style: .continuous))
        .animation(.spring(duration: 0.25), value: b.wrappedValue)
    }
}

// MARK: 2-3. Brew, then Done schedules the taste reminder

private struct Timer44: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let g = pouredGrams(r, at: elapsed)
            let prev = Double(r.steps[..<index].compactMap(\.cumulativeG).last ?? 0)
            let frac = s.cumulativeG.map { (g - prev) / max(1, Double($0) - prev) } ?? 1
            VStack(spacing: 24) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(Fmt.clock(Int(elapsed))).font(.headline).monospacedDigit().contentTransition(.numericText())
                        Text("of \(Fmt.clock(r.totalS))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                HStack(spacing: 4) { ForEach(r.steps) { st in Capsule().fill(st.id <= index ? C.gauge : C.nightRing).frame(height: 3) } }
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                ScaleGauge(grams: g, target: s.cumulativeG, fraction: frac, tint: C.gauge, track: C.nightRing).frame(width: 290, height: 290)
                VStack(spacing: 8) {
                    Text(s.instruction).font(.display(.title2)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if let n = model.nextStep(after: index) {
                        Text("Then \(n.kind.label.lowercased()) at \(Fmt.clock(n.startS))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                            .labelStyle(.iconOnly).font(.title2).foregroundStyle(.black)
                            .frame(width: 64, height: 64).glassEffect(.regular.tint(C.gauge).interactive(), in: .circle)
                            .contentTransition(.symbolEffect(.replace))
                        Button {
                            scheduleTasteReminder(bean: model.draft.bean)
                            model.pauseTimer(); model.showTimer = false
                        } label: {
                            VStack(spacing: 2) {
                                Text("Done, enjoy").font(.headline)
                                Text("We'll ask how it tastes in \(tasteDelayMin) min").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            .foregroundStyle(.white).padding(20)
            .background(C.night.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

// MARK: 4-5. Taste, then the next-cup tip

private struct Taste44: View {
    @Bindable var model: FlowModel
    @State private var showNext = ProcessInfo.processInfo.arguments.contains("-next")
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let notes: [(Verdict, String)] = [(.sour, "Sharp, thin, lemony"), (.bitter, "Dry, harsh, ashy"), (.weak, "Watery, light"),
                                             (.strong, "Heavy, intense"), (.balanced, "Sweet, round, clean")]

    var body: some View {
        NavigationStack {
            Group { if showNext { next } else { taste } }
                .background(C.bg)
                .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
        .onAppear { if showNext && model.draft.verdict == nil { model.draft.verdict = .sour; model.draft.ratingHalfSteps = 7 } }
    }

    private var taste: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LoopStrip(at: .taste, detail: "Brewed \(tasteDelayMin) minutes ago on the cone dripper.")
                Text("How does it taste?").font(.display(.largeTitle))
                VStack(spacing: 0) {
                    ForEach(notes, id: \.0) { v, desc in
                        let on = model.draft.verdict == v
                        Button { withAnimation(.snappy(duration: 0.2)) { model.draft.verdict = on ? nil : v } } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.label).font(.body.weight(on ? .semibold : .regular)).foregroundStyle(.primary)
                                    Text(desc).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2)
                                    .foregroundStyle(on ? C.accent : Color(.tertiaryLabel)).contentTransition(.symbolEffect(.replace))
                            }
                            .padding(.horizontal, 18).frame(minHeight: 64).contentShape(.rect)
                            .background(on ? C.wash : .clear)
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : []).sensoryFeedback(.selection, trigger: on)
                        if v != .balanced { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 18) }
                    }
                }
                .background(C.card).clipShape(.rect(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Overall").font(.display(.title3))
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.accent, size: 28)
                }
                TextField("Anything else you notice? (optional)", text: $model.draft.notes, axis: .vertical).lineLimit(1...4)
                    .padding(16).background(C.card, in: .rect(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button { withAnimation(.smooth(duration: 0.35)) { showNext = true } } label: {
                    Text("See tomorrow's change").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.glassProminent).tint(C.accent).foregroundStyle(C.onAccent).controlSize(.large)
                .disabled(model.draft.verdict == nil)
            }
        }
    }

    private var next: some View {
        let d = model.draft
        let tip = nextCupTip(d.verdict, grind: d.grind, dose: d.doseG, water: d.waterG)
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                LoopStrip(at: .next, detail: "You said \(d.verdict?.label.lowercased() ?? "–"), \(Fmt.stars(d.ratingHalfSteps).lowercased()).")
                VStack(alignment: .leading, spacing: 18) {
                    Text(tip.title).font(.display(.largeTitle))
                    if !tip.from.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(tip.unit).font(.subheadline).foregroundStyle(.secondary).fixedSize()
                            Text(tip.from).foregroundStyle(.secondary).strikethrough(revealed, color: .secondary)
                            Image(systemName: "arrow.right").font(.title3).foregroundStyle(.tertiary)
                            Text(revealed ? tip.to : tip.from).foregroundStyle(C.accent).contentTransition(.numericText())
                        }
                        .font(.display(.largeTitle, .medium)).monospacedDigit()
                        .accessibilityElement().accessibilityLabel("\(tip.unit) from \(tip.from) to \(tip.to)")
                    }
                    Text(tip.why).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(C.card, in: .rect(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keep the same").font(.display(.title3))
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow { keep("Beans", "\(Fmt.num(d.doseG)) g"); keep("Water", "\(Fmt.num(d.waterG)) g") }
                        GridRow { keep("Temperature", "\(Fmt.num(d.tempC)) °C"); keep("Method", "Cone dripper") }
                        GridRow { keep("Grinder", beanGrinder).gridCellColumns(2) }
                    }
                }
                Text("Tomorrow's brew opens with this change already set. You can still adjust it.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
        }
        .task {
            if reduceMotion { revealed = true; return }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) { revealed = true }
        }
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button("Not this time") { model.save() }.buttonStyle(.glass).controlSize(.large).font(.headline)
                Button { model.save() } label: { Text("Use tomorrow").font(.headline).frame(maxWidth: .infinity, minHeight: 36) }
                    .buttonStyle(.glassProminent).tint(C.accent).foregroundStyle(C.onAccent).controlSize(.large)
            }
        }
    }

    private func keep(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.footnote).foregroundStyle(.secondary)
            Text(v).font(.body).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
