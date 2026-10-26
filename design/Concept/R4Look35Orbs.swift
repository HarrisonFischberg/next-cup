import SwiftUI

// 35. Orbs (Stardust tracker). Organizing idea: everything you pick is a glowing orb on deep
// indigo. A dotted day timeline runs across the top; tastes are rows of orbs you tap; the
// timer is one large orb for the live step with the other steps as small orbs beneath.

private enum C {
    static let night = Color(0x221A5C, 0x150F3D)
    static let chip = Color(0x352B7A, 0x2A2266)
    static let cream = Color(0xF4EEDB, 0xF4EEDB)
    static func orb(_ i: Int) -> [Color] {
        [[Color(0xFF8A5B, 0xFF8A5B), Color(0xC2185B, 0xC2185B)], [Color(0x7CE0A0, 0x7CE0A0), Color(0x1E8E6E, 0x1E8E6E)],
         [Color(0x8FB8FF, 0x8FB8FF), Color(0x4A3FD1, 0x4A3FD1)], [Color(0xFFD45C, 0xFFD45C), Color(0xE0731F, 0xE0731F)],
         [Color(0xE29BFF, 0xE29BFF), Color(0x7B2FBE, 0x7B2FBE)], [Color(0x8CF0F0, 0x8CF0F0), Color(0x2B7FA8, 0x2B7FA8)]][i % 6]
    }
}

private struct Orb: View {
    let symbol: String
    let tone: Int
    var size: CGFloat = 64
    var on = true
    var body: some View {
        Circle().fill(RadialGradient(colors: C.orb(tone), center: .topLeading, startRadius: 2, endRadius: size))
            .overlay { Image(systemName: symbol).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.white) }
            .frame(width: size, height: size).saturation(on ? 1 : 0.15).opacity(on ? 1 : 0.55)
            .background(Circle().fill(C.chip).padding(-6))
    }
}

private struct DayDots: View {
    let model: FlowModel
    private let cal = Calendar.current
    var body: some View {
        HStack(spacing: 10) {
            ForEach(-12...0, id: \.self) { o in
                let d = cal.date(byAdding: .day, value: o, to: SampleData.today)!
                let e = model.journal.first { cal.isDate($0.date, inSameDayAs: d) }
                VStack(spacing: 4) {
                    Circle().fill(e.map { C.orb($0.ratingHalfSteps).first! } ?? C.cream.opacity(0.25)).frame(width: o == 0 ? 18 : 12, height: o == 0 ? 18 : 12)
                        .overlay(Circle().stroke(C.cream, lineWidth: o == 0 ? 2 : 0).padding(-4))
                    Text(d.formatted(.dateTime.day())).font(.caption2).foregroundStyle(C.cream.opacity(0.6))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct Look35: View {
    var body: some View {
        ConceptShell(tint: C.cream) { LookRecipe(model: $0) } timer: { Timer35(model: $0) }
            log: { Log35(model: $0) } journal: { Journal35(model: $0) }
    }
}

private struct Journal35: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(SampleData.today.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.title3.weight(.semibold))
                DayDots(model: model)
                Text("CUPS").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(C.cream.opacity(0.7))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 22) {
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        VStack(spacing: 10) {
                            Orb(symbol: "cup.and.saucer.fill", tone: e.ratingHalfSteps, size: 76)
                            Text(BeanArt.origin(e.bean)).font(.subheadline.weight(.semibold))
                            Text("\(Fmt.num(Double(e.ratingHalfSteps) / 2)) ★ · \(Fmt.day(e.date).components(separatedBy: ", ").last ?? "")").font(.caption).foregroundStyle(C.cream.opacity(0.7))
                        }
                        .accessibilityElement(children: .combine).assemble(i)
                    }
                }
            }
            .padding(20).foregroundStyle(C.cream)
        }
        .background(C.night)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct Timer35: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            VStack(spacing: 22) {
                HStack {
                    Text(Fmt.clock(Int(elapsed))).font(.title2.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                    Spacer()
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                }
                Spacer()
                Orb(symbol: s.kind.symbol, tone: index, size: 190).symbolEffect(.pulse, isActive: model.showsRunning)
                Text(s.kind.label + (s.cumulativeG.map { " · \($0) g" } ?? "")).font(.title.weight(.bold))
                Text(s.instruction).font(.body).multilineTextAlignment(.center).opacity(0.8)
                Spacer()
                HStack(spacing: 14) {
                    ForEach(r.steps) { st in Orb(symbol: st.kind.symbol, tone: st.id, size: 34, on: st.id <= index) }
                }
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    Button("Done") { model.finishBrew() }.frame(width: 100, height: 56).background(C.chip, in: .capsule)
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 56).background(C.cream, in: .capsule).foregroundStyle(C.night)
                }
                .font(.headline).buttonStyle(PressScale())
            }
            .padding(20).foregroundStyle(C.cream)
            .background(C.night.ignoresSafeArea())
        }
    }
}

private struct Log35: View {
    @Bindable var model: FlowModel
    @State private var tab = "Taste"
    private let tastes: [(Verdict, String)] = [(.sour, "bolt.fill"), (.bitter, "leaf.fill"), (.weak, "drop"), (.strong, "flame.fill"), (.balanced, "sparkles")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DayDots(model: model)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(["Taste", "Score", "Amounts", "Notes"], id: \.self) { t in
                                Button(t.uppercased()) { tab = t }.font(.caption.weight(.bold)).padding(.horizontal, 14).frame(minHeight: 36)
                                    .foregroundStyle(tab == t ? C.night : C.cream).background(tab == t ? C.cream : C.chip, in: .capsule).frame(minHeight: 44)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Text("TASTE").font(.caption.weight(.bold)).tracking(1.5)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(Array(tastes.enumerated()), id: \.offset) { i, t in
                            let on = model.draft.verdict == t.0
                            Button { model.draft.verdict = on ? nil : t.0 } label: {
                                VStack(spacing: 8) {
                                    Orb(symbol: t.1, tone: i, size: 62, on: model.draft.verdict == nil || on)
                                    Text(t.0.label).font(.caption)
                                }
                            }
                            .accessibilityLabel(t.0.label).accessibilityAddTraits(on ? .isSelected : []).sensoryFeedback(.selection, trigger: on)
                        }
                    }
                    Text("SCORE").font(.caption.weight(.bold)).tracking(1.5)
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.cream)
                }
                .padding(20).foregroundStyle(C.cream)
            }
            .background(C.night)
            .safeAreaInset(edge: .bottom) {
                Button("Add to journal") { model.save() }.font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                    .background(C.chip, in: .capsule).foregroundStyle(C.cream).padding(.horizontal, 40)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false }.tint(C.cream) } }
        }
    }
}
