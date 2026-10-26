import SwiftUI

// 22. Atmosphere (Insight Timer player + journal entry). Organizing idea: the brew is a calm
// session in a full-bleed colour field taken from the bean; one thin countdown, one control.
// The journal is a quiet page per cup: a mood mark, two tags and the note as a pull quote.

private enum C {
    static let ink = Color(0x2A2622, 0xF1ECE6)
    static let amber = Color(0xE0A526, 0xF2BE4A)
    static let page = Color(0xFFFFFF, 0x141211)
    static let chip = Color(0xF1EFEC, 0x24211F)
}

/// A circle with a mouth whose curve follows the rating, as in Insight Timer's mood row.
private struct Mood: View {
    var curve: Double // -1 sad ... 1 happy
    var on: Bool
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var mouth = Path()
            mouth.move(to: CGPoint(x: w * 0.32, y: h * 0.56))
            mouth.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.56), control: CGPoint(x: w * 0.5, y: h * (0.56 + 0.16 * curve)))
            ctx.stroke(mouth, with: .color(on ? .white : .secondary), style: .init(lineWidth: 1.6, lineCap: .round))
        }
        .background(on ? C.amber : C.chip, in: .circle)
    }
}

struct Look22: View {
    var body: some View {
        ConceptShell(tint: C.amber) { LookRecipe(model: $0) } timer: { Timer22(model: $0) }
            log: { Log22(model: $0) } journal: { Journal22(model: $0) }
    }
}

private struct Journal22: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Mood(curve: Double(e.ratingHalfSteps - 6) / 4, on: true).frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.bean).font(.headline)
                                Text(e.date.formatted(.dateTime.weekday(.wide).month().day())).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach([e.method, e.verdict?.label ?? "", Fmt.clock(e.timeS)].filter { !$0.isEmpty }, id: \.self) {
                                Text($0).font(.caption).padding(.horizontal, 9).padding(.vertical, 5).background(C.chip, in: .rect(cornerRadius: 6))
                            }
                        }
                        Text(e.note).font(.system(.title3, design: .serif)).foregroundStyle(C.ink)
                            .padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1.5) }
                    }
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 24).padding(.top, 8)
        }
        .background(C.page)
        .navigationTitle("Journal")
    }
}

private struct Timer22: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let base = BeanArt.color(model.draft.bean)
            ZStack {
                MeshGradient(width: 2, height: 3, points: [[0, 0], [1, 0], [0, 0.55], [1, 0.45], [0, 1], [1, 1]],
                             colors: [base.mix(with: .black, by: 0.55), base.mix(with: .black, by: 0.3), base, base.mix(with: .orange, by: 0.3),
                                      base.mix(with: .black, by: 0.2), base.mix(with: .black, by: 0.6)])
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    HStack {
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                            .frame(width: 44, height: 44).lookGlass(nil, in: Circle(), fallback: .black.opacity(0.3), clear: true)
                        Spacer()
                        Button("Finish") { model.finishBrew() }.font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                            .lookGlass(nil, in: Capsule(), fallback: .black.opacity(0.3), clear: true)
                    }
                    Spacer()
                    Text(model.draft.bean).font(.subheadline).opacity(0.85)
                    Text(r.steps[index].instruction).font(.body).multilineTextAlignment(.center).opacity(0.85).padding(.horizontal, 30)
                    Text(Fmt.clock(r.totalS - Int(elapsed))).font(.system(size: 96, weight: .ultraLight)).monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(Fmt.clock(r.totalS - Int(elapsed))) remaining")
                    Text("\(r.steps.count - index - 1) pours remaining").font(.subheadline).opacity(0.85)
                    Spacer()
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                        .labelStyle(.iconOnly).font(.system(size: 34)).frame(width: 88, height: 88)
                        .contentTransition(.symbolEffect(.replace)).buttonStyle(PressScale(scale: 0.9))
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 20)
                .foregroundStyle(.white)
            }
        }
    }
}

private struct Log22: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { i in
                            let on = model.draft.ratingHalfSteps == i * 2
                            Button { model.draft.ratingHalfSteps = i * 2 } label: {
                                Mood(curve: Double(i - 3) / 2, on: on).frame(width: 48, height: 48).scaleEffect(on ? 1.12 : 1)
                            }
                            .accessibilityLabel("\(i) of 5").accessibilityAddTraits(on ? .isSelected : [])
                            .sensoryFeedback(.selection, trigger: on)
                        }
                    }
                    .frame(maxWidth: .infinity).animation(.spring(duration: 0.25), value: model.draft.ratingHalfSteps)
                    HStack(spacing: 6) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { model.draft.verdict = on ? nil : v }.font(.caption.weight(.medium))
                                .padding(.horizontal, 10).frame(minHeight: 32)
                                .foregroundStyle(on ? .white : .primary).background(on ? C.amber : C.chip, in: .rect(cornerRadius: 6))
                                .frame(minHeight: 44)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text("\(Fmt.num(model.draft.doseG)) g in, \(Fmt.num(model.draft.waterG)) g water, \(Fmt.clock(model.draft.timeS)).")
                        .font(.system(.body, design: .serif)).foregroundStyle(.secondary)
                        .padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1.5) }
                    TextField("How did it taste? What would you change?", text: $model.draft.notes, axis: .vertical)
                        .font(.system(.title3, design: .serif)).lineLimit(5...12)
                }
                .padding(24)
            }
            .background(C.page)
            .navigationTitle(SampleData.today.formatted(.dateTime.month().day().hour().minute())).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back", systemImage: "arrow.left") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.amber) }
            }
        }
    }
}
