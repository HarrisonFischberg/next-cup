import SwiftUI

// 29. Bubbles (Tripadvisor review). Organizing idea: the cup is reviewed like a place. Ratings
// are filled bubbles, the journal is a stack of reviews with a photo-square, and the timer
// shows progress as one bubble per step, filling as you go.

private enum C {
    static let green = Color(0x00894B, 0x34C77B)
    static let page = Color(0xFFFFFF, 0x0F1110)
    static let line = Color(0xD9DCD9, 0x333833)
    static let words = ["Not rated", "Terrible", "Poor", "Average", "Very good", "Excellent"]
}

private struct BubbleRow: View {
    var filled: Double // 0...5
    var size: CGFloat = 16
    var count = 5
    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(0..<count, id: \.self) { i in
                Circle().stroke(C.green, lineWidth: max(1.5, size / 10))
                    .background(Circle().fill(C.green).mask(alignment: .leading) { Rectangle().frame(width: size * min(1, max(0, filled - Double(i)))) })
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement().accessibilityLabel("\(Fmt.num(filled)) of \(count)")
    }
}

struct Look29: View {
    var body: some View {
        ConceptShell(tint: C.green) { LookRecipe(model: $0) } timer: { Timer29(model: $0) }
            log: { Review29(model: $0) } journal: { Reviews29(model: $0) }
    }
}

private struct Reviews29: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10).fill(BeanArt.color(e.bean).gradient).frame(width: 64, height: 64)
                                .overlay { Image(systemName: "mug.fill").font(.title2).foregroundStyle(.white.opacity(0.9)) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.bean).font(.headline)
                                Text(e.method).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            BubbleRow(filled: Double(e.ratingHalfSteps) / 2, size: 14)
                            Text(C.words[(e.ratingHalfSteps + 1) / 2]).font(.subheadline.weight(.semibold))
                        }
                        Text(e.note).font(.body)
                        Text("Brewed \(Fmt.day(e.date)) · \(Fmt.clock(e.timeS))").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 18).accessibilityElement(children: .combine).assemble(i)
                    Rectangle().fill(C.line).frame(height: 1)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(C.page)
        .navigationTitle("Reviews")
    }
}

private struct Timer29: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let within = (elapsed - Double(s.startS)) / Double(r.endS(of: s) - s.startS)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.headline).monospacedDigit()
                        .padding(.horizontal, 14).frame(minHeight: 36).overlay(Capsule().stroke(Color.primary, lineWidth: 1.5))
                }
                .foregroundStyle(.primary)
                Text("Step \(index + 1) of \(r.steps.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                BubbleRow(filled: Double(index) + min(1, within), size: 44, count: r.steps.count).frame(maxWidth: .infinity, alignment: .leading)
                Text(s.instruction).font(.system(size: 34, weight: .bold))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coming up").font(.headline)
                    ForEach(r.steps.filter { $0.id > index }) { n in
                        HStack {
                            Text(n.kind.label).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 36).overlay(Capsule().stroke(Color.primary, lineWidth: 1))
                            Text("at \(Fmt.clock(n.startS))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button(model.primaryTitle) { model.toggleTimer() }.font(.headline).foregroundStyle(C.page).frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.primary.opacity(0.9), in: .capsule).buttonStyle(PressScale())
                Button("Finish and review") { model.finishBrew() }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                    .background(C.green, in: .capsule).buttonStyle(PressScale())
            }
            .padding(20)
            .background(C.page.ignoresSafeArea())
        }
    }
}

private struct Review29: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8).fill(BeanArt.color(model.draft.bean).gradient).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.draft.bean).font(.headline)
                            Text("Cone dripper · \(Fmt.num(model.draft.doseG)) g · \(Fmt.clock(model.draft.timeS))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 12).stroke(C.line))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How would you rate this cup?").font(.title3.weight(.bold))
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { i in
                                Button { model.draft.ratingHalfSteps = i * 2 } label: {
                                    Circle().stroke(C.green, lineWidth: 2.5).background(Circle().fill(model.draft.ratingHalfSteps >= i * 2 ? C.green : .clear)).frame(width: 40, height: 40)
                                }
                                .frame(width: 44, height: 44).accessibilityLabel("\(i) of 5")
                            }
                            Text(C.words[model.draft.ratingHalfSteps / 2]).font(.subheadline).padding(.leading, 6)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How did it taste?").font(.title3.weight(.bold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? C.page : .primary).background(on ? Color.primary : .clear, in: .capsule)
                                    .overlay(Capsule().stroke(Color.primary, lineWidth: 1))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Write your review").font(.title3.weight(.bold))
                        TextField("What stood out?", text: $model.draft.notes, axis: .vertical).lineLimit(3...6)
                            .padding(12).overlay(RoundedRectangle(cornerRadius: 10).stroke(C.line))
                    }
                }
                .padding(20)
            }
            .background(C.page)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Post") { model.save() }.buttonStyle(.glassProminent).tint(C.green) }
            }
        }
    }
}
