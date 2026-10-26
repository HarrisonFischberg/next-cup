import SwiftUI
@preconcurrency import UserNotifications

// 44. Daily loop (look 43's clean style, Harold's functionality brief). One loop a day:
// 1. Today's brew: bean (scan the bag, or type roaster, name, roast), method, grams of beans and water.
// 2. Brew with the gauge timer.
// 3. "Done" schedules a reminder 20 minutes later to taste.
// 4. Taste: pick what you notice, rate it.
// 5. Next cup: one change for tomorrow, with the reason, and what to keep.

private enum C {
    static let bg = Color(0xF6F5F2, 0x111111)
    static let card = Color(0xFFFFFF, 0x1C1C1E)
    static let line = Color(0xE7E3DD, 0x2C2C2E)
    static let accent = Color(0xB87A2B, 0xE0A458)
    static let night = Color(0x0F0F10, 0x0F0F10)
    static let nightRing = Color(0x27272B, 0x27272B)
    static let gauge = Color(0xE0A458, 0xE0A458)
}

private let tasteDelayMin = 20

/// One change for the next cup from how it tasted (the same direction as DialInRules in the app).
private func nextCupTip(_ v: Verdict?, grind: Int, dose: Double, water: Double) -> (title: String, from: String, to: String, why: String) {
    switch v {
    case .sour: ("Grind one step finer", "\(grind)", "\(grind - 1)", "Sour and thin means the water ran through too fast. Finer grounds slow it down and pull more sweetness.")
    case .bitter: ("Grind one step coarser", "\(grind)", "\(grind + 1)", "Bitter and dry means too much was pulled out. Coarser grounds let the water through sooner.")
    case .weak: ("Use a little more coffee", "\(Fmt.num(dose)) g", "\(Fmt.num(dose + 1)) g", "Weak means too much water for the coffee. One more gram makes the cup fuller without changing the grind.")
    case .strong: ("Add a little more water", "\(Fmt.num(water)) g", "\(Fmt.num(water + 20)) g", "Strong and heavy means the cup is too concentrated. More water opens it up.")
    default: ("Keep everything the same", "", "", "It tasted balanced. Brew it the same way tomorrow to be sure it repeats.")
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

struct Look44: View {
    var body: some View {
        ConceptShell(tint: C.accent) { Today44(model: $0) } timer: { Timer44(model: $0) }
            log: { Taste44(model: $0) } journal: { Home44(model: $0) }
    }
}

// MARK: Home: what's waiting (taste) and what's next (tip), then recent cups

private struct Home44: View {
    let model: FlowModel
    var body: some View {
        let last = model.journal.first
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Taste in 14 min", systemImage: "bell").font(.footnote.weight(.semibold)).foregroundStyle(C.accent)
                    Text("Today's Kenya Kiambu AA").font(.title3.weight(.semibold))
                    Text("Brewed at 9:41. We'll remind you to note how it tastes once it has cooled a little.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Taste now") { model.prefillFromRecipe(measuredS: 184); model.showLog = true }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(C.accent).frame(minHeight: 44)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 16))
                if let last {
                    let tip = nextCupTip(last.verdict == .balanced ? .sour : last.verdict, grind: last.grind, dose: last.doseG, water: last.waterG)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOR YOUR NEXT CUP").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                        Text(tip.title).font(.headline)
                        if !tip.from.isEmpty {
                            HStack(spacing: 8) {
                                Text(tip.from).foregroundStyle(.secondary).strikethrough()
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                                Text(tip.to).foregroundStyle(C.accent).fontWeight(.semibold)
                            }
                            .font(.title3).monospacedDigit()
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 16))
                }
                Button { model.tab = .recipes } label: {
                    Label("Start today's brew", systemImage: "plus").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white).background(C.accent, in: .capsule)
                }
                .buttonStyle(PressScale())
                Text("Recent").font(.headline).padding(.top, 6)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.bean).font(.body)
                            Text("\(e.method) · \(Fmt.num(e.doseG)) g : \(Fmt.num(e.waterG)) g · \(e.verdict?.label ?? "")").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.day(e.date)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1) }
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(C.bg)
        .navigationTitle("Next Cup")
    }
}

// MARK: 1. Today's brew

private struct Today44: View {
    let model: FlowModel
    @State private var roaster = "Kiambu Estate"
    @State private var bean = "Kenya Kiambu AA"
    @State private var roast = "Light"
    @State private var method = 0
    @State private var dose = 20.0
    @State private var water = 320.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Same as yesterday, with tomorrow's tip applied.").font(.subheadline).foregroundStyle(.secondary)
                section("Bean") {
                    Button { } label: {
                        Label("Scan the bag", systemImage: "camera.viewfinder").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(C.accent).overlay(RoundedRectangle(cornerRadius: 12).stroke(C.accent, style: .init(lineWidth: 1.2, dash: [5, 4])))
                    }
                    Text("Reads the roaster, name, origin and roast date on the device with Apple Intelligence, or with your own AI key.")
                        .font(.caption).foregroundStyle(.secondary)
                    field("Roaster", $roaster)
                    field("Coffee", $bean)
                    HStack {
                        Text("Roast").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Roast", selection: $roast) { ForEach(["Light", "Medium", "Dark"], id: \.self) { Text($0) } }.pickerStyle(.segmented).frame(width: 210)
                    }
                    .frame(minHeight: 44)
                }
                section("Method") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(Array(MethodIcons.all.enumerated()), id: \.offset) { i, m in
                                Button { method = i } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: m.1).font(.system(size: 22, weight: .light)).frame(width: 56, height: 56)
                                            .foregroundStyle(method == i ? C.accent : .primary)
                                            .overlay(Circle().stroke(method == i ? C.accent : C.line, lineWidth: method == i ? 1.5 : 1))
                                        Text(m.0).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityLabel(m.0).accessibilityAddTraits(method == i ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                section("Grams") {
                    grams("Beans", $dose, 0.5)
                    Rectangle().fill(C.line).frame(height: 1)
                    grams("Water", $water, 5)
                    Text("Ratio 1:\(Fmt.num((water / dose * 10).rounded() / 10)) · grind 22 (one step finer than yesterday)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(C.bg)
        .navigationTitle("Today's brew")
        .safeAreaInset(edge: .bottom) {
            Button("Start brewing") { model.showTimer = true }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54)
                .background(C.accent, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 20).padding(.bottom, 8)
        }
    }

    private func section<V: View>(_ t: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) { v() }.padding(16).background(C.card, in: .rect(cornerRadius: 16))
        }
    }
    private func field(_ k: String, _ b: Binding<String>) -> some View {
        HStack {
            Text(k).font(.subheadline).foregroundStyle(.secondary)
            TextField(k, text: b).multilineTextAlignment(.trailing).textContentType(.none)
        }
        .frame(minHeight: 44)
    }
    private func grams(_ k: String, _ b: Binding<Double>, _ step: Double) -> some View {
        let st = b.stepped(by: step, in: 1...1000)
        return HStack {
            Text(k).font(.subheadline)
            Spacer()
            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 44, height: 44)
            Text("\(Fmt.num(b.wrappedValue)) g").font(.title3).monospacedDigit().frame(minWidth: 76)
            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 44, height: 44)
        }
        .labelStyle(.iconOnly).foregroundStyle(.primary)
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
            VStack(spacing: 22) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.headline).monospacedDigit().contentTransition(.numericText())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                HStack(spacing: 4) { ForEach(r.steps) { st in Capsule().fill(st.id <= index ? C.gauge : C.nightRing).frame(height: 3) } }
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                ScaleGauge(grams: g, target: s.cumulativeG, fraction: frac, tint: C.gauge, track: C.nightRing).frame(width: 290, height: 290)
                Text(s.instruction).font(.title3).multilineTextAlignment(.center).padding(.horizontal, 24)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                        .labelStyle(.iconOnly).font(.title2).foregroundStyle(.black).frame(width: 64, height: 64).background(C.gauge, in: .circle)
                    Button {
                        scheduleTasteReminder(bean: model.draft.bean)
                        model.pauseTimer(); model.showTimer = false
                    } label: {
                        VStack(spacing: 2) {
                            Text("Done, enjoy").font(.headline)
                            Text("We'll ask how it tastes in \(tasteDelayMin) min").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64).background(C.nightRing, in: .capsule)
                    }
                }
                .buttonStyle(PressScale())
            }
            .foregroundStyle(.white).padding(20)
            .background(C.night.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: 4-5. Taste, then the next-cup tip

private struct Taste44: View {
    @Bindable var model: FlowModel
    @State private var showNext = ProcessInfo.processInfo.arguments.contains("-next")
    private let notes: [(Verdict, String)] = [(.sour, "Sharp, thin, lemony"), (.bitter, "Dry, harsh, ashy"), (.weak, "Watery, light"),
                                             (.strong, "Heavy, intense"), (.balanced, "Sweet, round, clean")]

    var body: some View {
        NavigationStack {
            Group { if showNext { next } else { taste } }
                .background(C.bg)
                .navigationTitle(showNext ? "Your next cup" : "How does it taste?").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
                .animation(.spring(duration: 0.35), value: showNext)
        }
        .onAppear { if showNext && model.draft.verdict == nil { model.draft.verdict = .sour; model.draft.ratingHalfSteps = 7 } }
    }

    private var taste: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("\(model.draft.bean) · brewed \(tasteDelayMin) min ago", systemImage: "bell").font(.footnote).foregroundStyle(.secondary)
                ForEach(notes, id: \.0) { v, desc in
                    let on = model.draft.verdict == v
                    Button { model.draft.verdict = on ? nil : v } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.label).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Text(desc).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(on ? C.accent : C.line)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 62).background(C.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? C.accent : .clear, lineWidth: 1.5))
                    }
                    .accessibilityAddTraits(on ? .isSelected : []).sensoryFeedback(.selection, trigger: on)
                }
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.accent, size: 28).frame(maxWidth: .infinity)
                TextField("Anything else? (optional)", text: $model.draft.notes, axis: .vertical).lineLimit(1...4)
                    .padding(14).background(C.card, in: .rect(cornerRadius: 14))
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("See tomorrow's tip") { showNext = true }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54)
                .background(C.accent, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 20).padding(.bottom, 8)
                .disabled(model.draft.verdict == nil).opacity(model.draft.verdict == nil ? 0.5 : 1)
        }
    }

    private var next: some View {
        let d = model.draft
        let tip = nextCupTip(d.verdict, grind: d.grind, dose: d.doseG, water: d.waterG)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("You said: \(d.verdict?.label.lowercased() ?? "–"), \(Fmt.stars(d.ratingHalfSteps).lowercased()).").font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Change one thing").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    Text(tip.title).font(.title2.weight(.semibold))
                    if !tip.from.isEmpty {
                        HStack(spacing: 12) {
                            Text(tip.from).foregroundStyle(.secondary).strikethrough()
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(tip.to).foregroundStyle(C.accent).fontWeight(.semibold)
                        }
                        .font(.system(size: 34, design: .rounded)).monospacedDigit()
                    }
                    Text(tip.why).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Keep the same").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    HStack {
                        keep("Beans", "\(Fmt.num(d.doseG)) g"); keep("Water", "\(Fmt.num(d.waterG)) g"); keep("Temp", "\(Fmt.num(d.tempC))°"); keep("Method", "Cone")
                    }
                }
                .padding(18).background(C.card, in: .rect(cornerRadius: 16))
                Text("Tomorrow's brew will open with this already set.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Not this time") { model.save() }.frame(maxWidth: .infinity, minHeight: 54).background(C.card, in: .capsule).foregroundStyle(.primary)
                Button("Use tomorrow") { model.save() }.frame(maxWidth: .infinity, minHeight: 54).background(C.accent, in: .capsule).foregroundStyle(.white)
            }
            .font(.headline).buttonStyle(PressScale()).padding(.horizontal, 20).padding(.bottom, 8)
        }
    }

    private func keep(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(k).font(.caption2).foregroundStyle(.secondary); Text(v).font(.subheadline).monospacedDigit() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
