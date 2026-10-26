import SwiftUI

// 24. Stack (BitePal). Organizing idea: a pile of big white cards over a soft colour wash, each
// card one number at headline size with a ring button that ends it. The journal is "Today"
// as a pull-up sheet over the wash; the log is the same cards, one per value.

private enum C {
    static let wash = Color(0xF4E6DA, 0x2A1F19)
    static let card = Color(0xFFFFFF, 0x1E1E1E)
    static let ring = Color(0x2E9E4F, 0x52C873)
    static let ink = Color(0x161616, 0xF4F4F4)
}

private struct Wash: View {
    var body: some View {
        ZStack {
            C.wash
            Circle().fill(BeanArt.color("Kenya").opacity(0.35)).frame(width: 260).blur(radius: 70).offset(x: -110, y: -300)
            Circle().fill(BeanArt.color("Colombia").opacity(0.3)).frame(width: 240).blur(radius: 70).offset(x: 140, y: -240)
        }
        .ignoresSafeArea()
    }
}

struct Look24: View {
    var body: some View {
        ConceptShell(tint: C.ring) { LookRecipe(model: $0) } timer: { Timer24(model: $0) }
            log: { Log24(model: $0) } journal: { Today24(model: $0) }
    }
}

private struct Today24: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average cup").font(.subheadline).foregroundStyle(.secondary)
                        Text(Fmt.num(Double(model.journal.map(\.ratingHalfSteps).reduce(0, +)) / Double(max(1, model.journal.count)) / 2))
                            .font(.system(size: 46, weight: .bold)).monospacedDigit()
                    }
                    Spacer()
                    Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true }
                        .labelStyle(.iconOnly).font(.title2.weight(.semibold)).foregroundStyle(C.ink).frame(width: 64, height: 64)
                        .overlay(Circle().stroke(C.ring, lineWidth: 6))
                }
                .padding(20).background(C.card.opacity(0.6), in: .rect(cornerRadius: 28)).padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 0) {
                    Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
                    HStack {
                        Text("This week").font(.system(size: 30, weight: .bold))
                        Spacer()
                        Image(systemName: "square.and.arrow.up").font(.title3).frame(width: 44, height: 44).accessibilityLabel("Share")
                    }
                    .padding(.top, 10).padding(.bottom, 6)
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 14) {
                            Circle().fill(BeanArt.color(e.bean).opacity(0.18)).frame(width: 44, height: 44)
                                .overlay { Image(systemName: "cup.and.saucer.fill").foregroundStyle(BeanArt.color(e.bean)) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.bean).font(.headline)
                                Text("\(e.method) • \(Fmt.day(e.date))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.headline).monospacedDigit()
                                Text("stars").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10).accessibilityElement(children: .combine).assemble(i)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
                .background(C.card, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .padding(.top, 14)
            }
        }
        .background(Wash())
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct Timer24: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                            .foregroundStyle(C.ink).frame(width: 44, height: 44).background(C.card, in: .circle)
                        Spacer()
                    }
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Brewing").font(.headline).foregroundStyle(.secondary)
                                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 54, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                                }
                                Spacer()
                                Button { model.finishBrew() } label: {
                                    ZStack {
                                        Circle().stroke(C.ring.opacity(0.2), lineWidth: 7)
                                        Circle().trim(from: 0, to: elapsed / Double(r.totalS)).stroke(C.ring, style: .init(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                                        Text("END").font(.subheadline.weight(.heavy)).foregroundStyle(C.ring)
                                    }
                                    .frame(width: 74, height: 74)
                                }
                                .accessibilityLabel("End brew").buttonStyle(PressScale(scale: 0.9))
                            }
                            HStack {
                                kv("Started", "9:40 AM")
                                kv("Target", Fmt.clock(r.totalS))
                            }
                            Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                                .font(.headline).foregroundStyle(C.card).frame(maxWidth: .infinity, minHeight: 50).background(C.ink, in: .capsule)
                                .buttonStyle(PressScale())
                        }
                    }
                    card { value("Now", s.cumulativeG.map { "\($0) g" } ?? s.kind.label, s.instruction, 0.75) }
                    if let n = model.nextStep(after: index) {
                        card { value("Next at \(Fmt.clock(n.startS))", n.cumulativeG.map { "\($0) g" } ?? n.kind.label, n.instruction, 0) }.opacity(0.55)
                    }
                }
                .padding(12)
            }
            .background(Wash())
        }
    }

    private func card<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        v().padding(20).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 28))
    }
    private func kv(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading) { Text(k).font(.subheadline).foregroundStyle(.secondary); Text(v).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func value(_ k: String, _ v: String, _ sub: String, _ p: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(k).font(.headline).foregroundStyle(.secondary)
                Text(v).font(.system(size: 40, weight: .bold))
                Text(sub).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: p).stroke(C.ring, style: .init(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            }
            .frame(width: 52, height: 52)
        }
    }
}

private struct Log24: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    tile("Rating") { LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.ring, size: 28) }
                    tile("Taste") {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Verdict.allCases) { v in
                                    let on = model.draft.verdict == v
                                    Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                                        .foregroundStyle(on ? C.card : C.ink).background(on ? C.ink : Color.secondary.opacity(0.12), in: .capsule)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    HStack(spacing: 10) {
                        num("Dose", Fmt.num(model.draft.doseG), "g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        num("Water", Fmt.num(model.draft.waterG), "g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                    }
                    tile("Note") { TextField("Optional", text: $model.draft.notes, axis: .vertical).font(.title3).lineLimit(2...4) }
                }
                .padding(12)
            }
            .background(Wash())
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.ring) }
            }
        }
    }

    private func tile<V: View>(_ k: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(k).font(.headline).foregroundStyle(.secondary); v() }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 28))
    }
    private func num(_ k: String, _ v: String, _ u: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        tile(k) {
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text(v).font(.system(size: 40, weight: .bold)).monospacedDigit(); Text(u).font(.headline).foregroundStyle(.secondary) }
            HStack {
                Button("Less", systemImage: "minus", action: step.down).frame(width: 44, height: 44).background(Color.secondary.opacity(0.12), in: .circle)
                Button("More", systemImage: "plus", action: step.up).frame(width: 44, height: 44).background(C.ink, in: .circle).foregroundStyle(C.card)
            }
            .labelStyle(.iconOnly).font(.headline).foregroundStyle(C.ink).buttonStyle(PressScale(scale: 0.9))
        }
    }
}
