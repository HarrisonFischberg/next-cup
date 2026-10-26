import SwiftUI

// 41. Guide (Filtru). Organizing idea: a quiet dark brewing guide. Home is "Prepare coffee":
// brew methods as thin line icons in circles, then your last cups. The timer is the scale gauge
// with one sentence of instruction and a small step bar; nothing else on screen.

private enum C {
    static let bg = Color(0xF5F4F2, 0x0E0E0F)
    static let surface = Color(0xFFFFFF, 0x1A1A1C)
    static let ring = Color(0xE8E6E2, 0x26262A)
    static let amber = Color(0xC98A12, 0xF2A93B)
    static let blue = Color(0x3E5BD9, 0x5B7CFA)
}

struct Look41: View {
    var body: some View {
        ConceptShell(tint: C.amber) { LookRecipe(model: $0) } timer: { Timer41(model: $0) }
            log: { Log41(model: $0) } journal: { Prepare41(model: $0) }
    }
}

private struct Prepare41: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brew methods").font(.title3.weight(.semibold))
                    Text("Select a guide to start").font(.subheadline).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                    ForEach(Array(MethodIcons.all.enumerated()), id: \.offset) { i, m in
                        Button { model.showTimer = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: m.1).font(.system(size: 34, weight: .ultraLight)).foregroundStyle(i == 0 ? C.amber : .primary)
                                    .frame(width: 84, height: 84).background(C.surface, in: .circle)
                                Text(m.0).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(PressScale()).accessibilityLabel("Brew \(m.0)")
                    }
                }
                Text("Last cups").font(.title3.weight(.semibold))
                VStack(spacing: 0) {
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.bean).font(.body)
                                Text("\(e.method) · \(Fmt.num(e.doseG)) g · \(Fmt.clock(e.timeS))").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.body.weight(.medium)).monospacedDigit()
                            Image(systemName: "star.fill").font(.caption).foregroundStyle(C.amber)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 64)
                        .overlay(alignment: .bottom) { if i < model.journal.count - 1 { Rectangle().fill(C.ring).frame(height: 1).padding(.leading, 16) } }
                        .accessibilityElement(children: .combine).assemble(i)
                    }
                }
                .background(C.surface, in: .rect(cornerRadius: 20))
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(C.bg)
        .navigationTitle("Prepare Coffee")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true } } }
    }
}

private struct Timer41: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let g = pouredGrams(r, at: elapsed)
            let prev = Double(r.steps[..<index].compactMap(\.cumulativeG).last ?? 0)
            let frac = s.cumulativeG.map { (g - prev) / max(1, Double($0) - prev) } ?? 1
            VStack(spacing: 26) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .frame(width: 44, height: 44).background(C.surface, in: .circle).foregroundStyle(.primary)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(r.method).font(.subheadline.weight(.semibold))
                        Text("\(index + 1) / \(r.steps.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.subheadline.weight(.medium)).monospacedDigit().frame(width: 44)
                }
                Spacer(minLength: 0)
                ScaleGauge(grams: g, target: s.cumulativeG, fraction: frac, tint: C.blue, track: C.ring).frame(width: 300, height: 300)
                Text(s.instruction).font(.title3).multilineTextAlignment(.center).padding(.horizontal, 24)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Button("Finish", systemImage: "checkmark") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 56)
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                        .font(.title2).foregroundStyle(.black).frame(width: 64, height: 64).background(C.amber, in: .circle)
                        .contentTransition(.symbolEffect(.replace))
                    Button("Steps", systemImage: "list.bullet") { }.frame(maxWidth: .infinity, minHeight: 56)
                }
                .labelStyle(.iconOnly).font(.title3).foregroundStyle(.primary)
                .padding(8).background(C.surface, in: .capsule)
            }
            .padding(20)
            .background(C.bg.ignoresSafeArea())
        }
    }
}

private struct Log41: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 14) {
                        Text("How was it?").font(.title3.weight(.semibold))
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.amber, size: 30)
                        HStack(spacing: 6) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? .black : .primary).background(on ? C.amber : C.ring, in: .capsule)
                            }
                        }
                    }
                    .padding(20).background(C.surface, in: .rect(cornerRadius: 20))
                    VStack(spacing: 0) {
                        row("Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        Rectangle().fill(C.ring).frame(height: 1).padding(.leading, 16)
                        row("Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        Rectangle().fill(C.ring).frame(height: 1).padding(.leading, 16)
                        row("Temperature", "\(Fmt.num(model.draft.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                    .background(C.surface, in: .rect(cornerRadius: 20))
                    TextField("Notes", text: $model.draft.notes, axis: .vertical).lineLimit(2...5).padding(16).background(C.surface, in: .rect(cornerRadius: 20))
                }
                .padding(20)
            }
            .background(C.bg)
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.amber) }
            }
        }
    }

    private func row(_ k: String, _ v: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Text(k)
            Spacer()
            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 44, height: 44)
            Text(v).monospacedDigit().frame(minWidth: 70)
            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 44, height: 44)
        }
        .labelStyle(.iconOnly).foregroundStyle(.primary).padding(.leading, 16).padding(.trailing, 4).frame(minHeight: 56)
    }
}
