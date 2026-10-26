import SwiftUI

// 14. Journal (Day One / Bear). Organizing idea: writing first. A calendar strip on top,
// entries as pages with a New York serif title and the note as the main text; numbers are
// small print underneath. The log is a blank page where the note comes first.

private enum J {
    static let accent = Color(0x2F6E73, 0x5FB3B8)
    static let paper = Color(0xFBFAF7, 0x161616)
}

struct Look14: View {
    var body: some View {
        ConceptShell(tint: J.accent) { LookRecipe(model: $0) } timer: { Timer14(model: $0) }
            log: { Log14(model: $0) } journal: { Journal14(model: $0) }
    }
}

private struct Journal14: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Two weeks of days, a dot under each day with a cup.
                HStack(spacing: 0) {
                    ForEach(0..<7) { d in
                        let day = SampleData.today.addingTimeInterval(Double(d - 6) * 86_400)
                        let has = model.journal.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
                        VStack(spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(day.formatted(.dateTime.day())).font(.body.weight(d == 6 ? .bold : .regular))
                                .foregroundStyle(d == 6 ? .white : .primary)
                                .frame(width: 36, height: 36).background(d == 6 ? J.accent : .clear, in: .circle)
                            Circle().fill(has ? J.accent : .clear).frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .ignore).accessibilityLabel("This week: \(model.journal.count) cups")
                Divider()
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Text(e.date.formatted(.dateTime.day())).font(.system(.title, design: .serif, weight: .semibold))
                            Text(e.date.formatted(.dateTime.weekday(.abbreviated)).uppercased()).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                        }
                        .frame(width: 44)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.bean).font(.system(.title3, design: .serif, weight: .semibold))
                            Text(e.note).font(.body).foregroundStyle(.primary.opacity(0.85)).lineSpacing(3)
                            Text("\(e.method) · \(Fmt.num(e.doseG)) g → \(Fmt.num(e.waterG)) g · \(Fmt.clock(e.timeS)) · \(Fmt.stars(e.ratingHalfSteps))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 18)
                    .accessibilityElement(children: .combine)
                    .assemble(i)
                    Divider().padding(.leading, 60)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(J.paper)
        .navigationTitle("Coffee Journal")
        .toolbar { Button("New Entry", systemImage: "square.and.pencil") { model.tab = .recipes; model.showTimer = true } }
    }
}

private struct Timer14: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                }
                .foregroundStyle(.primary)
                Text(r.name).font(.system(.largeTitle, design: .serif, weight: .semibold)).padding(.top, 24)
                Text("Step \(index + 1) of \(r.steps.count)").font(.subheadline.weight(.semibold)).foregroundStyle(J.accent).padding(.top, 28)
                Text(step.instruction).font(.system(.title, design: .serif)).lineSpacing(4).padding(.top, 6)
                    .id(step.id).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                if let next = model.nextStep(after: index) {
                    Text("Next, at \(Fmt.clock(next.startS)): \(next.instruction)").font(.body).foregroundStyle(.secondary).padding(.top, 14)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline) {
                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 64, weight: .regular, design: .serif)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(Fmt.clock(r.totalS))").font(.title3).foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: min(1, elapsed / Double(r.totalS))).tint(J.accent).padding(.bottom, 24)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56).glassEffect(.regular.tint(J.accent).interactive(), in: .capsule)
                        Button("Write It Down") { model.finishBrew() }.font(.headline).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 56).glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            .padding(20)
            .background(J.paper)
        }
    }
}

private struct Log14: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(SampleData.today.formatted(.dateTime.weekday(.wide).month().day())).font(.subheadline.weight(.semibold)).foregroundStyle(J.accent)
                    Text(model.draft.bean).font(.system(.largeTitle, design: .serif, weight: .semibold))
                    TextField("How was it? What did you taste?", text: $model.draft.notes, axis: .vertical)
                        .font(.system(.title3, design: .serif)).lineLimit(4...10)
                    Divider().padding(.vertical, 6)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: J.accent, size: 24)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.medium))
                                    .foregroundStyle(on ? .white : .primary).padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(on ? J.accent : Color(.tertiarySystemFill), in: .capsule)
                                    .buttonStyle(PressScale()).accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Text("\(model.recipe.method) · \(Fmt.num(model.draft.doseG)) g → \(Fmt.num(model.draft.waterG)) g · \(Fmt.num(model.draft.tempC)) °C · \(Fmt.clock(model.draft.timeS))")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Stepper("Dose", value: $model.draft.doseG, in: 1...100, step: 0.5).labelsHidden()
                        Text("dose").font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Stepper("Water", value: $model.draft.waterG, in: 10...1000, step: 5).labelsHidden()
                        Text("water").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(J.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { model.save() }.buttonStyle(.glassProminent).tint(J.accent) }
            }
        }
    }
}
