import SwiftUI

// 32. Ledger (Future Pro activity rings + table). Organizing idea: a serif headline over a grid
// of small rings, then a plain data table you can scan by column. The timer is one ring and the
// recipe as a table with the live row highlighted; the log is a target-vs-actual table.

private enum C {
    static let page = Color(0xF3F2F0, 0x0E0E0F)
    static let head = Color(0xDCDBD8, 0x2A2A2C)
    static let ring = Color(0x5BBF3A, 0x7AD957)
    static let soft = Color(0xE8C9C9, 0x4A3434)
}

private struct Ring: View {
    var value: Double
    var width: CGFloat = 6
    var body: some View {
        ZStack {
            Circle().stroke(C.soft, lineWidth: width)
            Circle().trim(from: 0, to: value).stroke(C.ring, style: .init(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))
        }
    }
}

struct Look32: View {
    var body: some View {
        ConceptShell(tint: C.ring) { LookRecipe(model: $0) } timer: { Timer32(model: $0) }
            log: { Log32(model: $0) } journal: { Ledger32(model: $0) }
    }
}

private struct Ledger32: View {
    let model: FlowModel
    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Cup Rings").font(.system(size: 40, design: .serif))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(0..<8, id: \.self) { i in
                        let day = cal.date(byAdding: .day, value: i - 7, to: SampleData.today)!
                        let e = model.journal.first { cal.isDate($0.date, inSameDayAs: day) }
                        VStack(spacing: 6) {
                            Text(i == 7 ? "Today" : day.formatted(.dateTime.weekday(.abbreviated))).font(.caption).foregroundStyle(.secondary)
                            Ring(value: Double(e?.ratingHalfSteps ?? 0) / 10, width: 7).frame(width: 52, height: 52)
                        }
                        .accessibilityElement().accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(e.map { Fmt.stars($0.ratingHalfSteps) } ?? "no cup")")
                    }
                }
                VStack(spacing: 0) {
                    row(["Date", "Bean", "Score", "Time"], header: true)
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 10) {
                            Ring(value: Double(e.ratingHalfSteps) / 10, width: 3).frame(width: 16, height: 16)
                            row([e.date.formatted(.dateTime.month(.abbreviated).day()), BeanArt.origin(e.bean), Fmt.num(Double(e.ratingHalfSteps) / 2), Fmt.clock(e.timeS)], header: false)
                        }
                        .padding(.leading, 12).accessibilityElement(children: .combine).assemble(i)
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.page)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func row(_ cells: [String], header: Bool) -> some View {
        HStack {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(c).font(header ? .subheadline.weight(.medium) : .subheadline).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .center)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, header ? 12 : 0)
        .background(header ? C.head : .clear, in: .rect(cornerRadius: 10))
    }
}

private struct Timer32: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Close", systemImage: "chevron.left") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .frame(width: 48, height: 48).background(Color(.systemBackground), in: .circle).foregroundStyle(.primary)
                    Spacer()
                }
                Text(r.steps[index].kind.label).font(.system(size: 40, design: .serif))
                HStack(spacing: 24) {
                    ZStack {
                        Ring(value: elapsed / Double(r.totalS), width: 16)
                        Text(Fmt.clock(Int(elapsed))).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                    }
                    .frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("of \(Fmt.clock(r.totalS))").font(.title3).foregroundStyle(.secondary)
                        Text(r.steps[index].instruction).font(.body)
                    }
                }
                VStack(spacing: 0) {
                    HStack { Text("Step"); Spacer(); Text("Start").frame(width: 60); Text("Water").frame(width: 70) }
                        .font(.subheadline.weight(.medium)).padding(12).background(C.head, in: .rect(cornerRadius: 10))
                    ForEach(r.steps) { s in
                        HStack {
                            Image(systemName: s.id < index ? "checkmark.circle.fill" : (s.id == index ? "circle.inset.filled" : "circle")).foregroundStyle(s.id <= index ? C.ring : .secondary)
                            Text(s.kind.label)
                            Spacer()
                            Text(Fmt.clock(s.startS)).frame(width: 60)
                            Text(s.cumulativeG.map { "\($0) g" } ?? "–").frame(width: 70)
                        }
                        .font(.subheadline.weight(s.id == index ? .semibold : .regular)).monospacedDigit()
                        .padding(12).background(s.id == index ? C.ring.opacity(0.15) : .clear, in: .rect(cornerRadius: 10))
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Button("Finish") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 54).background(C.head, in: .capsule).foregroundStyle(.primary)
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 54).background(C.ring, in: .capsule).foregroundStyle(.black)
                }
                .font(.headline).buttonStyle(PressScale())
            }
            .padding(16)
            .background(C.page.ignoresSafeArea())
        }
    }
}

private struct Log32: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Log cup").font(.system(size: 40, design: .serif))
                    VStack(spacing: 0) {
                        HStack { Text("Field"); Spacer(); Text("Target").frame(width: 70); Text("Actual").frame(width: 128) }
                            .font(.subheadline.weight(.medium)).padding(12).background(C.head, in: .rect(cornerRadius: 10))
                        line("Dose", "\(Fmt.num(model.recipe.doseG)) g", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        line("Water", "\(Fmt.num(model.recipe.waterG)) g", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        line("Temp", "\(Fmt.num(model.recipe.tempC))°", "\(Fmt.num(model.draft.tempC))°", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                    Text("Score").font(.headline)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.ring)
                    Picker("Taste", selection: $model.draft.verdict) {
                        Text("None").tag(Verdict?.none)
                        ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(16)
            }
            .background(C.page)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.ring) }
            }
        }
    }

    private func line(_ k: String, _ target: String, _ actual: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Text(k)
            Spacer()
            Text(target).foregroundStyle(.secondary).frame(width: 70)
            HStack(spacing: 2) {
                Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 36, height: 44)
                Text(actual).fontWeight(.semibold).frame(minWidth: 52)
                Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 36, height: 44)
            }
            .labelStyle(.iconOnly).frame(width: 128)
        }
        .font(.subheadline).monospacedDigit().padding(.horizontal, 12)
        .overlay(alignment: .bottom) { Divider() }
    }
}
