import SwiftUI

// 23. Workout (Nike Training Club). Organizing idea: the recipe is a circuit. A black bar holds
// one huge clock; below it every step is a row led by its load ("60 g", "15 s"), the live row
// lit white and the rest dimmed. The journal is an activity history with one giant total.

private enum C {
    static let bar = Color(0x000000, 0x000000)
    static let sheet = Color(0x2B2B2B, 0x1C1C1C)
    static let row = Color(0xFFFFFF, 0xFFFFFF)
    static let page = Color(0xFFFFFF, 0x000000)
    static let line = Color(0xE4E4E4, 0x2A2A2A)
}

private extension Font {
    static func block(_ size: CGFloat) -> Font { .system(size: size, weight: .black).width(.condensed) }
}

struct Look23: View {
    var body: some View {
        ConceptShell(tint: .primary) { LookRecipe(model: $0) } timer: { Timer23(model: $0) }
            log: { Log23(model: $0) } journal: { History23(model: $0) }
    }
}

private struct History23: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(model.journal.count)").font(.block(110)).monospacedDigit()
                    Text("Total brews").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(model.journal.reduce(0) { $0 + $1.timeS } / 60)").font(.title2.weight(.bold)).padding(.top, 14)
                    Text("Total minutes").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
                Rectangle().fill(C.line).frame(height: 8)
                HStack {
                    Text("October 2026").font(.headline)
                    Spacer()
                    Text("\(model.journal.count) Brews").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(16)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        BeanArt.color(e.bean).frame(width: 64, height: 64)
                            .overlay { Text(Fmt.clock(e.timeS)).font(.block(20)).foregroundStyle(.white) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(e.method), \(BeanArt.origin(e.bean))").font(.body.weight(.medium))
                            Text("\(Fmt.day(e.date))  \(Fmt.stars(e.ratingHalfSteps))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
        }
        .background(C.page)
        .navigationTitle("Activity").navigationBarTitleDisplayMode(.inline)
    }
}

private struct Timer23: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: 0) {
                HStack {
                    Text(Fmt.clock(Int(elapsed))).font(.block(84)).monospacedDigit().contentTransition(.numericText())
                    Spacer()
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause" : "play.fill") { model.toggleTimer() }
                        .labelStyle(.iconOnly).font(.title2.weight(.semibold)).frame(width: 64, height: 64)
                        .overlay(Circle().stroke(.white, lineWidth: 2)).contentTransition(.symbolEffect(.replace))
                }
                .foregroundStyle(.white).padding(.horizontal, 20).padding(.bottom, 8)
                .background(C.bar.ignoresSafeArea(edges: .top))
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(r.method).font(.block(30))
                            Spacer()
                            Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                        }
                        .foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 10)
                        ForEach(r.steps) { s in
                            let live = s.id == index
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(s.cumulativeG.map { "\($0)g" } ?? "\(r.endS(of: s) - s.startS)s").font(.block(24)).frame(width: 64, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.kind.label).font(.headline)
                                    Text(s.instruction).font(.subheadline).opacity(0.6)
                                }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(live ? Color.black : Color.white.opacity(s.id < index ? 0.35 : 0.8))
                            .padding(16)
                            .background(live ? C.row : .clear, in: .rect(cornerRadius: 6))
                            .accessibilityElement(children: .combine).accessibilityAddTraits(live ? .isSelected : [])
                        }
                    }
                    .padding(8)
                }
                .background(C.sheet)
                Button { model.finishBrew() } label: {
                    Text("Complete Brew").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 58)
                        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1.5))
                }
                .buttonStyle(PressScale()).padding(20).background(C.sheet)
            }
            .background(C.sheet.ignoresSafeArea())
        }
    }
}

private struct Log23: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("HOW DID IT GO?").font(.block(46))
                    HStack(spacing: 0) {
                        stat("Dose", "\(Fmt.num(model.draft.doseG))g")
                        stat("Water", "\(Fmt.num(model.draft.waterG))g")
                        stat("Time", Fmt.clock(model.draft.timeS))
                    }
                    Rectangle().fill(C.line).frame(height: 1)
                    Text("Effort").font(.headline)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: .primary, size: 30)
                    Text("Taste").font(.headline)
                    FlowChips(selection: $model.draft.verdict)
                    TextField("Add a note", text: $model.draft.notes, axis: .vertical).lineLimit(2...5)
                        .padding(14).overlay(RoundedRectangle(cornerRadius: 6).stroke(C.line))
                }
                .padding(20)
            }
            .background(C.page)
            .safeAreaInset(edge: .bottom) {
                Button { model.save() } label: {
                    Text("Save Brew").font(.headline).foregroundStyle(C.page).frame(maxWidth: .infinity, minHeight: 58).background(Color.primary, in: .capsule)
                }
                .buttonStyle(PressScale()).padding(.horizontal, 20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.block(34)).monospacedDigit()
            Text(k).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowChips: View {
    @Binding var selection: Verdict?
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Verdict.allCases) { v in
                let on = selection == v
                Button(v.label) { selection = on ? nil : v }.font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(on ? C.page : .primary).background(on ? Color.primary : .clear, in: .capsule)
                    .overlay(Capsule().stroke(Color.primary, lineWidth: 1.5))
                    .accessibilityAddTraits(on ? .isSelected : []).sensoryFeedback(.selection, trigger: on)
            }
        }
    }
}
