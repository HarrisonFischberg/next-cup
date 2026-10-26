import SwiftUI

// 25. Timeline (Structured). Organizing idea: every brew is a block on a day planner. The journal
// is a vertical timeline of tall colour pills joined by a dashed spine; the timer is one block
// opened up, its tinted header, a big tinted countdown and the steps as a checklist.

private enum C {
    static let page = Color(0xF7F6F4, 0x111111)
    static let card = Color(0xFFFFFF, 0x1D1D1F)
    static let accent = Color(0xE8807A, 0xF29B95)
}

struct Look25: View {
    var body: some View {
        ConceptShell(tint: C.accent) { LookRecipe(model: $0) } timer: { Block25(model: $0) }
            log: { Log25(model: $0) } journal: { Timeline25(model: $0) }
    }
}

private struct Timeline25: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    let tint = BeanArt.color(e.bean)
                    HStack(alignment: .top, spacing: 14) {
                        Text(e.date.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing).padding(.top, 6)
                        VStack(spacing: 0) {
                            Capsule().fill(tint).frame(width: 52, height: 40 + CGFloat(e.timeS) / 6)
                                .overlay(alignment: .top) { Image(systemName: "cup.and.saucer.fill").foregroundStyle(.white).padding(.top, 14) }
                            DashedSpine().frame(width: 2, height: 26)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Fmt.clock(e.timeS)) brew").font(.caption).foregroundStyle(.secondary)
                            Text(e.bean).font(.headline)
                            Text(e.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .padding(.top, 4)
                        Spacer(minLength: 0)
                        Image(systemName: e.ratingHalfSteps >= 7 ? "checkmark.circle.fill" : "circle").font(.title2)
                            .foregroundStyle(e.ratingHalfSteps >= 7 ? tint : Color.secondary.opacity(0.4)).padding(.top, 10)
                    }
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.page)
        .navigationTitle("Brews")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true } } }
    }
}

private struct DashedSpine: View {
    var body: some View {
        GeometryReader { g in
            Path { p in p.move(to: .init(x: 1, y: 0)); p.addLine(to: .init(x: 1, y: g.size.height)) }
                .stroke(Color.secondary.opacity(0.4), style: .init(lineWidth: 2, dash: [3, 4]))
        }
    }
}

private struct Block25: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    C.accent.ignoresSafeArea(edges: .top)
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 48)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.top, 50)
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .foregroundStyle(.primary).frame(width: 44, height: 44).background(.white.opacity(0.6), in: .circle).padding(.leading, 16)
                }
                .frame(height: 150)
                ScrollView {
                    VStack(spacing: 6) {
                        Text(r.method).font(.title.weight(.bold)).foregroundStyle(C.accent).padding(.top, 14)
                        Text("9:40 – 9:43 AM (3 min)").font(.subheadline).foregroundStyle(C.accent.opacity(0.8))
                        Text(Fmt.clock(r.totalS - Int(elapsed))).font(.system(size: 80, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(C.accent).contentTransition(.numericText(countsDown: true)).padding(.top, 14)
                        Text("REMAINING").font(.title2.weight(.heavy)).foregroundStyle(C.accent)
                        VStack(spacing: 6) {
                            ForEach(r.steps) { s in
                                HStack(spacing: 12) {
                                    Image(systemName: s.id < index ? "checkmark.square.fill" : "square").font(.title3)
                                        .foregroundStyle(s.id < index ? C.accent : (s.id == index ? Color.primary : Color.secondary))
                                    Text(s.instruction).font(.subheadline.weight(s.id == index ? .semibold : .regular))
                                        .strikethrough(s.id < index).foregroundStyle(s.id <= index ? Color.primary : Color.secondary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14).frame(minHeight: 48).background(C.card, in: .rect(cornerRadius: 12))
                            }
                        }
                        .padding(.top, 18)
                    }
                    .padding(.horizontal, 16)
                }
                VStack(spacing: 10) {
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54).background(C.accent.opacity(0.75), in: .capsule)
                    Button("Complete", systemImage: "checkmark.circle.fill") { model.finishBrew() }
                        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54).background(C.accent, in: .capsule)
                }
                .buttonStyle(PressScale()).padding(16)
            }
            .background(C.page.ignoresSafeArea())
        }
    }
}

private struct Log25: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Capsule().fill(C.accent).frame(width: 52, height: 84).overlay { Image(systemName: "cup.and.saucer.fill").foregroundStyle(.white) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("9:40 – 9:43 AM").font(.subheadline).foregroundStyle(.secondary)
                            Text(model.draft.bean).font(.title2.weight(.bold))
                        }
                    }
                    section("How was it?") {
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { n in
                                let on = model.draft.ratingHalfSteps == n * 2
                                Button("\(n)") { model.draft.ratingHalfSteps = n * 2 }.font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? .white : .primary).background(on ? C.accent : C.card, in: .capsule)
                                    .accessibilityLabel("\(n) of 5").accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    section("Taste") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? .white : .primary).background(on ? C.accent : C.card, in: .capsule)
                            }
                        }
                    }
                    section("Notes") {
                        TextField("Add notes", text: $model.draft.notes, axis: .vertical).lineLimit(3...6).padding(14).background(C.card, in: .rect(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(C.page)
            .safeAreaInset(edge: .bottom) {
                Button("Save brew") { model.save() }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 54)
                    .background(C.accent, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 16)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }

    private func section<V: View>(_ t: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(t).font(.headline); v() }
    }
}
