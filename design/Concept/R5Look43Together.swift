import SwiftUI

// 43. Together (Filtru guide + Beanconqueror logbook). Organizing idea: calm and light where you
// read and record, dark and focused where you brew. The journal opens with the method circles and
// lists cups as label/value cards; the timer is the Filtru gauge on near-black; the log is one card.

private enum C {
    static let bg = Color(0xF6F5F2, 0x111111)
    static let card = Color(0xFFFFFF, 0x1C1C1E)
    static let line = Color(0xE7E3DD, 0x2C2C2E)
    static let accent = Color(0xB87A2B, 0xE0A458)
    static let night = Color(0x0F0F10, 0x0F0F10)
    static let nightRing = Color(0x27272B, 0x27272B)
    static let gauge = Color(0xE0A458, 0xE0A458)
}

struct Look43: View {
    var body: some View {
        ConceptShell(tint: C.accent) { LookRecipe(model: $0) } timer: { Timer43(model: $0) }
            log: { Log43(model: $0) } journal: { Home43(model: $0) }
    }
}

private struct Home43: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(Array(MethodIcons.all.enumerated()), id: \.offset) { i, m in
                            Button { model.showTimer = true } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: m.1).font(.system(size: 26, weight: .light)).foregroundStyle(i == 0 ? C.accent : .primary)
                                        .frame(width: 68, height: 68).background(C.card, in: .circle)
                                        .overlay(Circle().stroke(i == 0 ? C.accent : C.line, lineWidth: 1))
                                    Text(m.0).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(PressScale()).accessibilityLabel("Brew \(m.0)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden).padding(.horizontal, -20)
                Text("Recent").font(.headline)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(e.bean).font(.body.weight(.medium))
                            Spacer()
                            Text(Fmt.day(e.date)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Rectangle().fill(C.line).frame(height: 1)
                        HStack(alignment: .top) {
                            kv("Method", e.method)
                            kv("Brew", "\(Fmt.num(e.doseG)) : \(Fmt.num(e.waterG))")
                            kv("Time", Fmt.clock(e.timeS))
                            kv("Rating", Fmt.num(Double(e.ratingHalfSteps) / 2) + " ★")
                        }
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 16))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(C.bg)
        .navigationTitle("Next Cup")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true } } }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption2).foregroundStyle(.secondary)
            Text(v).font(.footnote).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Timer43: View {
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
                    Button("Finish", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                }
                HStack(spacing: 4) {
                    ForEach(r.steps) { st in Capsule().fill(st.id <= index ? C.gauge : C.nightRing).frame(height: 3) }
                }
                .accessibilityHidden(true)
                Spacer(minLength: 0)
                ScaleGauge(grams: g, target: s.cumulativeG, fraction: frac, tint: C.gauge, track: C.nightRing).frame(width: 300, height: 300)
                VStack(spacing: 8) {
                    Text(s.instruction).font(.title3).multilineTextAlignment(.center)
                    if let n = model.nextStep(after: index) {
                        Text("Next at \(Fmt.clock(n.startS)): \(n.kind.label.lowercased())").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                    .labelStyle(.iconOnly).font(.title).foregroundStyle(.black).frame(width: 76, height: 76).background(C.gauge, in: .circle)
                    .contentTransition(.symbolEffect(.replace)).buttonStyle(PressScale(scale: 0.92))
            }
            .foregroundStyle(.white).padding(20)
            .background(C.night.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct Log43: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 12) {
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.accent, size: 30)
                        HStack(spacing: 6) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? .white : .primary).background(on ? C.accent : .clear, in: .capsule)
                                    .overlay(Capsule().stroke(on ? C.accent : C.line))
                            }
                        }
                    }
                    VStack(spacing: 0) {
                        row("Dose", "\(Fmt.num(model.draft.doseG)) g", "\(Fmt.num(model.recipe.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        Rectangle().fill(C.line).frame(height: 1)
                        row("Water", "\(Fmt.num(model.draft.waterG)) g", "\(Fmt.num(model.recipe.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        Rectangle().fill(C.line).frame(height: 1)
                        row("Temperature", "\(Fmt.num(model.draft.tempC)) °C", "\(Fmt.num(model.recipe.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                    .padding(.horizontal, 16).background(C.card, in: .rect(cornerRadius: 16))
                    TextField("Notes", text: $model.draft.notes, axis: .vertical).lineLimit(2...5).padding(16).background(C.card, in: .rect(cornerRadius: 16))
                }
                .padding(20)
            }
            .background(C.bg)
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.accent) }
            }
        }
    }

    private func row(_ k: String, _ v: String, _ target: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(k).font(.subheadline)
                Text("Recipe \(target)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 44, height: 44)
            Text(v).monospacedDigit().frame(minWidth: 68)
            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 44, height: 44)
        }
        .labelStyle(.iconOnly).foregroundStyle(.primary).frame(minHeight: 60)
    }
}
