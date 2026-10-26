import SwiftUI

// 38. Diary (Lifesum). Organizing idea: a food-diary day on warm paper, sections in small caps
// and white cards with a round plus. Water is counted in glasses: the timer fills one glass per
// 40 g, the journal's "daily wins" card shows cups as icons, and flat grey bars are the actions.

private enum C {
    static let paper = Color(0xF1EEE8, 0x15140F)
    static let card = Color(0xFFFFFF, 0x22211C)
    static let bar = Color(0xE2DED6, 0x2E2C26)
    static let green = Color(0x2E6B3F, 0x7FCB8E)
    static let water = Color(0x69A7E8, 0x69A7E8)
}

private struct Glass: View {
    var fill: Double
    var body: some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6).fill(C.water.opacity(0.18))
            UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6).fill(C.water.gradient)
                .frame(height: nil).scaleEffect(x: 1, y: fill, anchor: .bottom)
        }
        .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6).stroke(C.water.opacity(0.6), lineWidth: 1.5))
        .frame(width: 30, height: 42)
    }
}

private func smallCaps(_ t: String) -> some View {
    Text(t.uppercased()).font(.footnote.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
}

private func barButton(_ t: String, _ a: @escaping () -> Void) -> some View {
    Button(t.uppercased(), action: a).font(.subheadline.weight(.bold)).tracking(1.5).foregroundStyle(C.green)
        .frame(maxWidth: .infinity, minHeight: 50).background(C.bar, in: .rect(cornerRadius: 6)).buttonStyle(PressScale())
}

struct Look38: View {
    var body: some View {
        ConceptShell(tint: C.green) { LookRecipe(model: $0) } timer: { Water38(model: $0) }
            log: { Log38(model: $0) } journal: { Diary38(model: $0) }
    }
}

private struct Diary38: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                smallCaps("Daily wins")
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Cups").font(.title3.weight(.semibold)); Text("(\(model.journal.count) of 8)").font(.body.monospaced()).foregroundStyle(.secondary); Spacer() }
                    HStack(spacing: 6) {
                        ForEach(0..<8, id: \.self) { i in
                            Image(systemName: i < model.journal.count ? "cup.and.saucer.fill" : "cup.and.saucer").font(.title2)
                                .foregroundStyle(i < model.journal.count ? C.green : Color.secondary.opacity(0.4))
                        }
                    }
                }
                .padding(16).background(C.card, in: .rect(cornerRadius: 14))
                smallCaps("Logged").padding(.top, 8)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        Circle().fill(BeanArt.color(e.bean).opacity(0.85)).frame(width: 40, height: 40)
                            .overlay { Text(String(BeanArt.origin(e.bean).prefix(1))).font(.headline).foregroundStyle(.white) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.bean).font(.title3.weight(.semibold))
                            Text("\(Fmt.day(e.date)): \(Fmt.num(e.waterG)) g · \(Fmt.stars(e.ratingHalfSteps))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus").font(.headline).foregroundStyle(.secondary).frame(width: 40, height: 40).background(C.bar, in: .circle)
                            .accessibilityHidden(true)
                    }
                    .padding(14).background(C.card, in: .rect(cornerRadius: 14)).accessibilityElement(children: .combine).assemble(i)
                }
                barButton("Log a brew") { model.prefillFromRecipe(measuredS: 180); model.showLog = true }.padding(.top, 8)
            }
            .padding(16)
        }
        .background(C.paper)
        .navigationTitle("Diary")
    }
}

private struct Water38: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let target = Double(r.steps[...index].compactMap(\.cumulativeG).last ?? 0)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .foregroundStyle(.primary).frame(width: 44, height: 44).background(C.card, in: .circle)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.title3.weight(.semibold).monospacedDigit()).contentTransition(.numericText())
                }
                smallCaps("Water")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(target))").font(.system(size: 54, weight: .semibold)).monospacedDigit()
                        Text("/ \(Fmt.num(r.waterG)) g").font(.title3).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(0..<8, id: \.self) { i in Glass(fill: min(1, max(0, (target - Double(i) * 40) / 40))) }
                    }
                    .accessibilityHidden(true)
                }
                .padding(16).background(C.card, in: .rect(cornerRadius: 14))
                smallCaps("Now")
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.kind.label).font(.title3.weight(.semibold))
                    Text(s.instruction).font(.body).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(C.card, in: .rect(cornerRadius: 14))
                if let n = model.nextStep(after: index) {
                    smallCaps("Next at \(Fmt.clock(n.startS))")
                    Text(n.instruction).font(.body).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(C.card.opacity(0.6), in: .rect(cornerRadius: 14))
                }
                Spacer()
                barButton(model.primaryTitle) { model.toggleTimer() }
                barButton("Finish brew") { model.finishBrew() }
            }
            .padding(16)
            .background(C.paper.ignoresSafeArea())
        }
    }
}

private struct Log38: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    smallCaps("Amounts")
                    ForEach([("Dose", 0.5), ("Water", 5.0), ("Temperature", 1.0)], id: \.0) { k, step in
                        let b = k == "Dose" ? $model.draft.doseG : (k == "Water" ? $model.draft.waterG : $model.draft.tempC)
                        let st = b.stepped(by: step, in: 1...1000)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k).font(.title3.weight(.semibold))
                                Text("Recipe: \(Fmt.num(k == "Dose" ? model.recipe.doseG : (k == "Water" ? model.recipe.waterG : model.recipe.tempC)))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 40, height: 40).background(C.bar, in: .circle)
                            Text(Fmt.num(b.wrappedValue)).font(.title3.monospacedDigit()).frame(minWidth: 52)
                            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 40, height: 40).background(C.bar, in: .circle)
                        }
                        .labelStyle(.iconOnly).foregroundStyle(.primary).padding(14).background(C.card, in: .rect(cornerRadius: 14))
                    }
                    smallCaps("Taste").padding(.top, 8)
                    VStack(alignment: .leading, spacing: 12) {
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.green)
                        Picker("Taste", selection: $model.draft.verdict) {
                            Text("—").tag(Verdict?.none)
                            ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(14).background(C.card, in: .rect(cornerRadius: 14))
                    barButton("Save to diary") { model.save() }.padding(.top, 10)
                }
                .padding(16)
            }
            .background(C.paper)
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }
}
