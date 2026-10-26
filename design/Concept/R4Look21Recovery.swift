import SwiftUI

// 21. Recovery (WHOOP breathwork + calendar). Organizing idea: a brew is a guided session on a
// dark field. The timer is a dotted orbit around a glowing core; the journal is a month grid
// whose day numbers glow by score; the log is a yes/no checklist of what happened.

private enum C {
    static let bg = Color(0xEEF1F2, 0x0D1315)
    static let card = Color(0xFFFFFF, 0x1A2226)
    static let glow = Color(0x0F8A78, 0x4FE0C4)
    static let mid = Color(0xB07A12, 0xF2C94C)
    static let low = Color(0xB8322A, 0xFF5D5D)
    static func score(_ half: Int) -> Color { half >= 8 ? glow : (half >= 6 ? mid : low) }
}

struct Look21: View {
    var body: some View {
        ConceptShell(tint: C.glow) { LookRecipe(model: $0) } timer: { Timer21(model: $0) }
            log: { Log21(model: $0) } journal: { Journal21(model: $0) }
    }
}

private struct Journal21: View {
    let model: FlowModel
    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                month.padding(16).background(C.card, in: .rect(cornerRadius: 20))
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                            Circle().trim(from: 0, to: Double(e.ratingHalfSteps) / 10).stroke(C.score(e.ratingHalfSteps), style: .init(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("\(e.ratingHalfSteps * 10)").font(.caption.weight(.bold)).monospacedDigit()
                        }
                        .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.bean.uppercased()).font(.subheadline.weight(.bold)).tracking(0.6)
                            Text("\(Fmt.day(e.date)) · \(e.method) · \(Fmt.clock(e.timeS))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14).background(C.card, in: .rect(cornerRadius: 16))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.bg)
        .navigationTitle("Recovery")
    }

    private var month: some View {
        let start = cal.dateInterval(of: .month, for: SampleData.today)!.start
        let lead = cal.component(.weekday, from: start) - 1
        let days = cal.range(of: .day, in: .month, for: start)!.count
        return VStack(spacing: 12) {
            Text(start.formatted(.dateTime.month(.wide)).uppercased()).font(.footnote.weight(.bold)).tracking(2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(0..<(7 + lead + days), id: \.self) { i in
                    if i < 7 {
                        Text(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][i]).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    } else if i < 7 + lead {
                        Color.clear.frame(height: 30)
                    } else {
                        let d = i - 7 - lead + 1
                        let date = cal.date(byAdding: .day, value: d - 1, to: start)!
                        let e = model.journal.first { cal.isDate($0.date, inSameDayAs: date) }
                        Text("\(d)").font(.callout.weight(e == nil ? .regular : .bold)).monospacedDigit()
                            .foregroundStyle(e.map { C.score($0.ratingHalfSteps) } ?? Color.secondary.opacity(0.6))
                            .frame(height: 30)
                    }
                }
            }
        }
    }
}

private struct Timer21: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            VStack(spacing: 24) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44).foregroundStyle(.primary)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(s.kind.label.uppercased()).font(.subheadline.weight(.bold)).tracking(1.5)
                        Text("STEP \(index + 1)/\(r.steps.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.5), style: .init(lineWidth: 1.5, dash: [1.5, 7]))
                    Circle().trim(from: 0, to: elapsed / Double(r.totalS)).stroke(C.glow, style: .init(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                    Circle().fill(C.card).frame(width: 140, height: 140)
                        .overlay(Circle().stroke(C.glow.opacity(0.8), lineWidth: 3))
                        .shadow(color: C.glow.opacity(0.55), radius: 26)
                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                }
                .frame(width: 290, height: 290)
                .accessibilityElement().accessibilityLabel("Elapsed \(Fmt.clock(Int(elapsed)))")
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle().stroke(C.glow, lineWidth: 2).frame(width: 9, height: 9)
                    Text(s.instruction).font(.title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                Spacer()
                Button { model.toggleTimer() } label: {
                    Text(model.primaryTitle.uppercased()).font(.subheadline.weight(.bold)).tracking(1.5).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(C.bg).background(C.glow, in: .capsule)
                }
                .buttonStyle(PressScale())
                Button { model.finishBrew() } label: {
                    Text("FINISH BREW").font(.subheadline.weight(.bold)).tracking(1.5).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(C.glow).overlay(Capsule().stroke(C.glow, lineWidth: 1.5))
                }
                .buttonStyle(PressScale())
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(C.bg.ignoresSafeArea())
        }
    }
}

private struct Log21: View {
    @Bindable var model: FlowModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("What happened in this cup?").font(.title.weight(.bold))
                    Text("TASTE").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        HStack {
                            Text("Tasted \(v.label.lowercased())?").font(.body.weight(.medium))
                            Spacer()
                            toggle("xmark", on: !on && model.draft.verdict != nil) { model.draft.verdict = nil }
                            toggle("checkmark", on: on) { model.draft.verdict = v }
                        }
                        .padding(.leading, 16).padding(.trailing, 8).frame(minHeight: 60)
                        .background(C.card, in: .rect(cornerRadius: 14))
                    }
                    Text("SCORE").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.glow)
                        .frame(maxWidth: .infinity).padding(8).background(C.card, in: .rect(cornerRadius: 14))
                }
                .padding(20)
            }
            .background(C.bg)
            .safeAreaInset(edge: .bottom) {
                Button { model.save() } label: {
                    Text("SAVE CUP").font(.subheadline.weight(.bold)).tracking(1.5).frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(C.bg).background(Color.primary, in: .capsule)
                }
                .buttonStyle(PressScale()).padding(.horizontal, 20).padding(.bottom, 8)
            }
            .navigationTitle(model.draft.bean.uppercased()).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }

    private func toggle(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.subheadline.weight(.bold)).frame(width: 40, height: 40)
                .foregroundStyle(on ? Color.white : Color.secondary)
                .background(on ? (symbol == "checkmark" ? C.glow : C.low) : Color.secondary.opacity(0.15), in: .rect(cornerRadius: 9))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(symbol == "checkmark" ? "Yes" : "No").accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}
