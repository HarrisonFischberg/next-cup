import Charts
import SwiftUI

// 18. Run Summary (Slopes / Strava). Organizing idea: every brew is a recorded session with a
// story told in data. The journal opens on the last session's pour curve and splits; the
// timer draws your pour live against the target. Dark-first, one electric accent.

private enum S {
    static let accent = Color(0x0A7F8F, 0x3DE0F0)
    static let target = Color(0x8A8A8E, 0x636366)
}

private func curve(_ r: Recipe) -> [(t: Int, g: Int)] {
    var pts: [(Int, Int)] = [(0, 0)]
    var g = 0
    for s in r.steps {
        if let c = s.cumulativeG { pts.append((s.startS + 15, c)); g = c } else { pts.append((s.startS, g)) }
    }
    pts.append((r.totalS, g))
    return pts.map { (t: $0.0, g: $0.1) }
}

struct Look18: View {
    var body: some View {
        ConceptShell(tint: S.accent) { LookRecipe(model: $0) } timer: { Timer18(model: $0) }
            log: { Log18(model: $0) } journal: { Sessions18(model: $0) }
    }
}

private struct Sessions18: View {
    let model: FlowModel
    var body: some View {
        let last = model.journal[0], pts = curve(model.recipe)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST SESSION · \(Fmt.day(last.date).uppercased())").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(S.accent)
                    Text(last.bean).font(.title.weight(.bold))
                    Text(last.method).font(.subheadline).foregroundStyle(.secondary)
                }
                Chart {
                    ForEach(pts, id: \.t) { p in
                        AreaMark(x: .value("Time", p.t), y: .value("Water", p.g)).interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [S.accent.opacity(0.35), S.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", p.t), y: .value("Water", p.g)).interpolationMethod(.monotone)
                            .foregroundStyle(S.accent).lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                .chartXAxis { AxisMarks(values: [0, 60, 120, 180]) { v in AxisValueLabel { Text(Fmt.clock(v.as(Int.self) ?? 0)) } } }
                .frame(height: 180)
                .accessibilityLabel("Pour curve: 320 grams over 3 minutes")
                Grid(horizontalSpacing: 0, verticalSpacing: 14) {
                    GridRow { stat("Rating", Fmt.num(Double(last.ratingHalfSteps) / 2)); stat("Time", Fmt.clock(last.timeS)); stat("Ratio", "1:\(Fmt.num(last.ratio))") }
                    GridRow { stat("Dose", "\(Fmt.num(last.doseG)) g"); stat("Water", "\(Fmt.num(last.waterG)) g"); stat("Temp", "\(Fmt.num(last.tempC))°") }
                }
                .padding(.vertical, 6)
                Text("Sessions").font(.title3.weight(.bold)).padding(.top, 8)
                ForEach(Array(model.journal.dropFirst().enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        Chart(pts, id: \.t) { p in LineMark(x: .value("t", p.t), y: .value("g", p.g * Int(e.waterG) / 320)).foregroundStyle(S.accent) }
                            .chartXAxis(.hidden).chartYAxis(.hidden).frame(width: 64, height: 36).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.bean).font(.headline)
                            Text("\(e.method) · \(Fmt.day(e.date))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.clock(e.timeS)).font(.headline.monospacedDigit())
                            Text(Fmt.stars(e.ratingHalfSteps)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .assemble(i)
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Sessions").navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Timer18: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], pts = curve(r)
            let poured = pts.filter { Double($0.t) <= elapsed }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .foregroundStyle(.primary).frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                    Label("Recording", systemImage: "record.circle").font(.footnote.weight(.semibold)).foregroundStyle(S.accent)
                        .symbolEffect(.pulse, isActive: model.showsRunning)
                }
                HStack(alignment: .firstTextBaseline, spacing: 22) {
                    VStack(alignment: .leading) {
                        Text("TIME").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Text(Fmt.clock(Int(elapsed))).font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                    }
                    VStack(alignment: .leading) {
                        Text("SCALE").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Text("\(step.cumulativeG ?? 320)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(S.accent)
                    }
                }
                .padding(.top, 20)
                Chart {
                    ForEach(pts, id: \.t) { p in
                        LineMark(x: .value("t", p.t), y: .value("g", p.g), series: .value("s", "target")).interpolationMethod(.monotone)
                            .foregroundStyle(S.target).lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                    ForEach(poured, id: \.t) { p in
                        LineMark(x: .value("t", p.t), y: .value("g", p.g), series: .value("s", "you")).interpolationMethod(.monotone)
                            .foregroundStyle(S.accent).lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                    PointMark(x: .value("t", elapsed), y: .value("g", poured.last?.g ?? 0)).foregroundStyle(S.accent).symbolSize(180)
                }
                .chartXScale(domain: 0...r.totalS).chartYScale(domain: 0...340)
                .chartXAxis { AxisMarks(values: [0, 60, 120, 180]) { v in AxisGridLine(); AxisValueLabel { Text(Fmt.clock(v.as(Int.self) ?? 0)) } } }
                .frame(height: 230).padding(.top, 16)
                .accessibilityLabel("Pour so far against the target curve")
                Text(step.instruction).font(.title3.weight(.medium)).padding(.top, 20)
                if let next = model.nextStep(after: index) {
                    Text("Next: \(next.kind.label) in \(Fmt.clock(next.startS - Int(elapsed)))").font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                }
                Spacer()
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                            .font(.title3.weight(.semibold)).foregroundStyle(.white).contentTransition(.symbolEffect(.replace))
                            .frame(maxWidth: .infinity, minHeight: 64).glassEffect(.regular.tint(S.accent).interactive(), in: .capsule)
                        Button("Finish", systemImage: "flag.checkered") { model.finishBrew() }
                            .font(.title3.weight(.semibold)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 64).glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct Log18: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SESSION COMPLETE").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(S.accent)
                        Text(Fmt.clock(model.draft.timeS)).font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("\(model.draft.bean) · \(model.recipe.method)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section("Rate it") {
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: S.accent, size: 28).frame(maxWidth: .infinity)
                    Picker("Taste", selection: $model.draft.verdict) {
                        ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Splits") {
                    Stepper("Dose  \(Fmt.num(model.draft.doseG)) g", value: $model.draft.doseG, in: 1...100, step: 0.5).monospacedDigit()
                    Stepper("Water  \(Fmt.num(model.draft.waterG)) g", value: $model.draft.waterG, in: 10...1000, step: 5).monospacedDigit()
                    Stepper("Temp  \(Fmt.num(model.draft.tempC)) °C", value: $model.draft.tempC, in: 50...100).monospacedDigit()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Session") { model.save() }.buttonStyle(.glassProminent).tint(S.accent) }
            }
        }
    }
}
