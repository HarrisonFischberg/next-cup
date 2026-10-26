import SwiftUI

// 7. Ma. Exaggerated minimalism from Japanese print: rice paper or sumi black, Hiragino
// Mincho, one vermilion seal, and almost nothing else. The timer is a hairline circle and
// one number; the only control is a single clear glass disc.

private enum M {
    static let paper = Color(0xF6F2E9, 0x111111)
    static let ink = Color(0x1A1A1A, 0xEDE8DD)
    static let ink2 = Color(0x6B665C, 0x8F8A80)
    static let seal = Color(0xB3261E, 0xE8604F)
    static let onSeal = Color(0xFFFFFF, 0x111111)
    static func mincho(_ size: CGFloat, _ style: Font.TextStyle = .body, bold: Bool = false) -> Font {
        .custom(bold ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size, relativeTo: style)
    }
}

/// The square red seal stamped next to a title.
private struct Seal: View {
    let text: String
    var body: some View {
        Text(text).font(M.mincho(14, bold: true)).foregroundStyle(M.onSeal)
            .frame(width: 34, height: 34).background(M.seal, in: .rect(cornerRadius: 3))
            .accessibilityHidden(true)
    }
}

struct Look07: View {
    var body: some View {
        ConceptShell(tint: M.seal) { LookRecipe(model: $0) } timer: { Timer07(model: $0) }
            log: { Log07(model: $0) } journal: { Journal07(model: $0) }
    }
}

private struct Journal07: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 56) {
                HStack(alignment: .top) {
                    Text("一杯").font(M.mincho(54, .largeTitle)).foregroundStyle(M.ink)
                    Seal(text: "珈")
                }
                .padding(.top, 30)
                ForEach(model.journal) { e in
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(M.mincho(40, .title)).foregroundStyle(e.ratingHalfSteps >= 8 ? M.seal : M.ink)
                            .frame(width: 70, alignment: .leading)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(e.bean).font(M.mincho(19, .headline, bold: true)).foregroundStyle(M.ink)
                            Text(e.note).font(M.mincho(14)).foregroundStyle(M.ink2).lineSpacing(6)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 36).padding(.bottom, 40)
        }
        .background(M.paper)
    }
}

private struct Timer07: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                            .font(.title3.weight(.light)).foregroundStyle(M.ink2).frame(width: 44, height: 44)
                        Spacer()
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(M.ink2.opacity(0.25), lineWidth: 1)
                        Circle().trim(from: 0, to: min(1, elapsed / Double(r.totalS)))
                            .stroke(M.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 18) {
                            Text(Fmt.clock(Int(elapsed))).font(M.mincho(72, .largeTitle)).monospacedDigit().foregroundStyle(M.ink)
                            Text(step.cumulativeG.map { "\($0) g" } ?? step.kind.label).font(M.mincho(20, bold: true)).foregroundStyle(M.seal)
                        }
                    }
                    .frame(width: 280, height: 280)
                    .accessibilityElement(children: .combine)
                    Text(step.instruction).font(M.mincho(16)).foregroundStyle(M.ink2).multilineTextAlignment(.center)
                        .lineSpacing(8).padding(.top, 44).padding(.horizontal, 40)
                    Spacer()
                    Button(model.showsRunning ? "Pause" : "Begin") { model.toggleTimer() }
                        .font(M.mincho(17, bold: true)).foregroundStyle(M.ink)
                        .frame(width: 96, height: 96).lookGlass(nil, in: .circle, fallback: M.paper, clear: true)
                        .overlay(Circle().stroke(M.ink.opacity(0.3), lineWidth: 1))
                    Button("Finish") { model.finishBrew() }.font(M.mincho(15)).foregroundStyle(M.ink2)
                        .frame(minWidth: 88, minHeight: 44).padding(.top, 8)
                }
                // Steps as a quiet column of marks along the right edge.
                VStack(spacing: 14) {
                    ForEach(r.steps) { s in
                        Capsule().fill(s.id == index ? M.seal : M.ink2.opacity(s.id < index ? 0.8 : 0.25))
                            .frame(width: 2, height: s.id == index ? 30 : 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Step \(index + 1) of \(r.steps.count)")
            }
            .padding(24)
            .background(M.paper)
        }
    }
}

private struct Log07: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text("味").font(M.mincho(64, .largeTitle)).foregroundStyle(M.ink).padding(.top, 20)
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: M.seal, size: 22)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button { model.draft.verdict = on ? nil : v } label: {
                            HStack(spacing: 16) {
                                Rectangle().fill(on ? M.seal : .clear).frame(width: 2, height: 22)
                                Text(v.label).font(M.mincho(20, bold: on)).foregroundStyle(on ? M.ink : M.ink2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                HStack(spacing: 30) {
                    quiet("dose", Fmt.num(model.draft.doseG), $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                    quiet("water", Fmt.num(model.draft.waterG), $model.draft.waterG.stepped(by: 5, in: 10...1000))
                }
                Button("Keep") { model.save() }.font(M.mincho(18, bold: true)).foregroundStyle(M.onSeal)
                    .frame(width: 110, height: 110).background(M.seal, in: .circle).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)
        }
        .background(M.paper)
    }

    private func quiet(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(M.mincho(13)).foregroundStyle(M.ink2)
            Text("\(v) g").font(M.mincho(30)).foregroundStyle(M.ink)
            HStack(spacing: 0) {
                Button("Less \(k)", systemImage: "minus", action: step.down).frame(width: 44, height: 44)
                Button("More \(k)", systemImage: "plus", action: step.up).frame(width: 44, height: 44)
            }
            .labelStyle(.iconOnly).font(.body.weight(.light)).foregroundStyle(M.ink2)
        }
    }
}
