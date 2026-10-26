import SwiftUI

// 26. Ruler (Brink sleep timer). Organizing idea: every number is set and read on a sliding
// tick ruler with a fixed centre needle. The timer slides the ruler as water goes in; the log
// is three rulers you drag; the journal rows each carry a small ruler at the ratio used.

private enum C {
    static let page = Color(0xF2F2F2, 0x0B0B0B)
    static let sheet = Color(0xFFFFFF, 0x1E1E1E)
    static let needle = Color(0xE5542E, 0xFF7A4D)
}

/// Ticks every `step`, a long one every five; the value sits under the centre needle.
private struct Ruler: View {
    var value: Double
    var step: Double
    var px: CGFloat = 12

    var body: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let units = value / step
            let base = units.rounded(.down)
            let n = Int(mid / px) + 2
            for i in -n...n {
                let k = Int(base) + i
                let x = mid + (CGFloat(i) - CGFloat(units - base)) * px
                let major = k % 5 == 0
                var p = Path()
                let h = major ? size.height * 0.7 : size.height * 0.4
                p.move(to: .init(x: x, y: (size.height - h) / 2)); p.addLine(to: .init(x: x, y: (size.height + h) / 2))
                let fade = 1 - abs(x - mid) / mid
                ctx.stroke(p, with: .color(.primary.opacity(0.15 + 0.55 * fade)), lineWidth: major ? 1.5 : 1)
            }
        }
        .overlay { Capsule().fill(C.needle).frame(width: 3) }
        .accessibilityHidden(true)
    }
}

/// A ruler you drag to change a value, with VoiceOver adjust.
private struct DragRuler: View {
    let title: String
    let unit: String
    @Binding var value: Double
    var step: Double
    var range: ClosedRange<Double>
    @State private var start: Double?

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.num(value)).font(.system(size: 52, weight: .regular)).monospacedDigit().contentTransition(.numericText())
                Text(unit).font(.headline).foregroundStyle(.secondary)
            }
            Ruler(value: value, step: step).frame(height: 40)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                    let s = start ?? value
                    start = s
                    value = min(range.upperBound, max(range.lowerBound, ((s - Double(g.translation.width / 12) * step) / step).rounded() * step))
                }.onEnded { _ in start = nil })
                .sensoryFeedback(.selection, trigger: value)
        }
        .accessibilityElement().accessibilityLabel(title).accessibilityValue("\(Fmt.num(value)) \(unit)")
        .accessibilityAdjustableAction { d in value = min(range.upperBound, max(range.lowerBound, value + (d == .increment ? step : -step))) }
    }
}

struct Look26: View {
    var body: some View {
        ConceptShell(tint: C.needle) { LookRecipe(model: $0) } timer: { Timer26(model: $0) }
            log: { Log26(model: $0) } journal: { List26(model: $0) }
    }
}

private struct List26: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(e.bean).font(.headline)
                            Spacer()
                            Text("1:\(Fmt.num((e.ratio * 10).rounded() / 10))").font(.system(.title2)).monospacedDigit()
                        }
                        Ruler(value: e.ratio, step: 0.2, px: 9).frame(height: 24)
                        Text("\(Fmt.day(e.date)) · \(e.method) · \(Fmt.stars(e.ratingHalfSteps))").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16).background(C.sheet, in: .rect(cornerRadius: 22))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.page)
        .navigationTitle("Brews")
    }
}

private struct Timer26: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let poured = poured(r, elapsed)
            VStack(spacing: 18) {
                Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 36, height: 5)
                ZStack {
                    Text("Brewing").font(.headline)
                    HStack { Spacer(); Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44).background(Color.secondary.opacity(0.15), in: .circle) }
                }
                Spacer()
                Circle().fill(C.needle).frame(width: 6, height: 6)
                Ruler(value: poured, step: 5, px: 8).frame(height: 44)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(poured))").font(.system(size: 72, weight: .regular)).monospacedDigit().contentTransition(.numericText())
                    Text("G").font(.headline).foregroundStyle(.secondary)
                }
                .accessibilityElement().accessibilityLabel("\(Int(poured)) grams poured")
                Text("\(s.kind.label) · \(Fmt.clock(Int(elapsed))) of \(Fmt.clock(r.totalS))").font(.subheadline).foregroundStyle(.secondary)
                Text(s.instruction).font(.title3).multilineTextAlignment(.center)
                Spacer()
                HStack(spacing: 10) {
                    Button("Finish") { model.finishBrew() }.font(.headline).frame(maxWidth: .infinity, minHeight: 54).background(Color.secondary.opacity(0.15), in: .capsule)
                    Button(model.primaryTitle) { model.toggleTimer() }.font(.headline).foregroundStyle(C.page).frame(maxWidth: .infinity, minHeight: 54).background(Color.primary, in: .capsule)
                }
                .foregroundStyle(.primary).buttonStyle(PressScale())
            }
            .padding(20)
            .background(C.sheet.ignoresSafeArea())
        }
    }

    /// Water in the cup now, read off the recipe's cumulative targets.
    private func poured(_ r: Recipe, _ t: Double) -> Double {
        var last = (t: 0.0, g: 0.0)
        for s in r.steps {
            guard let g = s.cumulativeG else { continue }
            let end = Double(r.endS(of: s))
            if t < end { return last.g + (Double(g) - last.g) * min(1, (t - Double(s.startS)) / max(1, end - Double(s.startS)) * 1.4) }
            last = (end, Double(g))
        }
        return last.g
    }
}

private struct Log26: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    DragRuler(title: "Dose", unit: "G", value: $model.draft.doseG, step: 0.5, range: 5...60)
                    DragRuler(title: "Water", unit: "G", value: $model.draft.waterG, step: 5, range: 30...800)
                    DragRuler(title: "Temperature", unit: "°C", value: $model.draft.tempC, step: 1, range: 50...100)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.needle)
                }
                .padding(.vertical, 20)
            }
            .background(C.sheet)
            .safeAreaInset(edge: .bottom) {
                Button("Save") { model.save() }.font(.headline).foregroundStyle(C.page).frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.primary, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 20)
            }
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }
}
