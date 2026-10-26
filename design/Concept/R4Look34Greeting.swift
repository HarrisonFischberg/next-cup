import SwiftUI

// 34. Greeting (Joi). Organizing idea: the app talks to you first. A dark top with a huge date
// and a sentence that carries live tokens ("2 cups"), then a white sheet with a week strip and
// the day's list. The log is a fill-in sentence where every blank is a tappable token.

private enum C {
    static let night = Color(0x141414, 0x0A0A0A)
    static let sheet = Color(0xFFFFFF, 0x1C1C1E)
    static let dot = Color(0xF0644E, 0xFF7A66)
    static let muted = Color(0x8A8A8A, 0x8A8A8A)
}

/// A rounded inline token inside a sentence.
private struct Token: View {
    let text: String
    var symbol: String?
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 18, weight: .semibold)) }
            Text(text)
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1.5))
    }
}

struct Look34: View {
    var body: some View {
        ConceptShell(tint: C.dot) { LookRecipe(model: $0) } timer: { Timer34(model: $0) }
            log: { Sentence34(model: $0) } journal: { Day34(model: $0) }
    }
}

private struct Day34: View {
    let model: FlowModel
    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        Text(SampleData.today.formatted(.dateTime.day())).font(.system(size: 64, weight: .bold)).monospacedDigit().foregroundStyle(.white)
                        Circle().fill(C.dot).frame(width: 16, height: 16)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(SampleData.today.formatted(.dateTime.weekday(.wide)))
                        Text(SampleData.today.formatted(.dateTime.month(.wide).day()))
                    }
                    .font(.title3.weight(.semibold)).foregroundStyle(C.muted).padding(.top, 10)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good morning,").foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text("You've had").foregroundStyle(C.muted)
                        Token(text: "\(model.journal.count) cups", symbol: "cup.and.saucer").foregroundStyle(.white)
                    }
                    Text("this fortnight.").foregroundStyle(C.muted)
                }
                .font(.system(size: 26, weight: .semibold)).padding(.top, 28).padding(.bottom, 40)
                .accessibilityElement(children: .combine)
                VStack(spacing: 14) {
                    HStack(spacing: 0) {
                        ForEach(-6...0, id: \.self) { o in
                            let d = cal.date(byAdding: .day, value: o, to: SampleData.today)!
                            let has = model.journal.contains { cal.isDate($0.date, inSameDayAs: d) }
                            VStack(spacing: 2) {
                                Text(d.formatted(.dateTime.day())).font(.title3.weight(o == 0 ? .bold : .regular))
                                Text(d.formatted(.dateTime.weekday(.abbreviated)).uppercased()).font(.caption2.weight(.semibold))
                                    .foregroundStyle(o == 0 ? C.dot : .secondary)
                                Circle().fill(has ? C.dot : .clear).frame(width: 5, height: 5)
                            }
                            .foregroundStyle(o == 0 ? .primary : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 64).background(o == 0 ? Color.secondary.opacity(0.1) : .clear, in: .rect(cornerRadius: 12))
                        }
                    }
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 14) {
                            Image(systemName: e.ratingHalfSteps >= 7 ? "sun.max.fill" : "cloud.sun").font(.title3)
                                .foregroundStyle(e.ratingHalfSteps >= 7 ? Color.yellow : .secondary).frame(width: 28)
                            Text(e.bean).font(.body).foregroundStyle(e.ratingHalfSteps >= 7 ? .primary : .secondary)
                            Spacer()
                            Text(Fmt.day(e.date)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 48).overlay(alignment: .bottom) { Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1) }
                        .accessibilityElement(children: .combine).assemble(i)
                    }
                }
                .padding(16).background(C.sheet, in: .rect(cornerRadius: 30)).padding(.horizontal, -12)
            }
            .padding(.horizontal, 20)
        }
        .background(C.night)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct Timer34: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 64, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                    Circle().fill(model.showsRunning ? C.dot : C.muted).frame(width: 16, height: 16)
                    Spacer()
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                }
                Text(s.instruction).font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                if let n = model.nextStep(after: index) {
                    HStack(spacing: 8) {
                        Text("Then").foregroundStyle(C.muted)
                        Token(text: n.cumulativeG.map { "\($0) g" } ?? n.kind.label, symbol: n.kind.symbol)
                        Text("at \(Fmt.clock(n.startS))").foregroundStyle(C.muted)
                    }
                    .font(.system(size: 24, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 0) {
                    ForEach(r.steps) { st in
                        VStack(spacing: 4) {
                            Image(systemName: st.kind.symbol).font(.body)
                            Text(Fmt.clock(st.startS)).font(.caption2).monospacedDigit()
                        }
                        .foregroundStyle(st.id == index ? Color.white : C.muted)
                        .frame(maxWidth: .infinity, minHeight: 60).background(st.id == index ? Color.white.opacity(0.12) : .clear, in: .rect(cornerRadius: 12))
                    }
                }
                HStack(spacing: 12) {
                    Button("Finish", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly).frame(width: 60, height: 60)
                        .lookGlass(nil, in: Circle(), fallback: .white.opacity(0.15))
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause" : "play") { model.toggleTimer() }
                        .frame(maxWidth: .infinity, minHeight: 60).lookGlass(nil, in: Capsule(), fallback: .white.opacity(0.15))
                }
                .font(.headline)
            }
            .foregroundStyle(.white).padding(20)
            .background(C.night.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct Sentence34: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    line { Text("This"); Text(BeanArt.origin(model.draft.bean)).foregroundStyle(C.dot); Text("cup was") }
                    Menu {
                        ForEach(Verdict.allCases) { v in Button(v.label) { model.draft.verdict = v } }
                    } label: { blank(model.draft.verdict?.label.lowercased() ?? "how it tasted") }
                    line { Text("and I'd give it") }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { n in
                            Button { model.draft.ratingHalfSteps = n * 2 } label: { blank("\(n)", on: model.draft.ratingHalfSteps == n * 2) }
                                .accessibilityLabel("\(n) of 5")
                        }
                    }
                    line { Text("stars. I used") }
                    HStack(spacing: 8) {
                        let st = $model.draft.doseG.stepped(by: 0.5, in: 1...100)
                        Button("Less dose", systemImage: "minus", action: st.down).labelStyle(.iconOnly).frame(width: 44, height: 44)
                        blank("\(Fmt.num(model.draft.doseG)) g")
                        Button("More dose", systemImage: "plus", action: st.up).labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                    .foregroundStyle(.primary)
                    line { Text("in \(Fmt.num(model.draft.waterG)) g of water.") }
                }
                .font(.system(size: 30, weight: .semibold)).padding(24)
            }
            .background(C.sheet)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.dot) }
            }
        }
    }

    private func line<V: View>(@ViewBuilder _ v: () -> V) -> some View { HStack(spacing: 8) { v() } }
    private func blank(_ t: String, on: Bool = true) -> some View {
        Text(t).padding(.horizontal, 14).frame(minHeight: 48)
            .foregroundStyle(on ? Color.primary : Color.secondary)
            .overlay(Capsule().stroke(on ? C.dot : Color.secondary.opacity(0.4), style: .init(lineWidth: 2, dash: on ? [] : [5, 4])))
    }
}
