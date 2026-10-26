import SwiftUI

// 37. Session List (Google Health / Fitbit workout). Organizing idea: a calm, rounded list
// where every step is a tinted tile with an icon square and a check, under a small pill clock
// and three headline stats. Generous corner radii, soft tonal fills, no hard lines.

private enum C {
    static let page = Color(0xFFFFFF, 0x111318)
    static let tile = Color(0xEEF2FA, 0x1D2230)
    static let icon = Color(0xD5E3FF, 0x2B3A5C)
    static let blue = Color(0x0B57D0, 0xA8C7FA)
    static let teal = Color(0x00796B, 0x5BD6C4)
}

struct Look37: View {
    var body: some View {
        ConceptShell(tint: C.blue) { LookRecipe(model: $0) } timer: { Session37(model: $0) }
            log: { Log37(model: $0) } journal: { List37(model: $0) }
    }
}

private func tileRow(symbol: String, title: String, subtitle: String, done: Bool, live: Bool = false) -> some View {
    HStack(spacing: 14) {
        Image(systemName: symbol).font(.title3).foregroundStyle(C.blue).frame(width: 52, height: 52).background(C.icon, in: .rect(cornerRadius: 14))
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body.weight(live ? .semibold : .regular))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: done ? "checkmark.circle.fill" : (live ? "circle.dotted" : "circle")).font(.title2).foregroundStyle(done || live ? C.blue : Color.secondary.opacity(0.5))
    }
    .padding(10).background(C.tile, in: .rect(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(live ? C.blue : .clear, lineWidth: 2))
    .accessibilityElement(children: .combine)
}

private struct List37: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("This week").font(.headline).foregroundStyle(.secondary).padding(.top, 6)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    tileRow(symbol: e.method == "Espresso" ? "cup.and.heat.waves.fill" : "drop.fill", title: e.bean,
                            subtitle: "\(Fmt.day(e.date)) · \(Fmt.clock(e.timeS)) · \(Fmt.stars(e.ratingHalfSteps))", done: e.ratingHalfSteps >= 7)
                        .assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.page)
        .navigationTitle("Brews")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true } } }
    }
}

private struct Session37: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.title3).frame(width: 44, height: 44).foregroundStyle(.primary)
                        Spacer()
                        Button { model.toggleTimer() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: model.showsRunning ? "pause.fill" : "play.fill").contentTransition(.symbolEffect(.replace))
                                Text("00:" + Fmt.clock(Int(elapsed)).leftPadded).monospacedDigit().contentTransition(.numericText())
                            }
                            .font(.headline).padding(.horizontal, 18).frame(minHeight: 44).background(C.tile, in: .capsule)
                        }
                        .foregroundStyle(.primary).accessibilityLabel(model.primaryTitle)
                        Spacer()
                        Button("Finish", systemImage: "flag.checkered") { model.finishBrew() }.labelStyle(.iconOnly).font(.title3).frame(width: 44, height: 44).foregroundStyle(.primary)
                    }
                    HStack {
                        stat(s.cumulativeG.map(String.init) ?? "–", "Water g", C.teal)
                        stat("\(index + 1)/\(r.steps.count)", "Step", .primary)
                        stat(Fmt.num(r.tempC), "Temp °C", .primary)
                    }
                    Text("9:40 AM \(r.method)").font(.system(size: 30, weight: .regular))
                    Text("Bloom").font(.headline).foregroundStyle(.secondary)
                    ForEach(r.steps.prefix(2)) { st in row(st, index) }
                    Text("Pours").font(.headline).foregroundStyle(.secondary)
                    ForEach(r.steps.dropFirst(2)) { st in row(st, index) }
                }
                .padding(16)
            }
            .background(C.page.ignoresSafeArea())
        }
    }

    private func row(_ st: RecipeStep, _ index: Int) -> some View {
        tileRow(symbol: st.kind.symbol, title: st.cumulativeG.map { "\(st.kind.label) to \($0) g" } ?? st.kind.label,
                subtitle: "At \(Fmt.clock(st.startS)) · \(model.recipe.endS(of: st) - st.startS) secs", done: st.id < index, live: st.id == index)
    }

    private func stat(_ v: String, _ k: String, _ tint: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(.title2.weight(.medium)).foregroundStyle(tint).monospacedDigit(); Text(k).font(.subheadline).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity)
    }
}

private extension String { var leftPadded: String { count < 5 ? "0" + self : self } }

private struct Log37: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How was it?").font(.system(size: 30))
                    HStack(spacing: 0) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button { model.draft.verdict = on ? nil : v } label: {
                                HStack(spacing: 4) { if on { Image(systemName: "checkmark") }; Text(v.label).lineLimit(1).minimumScaleFactor(0.7) }
                                    .font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? C.blue : .primary).background(on ? C.icon : .clear)
                            }
                            .overlay(Rectangle().stroke(Color.secondary.opacity(0.5), lineWidth: 0.5))
                        }
                    }
                    .clipShape(.capsule).overlay(Capsule().stroke(Color.secondary.opacity(0.6)))
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.blue)
                    ForEach([("Dose", "g", 0.5), ("Water", "g", 5.0)], id: \.0) { k, u, step in
                        let b = k == "Dose" ? $model.draft.doseG : $model.draft.waterG
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(k).font(.caption).foregroundStyle(C.blue); Text("\(Fmt.num(b.wrappedValue)) \(u)").font(.title3) }
                            Spacer()
                            Stepper(k, value: b, in: 1...1000, step: step).labelsHidden()
                        }
                        .padding(.horizontal, 16).frame(minHeight: 60).overlay(RoundedRectangle(cornerRadius: 6).stroke(C.blue, lineWidth: 1.5))
                    }
                }
                .padding(20)
            }
            .background(C.page)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.blue) }
            }
        }
    }
}
