import SwiftUI

// 15. Pro Tool (Halide). Organizing idea: "we didn't make an app, we made a brewer". Dark,
// precise, instrument-like: tracked all-caps labels, SF Mono readouts, one yellow accent, and
// a horizontal scale dial you could scrub. Light mode keeps the same precision on white.

private enum H {
    static let bg = Color(0xF4F4F2, 0x000000)
    static let surface = Color(0xFFFFFF, 0x141414)
    static let accent = Color(0x9A6B00, 0xFFD60A)
    static let onAccent = Color(0xFFFFFF, 0x000000)
}

private struct Caps: View {
    let text: String
    var color: Color = .secondary
    var body: some View { Text(text.uppercased()).font(.caption2.weight(.heavy)).tracking(1.8).foregroundStyle(color) }
}

/// A horizontal ruler of ticks that slides under a fixed centre needle: the scale target.
private struct Ruler: View {
    let grams: Double
    var body: some View {
        GeometryReader { g in
            let perGram: CGFloat = 3, mid = g.size.width / 2
            ZStack(alignment: .topLeading) {
                ForEach(0...80, id: \.self) { i in
                    let v = i * 5, x = mid + (CGFloat(v) - grams) * perGram
                    VStack(spacing: 4) {
                        Rectangle().fill(v % 50 == 0 ? Color.primary : Color.secondary.opacity(0.6)).frame(width: 1.5, height: v % 50 == 0 ? 22 : 12)
                        if v % 50 == 0 { Text("\(v)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize() }
                    }
                    .position(x: x, y: 22)
                }
                Rectangle().fill(H.accent).frame(width: 3, height: 34).position(x: mid, y: 17)
            }
        }
        .frame(height: 48).clipped()
        .accessibilityHidden(true)
    }
}

struct Look15: View {
    var body: some View {
        ConceptShell(tint: H.accent) { LookRecipe(model: $0) } timer: { Timer15(model: $0) }
            log: { Log15(model: $0) } journal: { Journal15(model: $0) }
    }
}

private struct Journal15: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Log").font(.largeTitle.weight(.bold))
                    Spacer()
                    Caps(text: "\(model.journal.count) shots", color: H.accent)
                }
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Caps(text: Fmt.day(e.date))
                            Spacer()
                            Caps(text: e.verdict?.label ?? "", color: e.verdict == .balanced ? H.accent : .secondary)
                        }
                        Text(e.bean).font(.title3.weight(.semibold))
                        HStack(spacing: 0) {
                            cell("Dose", "\(Fmt.num(e.doseG))g")
                            cell("Ratio", "1:\(Fmt.num(e.ratio))")
                            cell("Grind", "\(e.grind)")
                            cell("Time", Fmt.clock(e.timeS))
                            cell("Score", Fmt.num(Double(e.ratingHalfSteps) / 2))
                        }
                    }
                    .padding(16).background(H.surface, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
                    .accessibilityElement(children: .combine)
                    .assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(H.bg)
    }

    private func cell(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Caps(text: k)
            Text(v).font(.system(.callout, design: .monospaced, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Timer15: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            let target = Double(r.steps[...index].compactMap(\.cumulativeG).last ?? 0)
            VStack(spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                    HStack(spacing: 14) {
                        Caps(text: "\(Fmt.num(r.doseG))G")
                        Caps(text: r.ratioText)
                        Caps(text: "\(Fmt.num(r.tempC))°C")
                    }
                    .padding(.horizontal, 14).frame(minHeight: 36).background(H.surface, in: .capsule)
                }
                .foregroundStyle(.primary)
                Spacer()
                Caps(text: "Step \(index + 1)/\(r.steps.count) · \(step.kind.label)", color: H.accent)
                Text(Fmt.clock(Int(elapsed))).font(.system(size: 88, weight: .medium, design: .monospaced)).monospacedDigit()
                    .contentTransition(.numericText()).padding(.top, 6)
                Text(step.instruction).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
                Spacer()
                VStack(spacing: 8) {
                    HStack {
                        Caps(text: "Scale target")
                        Spacer()
                        Text("\(Int(target)) g").font(.system(.title2, design: .monospaced, weight: .semibold)).foregroundStyle(H.accent)
                            .contentTransition(.numericText())
                    }
                    Ruler(grams: target)
                }
                .padding(16).background(H.surface, in: .rect(cornerRadius: 16))
                .animation(.spring(duration: 0.42, bounce: 0.1), value: target)
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Reset", systemImage: "arrow.counterclockwise") { model.resetTimer() }.labelStyle(.iconOnly).font(.title3.weight(.semibold))
                            .foregroundStyle(.primary).frame(width: 60, height: 60).glassEffect(.regular.interactive(), in: .circle)
                        Button(model.primaryTitle.uppercased()) { model.toggleTimer() }.font(.headline.weight(.heavy)).tracking(1.8).foregroundStyle(H.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 60).glassEffect(.regular.tint(H.accent).interactive(), in: .capsule)
                        Button("Log", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly).font(.title3.weight(.semibold))
                            .foregroundStyle(.primary).frame(width: 60, height: 60).glassEffect(.regular.interactive(), in: .circle)
                    }
                }
                .padding(.top, 16)
            }
            .padding(16)
            .background(H.bg)
        }
    }
}

private struct Log15: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Caps(text: "Shot", color: H.accent)
                    Text(model.draft.bean).font(.title.weight(.bold))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        dial("Dose", "\(Fmt.num(model.draft.doseG))", "g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        dial("Water", "\(Fmt.num(model.draft.waterG))", "g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        dial("Temp", "\(Fmt.num(model.draft.tempC))", "°C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                        VStack(alignment: .leading, spacing: 6) {
                            Caps(text: "Ratio")
                            Text(model.draft.ratio.map { "1:\(Fmt.num(($0 * 10).rounded() / 10))" } ?? "—").font(.system(.title, design: .monospaced, weight: .semibold))
                        }
                        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(H.surface, in: .rect(cornerRadius: 14))
                    }
                    Caps(text: "Taste")
                    HStack(spacing: 6) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label.uppercased()) { model.draft.verdict = on ? nil : v }.font(.caption2.weight(.heavy)).tracking(1)
                                .foregroundStyle(on ? H.onAccent : .primary).frame(maxWidth: .infinity, minHeight: 44)
                                .background(on ? H.accent : H.surface, in: .rect(cornerRadius: 10))
                                .buttonStyle(PressScale()).accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: H.accent)
                }
                .padding(16)
            }
            .background(H.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Shot") { model.save() }.buttonStyle(.glassProminent).tint(H.accent) }
            }
        }
    }

    private func dial(_ k: String, _ v: String, _ unit: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Caps(text: k)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(v).font(.system(.title, design: .monospaced, weight: .semibold)).contentTransition(.numericText())
                Text(unit).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down)
                Spacer()
                Button("More \(k.lowercased())", systemImage: "plus", action: step.up)
            }
            .labelStyle(.iconOnly).font(.headline).foregroundStyle(H.accent).frame(minHeight: 44).buttonStyle(PressScale(scale: 0.9))
        }
        .padding(14).background(H.surface, in: .rect(cornerRadius: 14))
    }
}
