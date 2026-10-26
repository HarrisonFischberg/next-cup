import SwiftUI

// 11. Today. Organizing idea: a single "Today" scroll like Fitness / Health. Home is a summary
// (this week's cups as rings, the next cup to brew), then history. Timer is workout-style:
// one huge rounded number, floating glass controls. Semantic colors, one coffee accent.

private enum T {
    static let accent = Color(0xA4501E, 0xF09A5B)
    static let sage = Color(0x4F7A55, 0x8CC495)
    static let radius: CGFloat = 22
}

struct Look11: View {
    var body: some View {
        ConceptShell(tint: T.accent) { LookRecipe(model: $0) } timer: { Timer11(model: $0) }
            log: { Log11(model: $0) } journal: { Today11(model: $0) }
    }
}

private struct WeekRings: View {
    let cups: Int, avg: Double
    var body: some View {
        ZStack {
            Circle().stroke(T.accent.opacity(0.18), lineWidth: 16)
            Circle().trim(from: 0, to: Double(cups) / 7).stroke(T.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().stroke(T.sage.opacity(0.18), lineWidth: 16).padding(20)
            Circle().trim(from: 0, to: avg / 5).stroke(T.sage, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90)).padding(20)
        }
        .frame(width: 120, height: 120)
        .accessibilityHidden(true)
    }
}

private struct Today11: View {
    let model: FlowModel
    var body: some View {
        let j = model.journal, avg = Double(j.map(\.ratingHalfSteps).reduce(0, +)) / Double(max(1, j.count)) / 2
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(SampleData.today.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(.footnote.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    WeekRings(cups: j.count, avg: avg)
                    VStack(alignment: .leading, spacing: 10) {
                        stat("Cups this week", "\(j.count)", T.accent)
                        stat("Average rating", Fmt.num((avg * 10).rounded() / 10), T.sage)
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: T.radius))
                .assemble(0)

                Text("Up next").font(.title2.weight(.bold))
                Button { model.tab = .recipes; model.showTimer = true } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(.white)
                            .frame(width: 56, height: 56).background(T.accent, in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.recipe.method).font(.headline)
                            Text("Kenya Kiambu AA · 20 g · 3:00").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.headline).foregroundStyle(T.accent)
                            .frame(width: 44, height: 44).background(T.accent.opacity(0.12), in: .circle)
                    }
                    .padding(16).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: T.radius))
                }
                .buttonStyle(PressScale()).foregroundStyle(.primary)
                .assemble(1)

                HStack {
                    Text("History").font(.title2.weight(.bold))
                    Spacer()
                    Text("Show all").font(.subheadline.weight(.semibold)).foregroundStyle(T.accent)
                }
                VStack(spacing: 0) {
                    ForEach(Array(j.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 14) {
                            Circle().fill(BeanArt.color(e.bean)).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.bean).font(.body.weight(.semibold))
                                Text("\(e.method) · \(Fmt.day(e.date))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label(Fmt.num(Double(e.ratingHalfSteps) / 2), systemImage: "star.fill").labelStyle(.titleAndIcon)
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .padding(.vertical, 12).padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        if i < j.count - 1 { Divider().padding(.leading, 40) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: T.radius))
                .assemble(2)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Today")
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(color).monospacedDigit()
        }
    }
}

private struct Timer11: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], next = model.nextStep(after: index)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Close", systemImage: "chevron.down") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.headline).frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                    Text(r.method).font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .foregroundStyle(.primary)
                Spacer()
                Text("ELAPSED").font(.footnote.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(Fmt.clock(Int(elapsed))).font(.system(size: 96, weight: .bold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                Text(step.cumulativeG.map { "Pour to \($0) g" } ?? step.kind.label)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(T.accent)
                Text(step.instruction).font(.title3).foregroundStyle(.secondary).padding(.top, 4)
                HStack(spacing: 4) {
                    ForEach(r.steps) { s in
                        Capsule().fill(s.id <= index ? T.accent : Color(.systemFill)).frame(height: 6)
                    }
                }
                .padding(.top, 24).accessibilityLabel("Step \(index + 1) of \(r.steps.count)")
                if let next {
                    Text("\(next.kind.label) in \(Fmt.clock(next.startS - Int(elapsed)))").font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary).monospacedDigit().padding(.top, 8)
                }
                Spacer()
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 16) {
                        Button("End", systemImage: "stop.fill") { model.finishBrew() }.labelStyle(.iconOnly)
                            .font(.title2).foregroundStyle(.primary).frame(width: 72, height: 72)
                            .glassEffect(.regular.interactive(), in: .circle)
                        Spacer()
                        Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                            .labelStyle(.iconOnly).font(.largeTitle).foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 88, height: 88).glassEffect(.regular.tint(T.accent).interactive(), in: .circle)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
        }
    }
}

private struct Log11: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Text(model.draft.bean).font(.title3.weight(.semibold))
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: T.accent, size: 30)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                Section("How did it taste?") {
                    Picker("Taste", selection: $model.draft.verdict) {
                        ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Measured") {
                    Stepper(value: $model.draft.doseG, in: 1...100, step: 0.5) { LabeledContent("Dose", value: "\(Fmt.num(model.draft.doseG)) g").monospacedDigit() }
                    Stepper(value: $model.draft.waterG, in: 10...1000, step: 5) { LabeledContent("Water", value: "\(Fmt.num(model.draft.waterG)) g").monospacedDigit() }
                    Stepper(value: $model.draft.tempC, in: 50...100) { LabeledContent("Temperature", value: "\(Fmt.num(model.draft.tempC)) °C").monospacedDigit() }
                    LabeledContent("Brew time", value: Fmt.clock(model.draft.timeS))
                }
                Section("Notes") { TextField("Blackcurrant, clean finish…", text: $model.draft.notes, axis: .vertical).lineLimit(2...5) }
            }
            .navigationTitle("Log cup").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Cup") { model.save() }.buttonStyle(.glassProminent).tint(T.accent) }
            }
        }
        .presentationDetents([.large])
    }
}
