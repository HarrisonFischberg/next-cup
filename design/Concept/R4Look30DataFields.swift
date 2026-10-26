import SwiftUI

// 30. Data Fields (Garmin). Organizing idea: the phone becomes a sports watch face. The timer is
// four data fields split by hairlines, labels tiny and values huge; the journal is a range
// selector over weekly rows with goal rings; the log is a grouped settings-style form.

private enum C {
    static let page = Color(0xF2F2F7, 0x000000)
    static let row = Color(0xFFFFFF, 0x1C1C1E)
    static let blue = Color(0x0A6FD6, 0x3FA2FF)
    static let good = Color(0x1F9D47, 0x30D158)
}

struct Look30: View {
    var body: some View {
        ConceptShell(tint: C.blue) { LookRecipe(model: $0) } timer: { Fields30(model: $0) }
            log: { Feedback30(model: $0) } journal: { Weeks30(model: $0) }
    }
}

private struct Weeks30: View {
    let model: FlowModel
    @State private var range = "4w"

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("Range", selection: $range) { ForEach(["1d", "7d", "4w", "1y"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                HStack {
                    Image(systemName: "chevron.left.circle.fill").font(.title3).foregroundStyle(.secondary)
                    Spacer()
                    Text("Sep 17 – Oct 14, 2026").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill").font(.title3).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    let pct = Int(Double(e.ratingHalfSteps) / 9 * 100)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Fmt.day(e.date)) · \(BeanArt.origin(e.bean))").font(.headline)
                            Text("\(pct)% of best cup").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.clock(e.timeS)).font(.title3).monospacedDigit()
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                            if pct >= 100 {
                                Circle().stroke(C.good, lineWidth: 3)
                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(C.good)
                            } else {
                                Circle().trim(from: 0, to: Double(pct) / 100).stroke(C.blue, style: .init(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: 30, height: 30).padding(.leading, 10)
                    }
                    .padding(16).background(C.row, in: .rect(cornerRadius: 12))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.page)
        .navigationTitle("Brew Stats").navigationBarTitleDisplayMode(.inline)
    }
}

private struct Fields30: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let next = model.nextStep(after: index)
            VStack(spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                    Spacer()
                    Text("CONE DRIPPER").font(.caption.weight(.bold)).tracking(1)
                    Spacer()
                    Circle().fill(model.showsRunning ? C.good : .secondary).frame(width: 10, height: 10).frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                field("TIME", Fmt.clock(Int(elapsed)), big: true)
                Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1)
                HStack(spacing: 0) {
                    field("WATER", s.cumulativeG.map { "\($0)" } ?? "–", big: false)
                    Rectangle().fill(.secondary.opacity(0.4)).frame(width: 1)
                    field("STEP", "\(index + 1)/\(r.steps.count)", big: false)
                }
                Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1)
                HStack(spacing: 0) {
                    field("NEXT IN", next.map { Fmt.clock($0.startS - Int(elapsed)) } ?? "–", big: false)
                    Rectangle().fill(.secondary.opacity(0.4)).frame(width: 1)
                    field("TEMP °C", Fmt.num(r.tempC), big: false)
                }
                Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1)
                Text(s.instruction).font(.headline).multilineTextAlignment(.center).padding(16).frame(maxHeight: .infinity)
                HStack(spacing: 10) {
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 56).background(C.blue, in: .rect(cornerRadius: 12)).foregroundStyle(.white)
                    Button("Save") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 56).background(C.row, in: .rect(cornerRadius: 12)).foregroundStyle(.primary)
                }
                .font(.headline).buttonStyle(PressScale()).padding(16)
            }
            .background(C.page.ignoresSafeArea())
        }
    }

    private func field(_ label: String, _ value: String, big: Bool) -> some View {
        VStack(spacing: 0) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: big ? 104 : 56, weight: .semibold, design: .rounded).width(.condensed)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct Feedback30: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            Form {
                Section("How would you rate this brew?") {
                    ForEach([(8, "Great", "face.smiling"), (6, "OK", "face.dashed"), (3, "Poor", "hand.thumbsdown")], id: \.0) { h, t, icon in
                        Button { model.draft.ratingHalfSteps = h } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon).font(.title2).foregroundStyle(.secondary).frame(width: 32)
                                Text(t).foregroundStyle(.primary)
                                Spacer()
                                if model.draft.ratingHalfSteps == h { Image(systemName: "checkmark").foregroundStyle(C.blue).fontWeight(.semibold) }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                Section("Values") {
                    Stepper("Dose  \(Fmt.num(model.draft.doseG)) g", value: $model.draft.doseG, in: 1...100, step: 0.5)
                    Stepper("Water  \(Fmt.num(model.draft.waterG)) g", value: $model.draft.waterG, in: 10...1000, step: 5)
                    Stepper("Grind  \(model.draft.grind)", value: $model.draft.grind, in: 1...60)
                }
                Section("Additional feedback (optional)") {
                    TextField("Add feedback", text: $model.draft.notes, axis: .vertical).lineLimit(2...5)
                }
                Section("What stood out? (optional)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(on ? .white : .primary).background(on ? C.blue : .clear, in: .capsule)
                                .overlay(Capsule().stroke(Color.secondary.opacity(0.5))).buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Brew Feedback").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() } }
            }
        }
    }
}
