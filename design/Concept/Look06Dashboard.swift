import Charts
import SwiftUI

// 6. Brew Lab Dashboard. Bento grid of tiles with Swift Charts: the journal is analytics
// first (ratings over time, ratio vs rating), the timer plots your pour against the target
// curve live. System type, Apple-style tiles, regular glass on the controls.

private enum D {
    static let bg = Color(0xF2F2F7, 0x000000)
    static let tile = Color(0xFFFFFF, 0x1C1C1E)
    static let ink = Color(0x000000, 0xFFFFFF)
    static let ink2 = Color(0x5C5C63, 0x9A9AA1)
    static let accent = Color(0x0A7A5A, 0x30D99E)
    static let warm = Color(0xB8520F, 0xFF9F45)
    static let onAccent = Color(0xFFFFFF, 0x000000)
}

private struct Tile<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(D.ink2)
            content
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(D.tile, in: .rect(cornerRadius: 22))
    }
}

struct Look06: View {
    var body: some View {
        ConceptShell(tint: D.accent) { LookRecipe(model: $0) } timer: { Timer06(model: $0) }
            log: { Log06(model: $0) } journal: { Journal06(model: $0) }
    }
}

private struct Journal06: View {
    let model: FlowModel
    var body: some View {
        let j = model.journal
        let avg = Double(j.map(\.ratingHalfSteps).reduce(0, +)) / Double(max(1, j.count)) / 2
        ScrollView {
            VStack(spacing: 12) {
                Text("Dashboard").font(.largeTitle.weight(.bold)).foregroundStyle(D.ink).frame(maxWidth: .infinity, alignment: .leading)
                Tile(title: "Rating, last 10 days") {
                    Chart(j) { e in
                        BarMark(x: .value("Day", e.date, unit: .day), y: .value("Rating", Double(e.ratingHalfSteps) / 2))
                            .foregroundStyle(e.ratingHalfSteps >= 8 ? D.accent : D.accent.opacity(0.45))
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    .chartYScale(domain: 0...5).frame(height: 140)
                }
                HStack(spacing: 12) {
                    Tile(title: "Average") {
                        Text(Fmt.num((avg * 10).rounded() / 10)).font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(D.ink)
                        Text("of 5 · \(j.count) cups").font(.footnote).foregroundStyle(D.ink2)
                    }
                    Tile(title: "Sweet spot") {
                        Chart(j) { e in
                            PointMark(x: .value("Ratio", e.ratio), y: .value("Rating", Double(e.ratingHalfSteps) / 2))
                                .foregroundStyle(D.warm).symbolSize(70)
                        }
                        .chartXScale(domain: 12...18).chartYScale(domain: 0...5)
                        .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 70)
                        Text("1:15 to 1:16").font(.headline).foregroundStyle(D.ink)
                    }
                }
                .frame(height: 150)
                ForEach(j.prefix(4)) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.bean).font(.headline).foregroundStyle(D.ink)
                            Text("\(e.method) · 1:\(Fmt.num(e.ratio))").font(.subheadline).foregroundStyle(D.ink2)
                        }
                        Spacer()
                        Gauge(value: Double(e.ratingHalfSteps), in: 0...10) { EmptyView() } currentValueLabel: {
                            Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).foregroundStyle(D.ink)
                        }
                        .gaugeStyle(.accessoryCircularCapacity).tint(D.accent).scaleEffect(0.8)
                    }
                    .padding(14).background(D.tile, in: .rect(cornerRadius: 18))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(D.bg)
    }
}

private struct Timer06: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            let target = r.steps.compactMap { s in s.cumulativeG.map { (t: s.startS, g: $0) } }
            VStack(spacing: 12) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.headline).foregroundStyle(D.ink).frame(width: 44, height: 44).lookGlass(nil, in: .circle, fallback: D.tile)
                    Spacer()
                    Text(r.method).font(.headline).foregroundStyle(D.ink)
                }
                HStack(spacing: 12) {
                    Tile(title: "Elapsed") {
                        Text(Fmt.clock(Int(elapsed))).font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(D.ink)
                        Text("of \(Fmt.clock(r.totalS))").font(.footnote).foregroundStyle(D.ink2)
                    }
                    Tile(title: "Scale") {
                        Text(step.cumulativeG.map { "\($0) g" } ?? "hold").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(D.accent)
                        Text(step.kind.label).font(.footnote).foregroundStyle(D.ink2)
                    }
                }
                .frame(height: 140)
                Tile(title: "Pour vs target") {
                    Chart {
                        ForEach(target, id: \.t) { p in
                            LineMark(x: .value("s", p.t), y: .value("g", p.g)).interpolationMethod(.stepEnd).foregroundStyle(D.ink2)
                        }
                        RuleMark(x: .value("now", elapsed)).foregroundStyle(D.warm).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("now", elapsed), y: .value("g", step.cumulativeG ?? 320)).foregroundStyle(D.accent).symbolSize(160)
                    }
                    .chartXScale(domain: 0...r.totalS).frame(height: 170)
                }
                Tile(title: "Now") {
                    Text(step.instruction).font(.title3.weight(.semibold)).foregroundStyle(D.ink)
                    if let next = model.nextStep(after: index) {
                        ProgressView(value: elapsed - Double(step.startS), total: Double(next.startS - step.startS)).tint(D.accent)
                        Text("\(next.kind.label) in \(Fmt.clock(next.startS - Int(elapsed)))").font(.footnote).foregroundStyle(D.ink2)
                    }
                }
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.title3.weight(.bold)).foregroundStyle(D.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 58).lookGlass(D.accent, in: .rect(cornerRadius: 18), fallback: D.accent)
                        Button("Finish") { model.finishBrew() }.font(.title3.weight(.semibold)).foregroundStyle(D.ink)
                            .frame(maxWidth: .infinity, minHeight: 58).lookGlass(nil, in: .rect(cornerRadius: 18), fallback: D.tile)
                    }
                }
            }
            .padding(16)
            .background(D.bg)
        }
    }
}

private struct Log06: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: D.accent).frame(maxWidth: .infinity)
                    Picker("Taste", selection: $model.draft.verdict) {
                        Text("None").tag(Verdict?.none)
                        ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Measured") {
                    Stepper("Dose \(Fmt.num(model.draft.doseG)) g", value: $model.draft.doseG, in: 1...100, step: 0.5)
                    Stepper("Water \(Fmt.num(model.draft.waterG)) g", value: $model.draft.waterG, in: 10...1000, step: 5)
                    Stepper("Temp \(Fmt.num(model.draft.tempC)) °C", value: $model.draft.tempC, in: 50...100)
                    LabeledContent("Ratio", value: model.draft.ratio.map { "1:\(Fmt.num(($0 * 10).rounded() / 10))" } ?? "—")
                }
                Section("This cup vs your average") {
                    Chart {
                        BarMark(x: .value("Ratio", model.draft.ratio ?? 0), y: .value("", "This cup")).foregroundStyle(D.accent)
                        BarMark(x: .value("Ratio", 15.4), y: .value("", "Average")).foregroundStyle(D.ink2)
                    }
                    .frame(height: 80)
                }
            }
            .scrollContentBackground(.hidden).background(D.bg)
            .navigationTitle("Log brew")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(D.accent) }
            }
        }
    }
}
