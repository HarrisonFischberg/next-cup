import SwiftUI

// 27. Balance (Cash App). Organizing idea: one number, as big as the screen allows, on a solid
// field. The timer is the water in the cup the way a balance is shown; the journal is an
// activity feed with signed amounts; the log asks one plain question at a time with radio rows.

private enum C {
    static let field = Color(0x1F7A4D, 0x1F7A4D)
    static let page = Color(0xFFFFFF, 0x000000)
    static let line = Color(0xE2E2E2, 0x2C2C2C)
}

struct Look27: View {
    var body: some View {
        ConceptShell(tint: C.field) { LookRecipe(model: $0) } timer: { Timer27(model: $0) }
            log: { Log27(model: $0) } journal: { Feed27(model: $0) }
    }
}

private struct Feed27: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Cups this week").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 8)
                Text("\(model.journal.count)").font(.system(size: 76, weight: .heavy, design: .rounded)).monospacedDigit()
                HStack(spacing: 10) {
                    Button("Brew") { model.tab = .recipes }.frame(maxWidth: .infinity, minHeight: 48).background(Color.primary, in: .capsule).foregroundStyle(C.page)
                    Button("Log") { model.prefillFromRecipe(measuredS: 180); model.showLog = true }.frame(maxWidth: .infinity, minHeight: 48).background(Color.secondary.opacity(0.15), in: .capsule)
                }
                .font(.headline).foregroundStyle(.primary).buttonStyle(PressScale()).padding(.vertical, 16)
                Text("Activity").font(.title3.weight(.bold)).padding(.top, 12).padding(.bottom, 6)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        Text(String(BeanArt.origin(e.bean).prefix(1))).font(.title3.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(BeanArt.color(e.bean), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.bean).font(.body.weight(.semibold))
                            Text("\(e.method) · \(Fmt.day(e.date))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(Fmt.num(e.waterG)) g").font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(e.ratingHalfSteps >= 7 ? C.field : .primary)
                    }
                    .padding(.vertical, 10).accessibilityElement(children: .combine).assemble(i)
                    Rectangle().fill(C.line).frame(height: 1).padding(.leading, 60)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(C.page)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct Timer27: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let target = r.steps[...index].compactMap(\.cumulativeG).last ?? 0
            VStack(spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.title3.weight(.bold)).frame(width: 44, height: 44)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.headline).monospacedDigit().padding(.horizontal, 14).frame(minHeight: 36).background(.white.opacity(0.18), in: .capsule)
                }
                Spacer()
                Text("\(target)g").font(.system(size: 120, weight: .heavy, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
                Text(s.instruction).font(.title3.weight(.semibold)).multilineTextAlignment(.center).opacity(0.85).padding(.horizontal, 20)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(r.steps) { st in Capsule().fill(.white.opacity(st.id <= index ? 1 : 0.3)).frame(height: 4) }
                }
                .padding(.bottom, 20).accessibilityHidden(true)
                HStack(spacing: 10) {
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 58).background(.black.opacity(0.85), in: .capsule)
                    Button("Done") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 58).background(.black.opacity(0.85), in: .capsule)
                }
                .font(.title3.weight(.bold)).buttonStyle(PressScale())
            }
            .foregroundStyle(.white).padding(20)
            .background(C.field.ignoresSafeArea())
        }
    }
}

private struct Log27: View {
    @Bindable var model: FlowModel
    private let answers = [(10, "Excellent"), (8, "Very good"), (6, "Fine"), (4, "Not great"), (2, "Not at all")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How good was this cup?").font(.system(size: 32, weight: .bold)).padding(.bottom, 6)
                    ForEach(answers, id: \.0) { half, label in
                        let on = model.draft.ratingHalfSteps == half
                        Button { model.draft.ratingHalfSteps = half } label: {
                            HStack {
                                Text(label).font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: on ? "record.circle" : "circle").font(.title2).foregroundStyle(on ? .primary : .secondary)
                            }
                            .padding(.horizontal, 16).frame(minHeight: 56)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Color.primary : C.line, lineWidth: on ? 2 : 1))
                        }
                        .foregroundStyle(.primary).accessibilityAddTraits(on ? .isSelected : []).sensoryFeedback(.selection, trigger: on)
                    }
                    Text("Was it balanced?").font(.title2.weight(.bold)).padding(.top, 22)
                    HStack(spacing: 10) {
                        pill("No", on: model.draft.verdict != nil && model.draft.verdict != .balanced) { model.draft.verdict = .sour }
                        pill("Yes", on: model.draft.verdict == .balanced) { model.draft.verdict = .balanced }
                    }
                }
                .padding(20)
            }
            .background(C.page)
            .safeAreaInset(edge: .bottom) {
                Button("Save") { model.save() }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                    .background(C.field, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }

    private func pill(_ t: String, on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(t, action: a).font(.headline).frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(on ? C.page : .primary).background(on ? Color.primary : Color.secondary.opacity(0.15), in: .capsule)
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}
