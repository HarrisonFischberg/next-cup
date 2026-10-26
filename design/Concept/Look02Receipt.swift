import SwiftUI

// 2. Receipt. Brutalism: every brew is a thermal-printer ticket. Menlo, all caps, dashed
// rules, torn edges. The only glass is one clear, square-cornered bar holding the actions.

private enum R {
    static let bg = Color(0xE4E2DC, 0x0C0C0C)
    static let paper = Color(0xFFFFFF, 0x1A1A1A)
    static let ink = Color(0x000000, 0xF2F2F2)
    static let ink2 = Color(0x4D4D4D, 0xA6A6A6)
    static let hot = Color(0xD0021B, 0xFF5C6C)
    static let onHot = Color(0xFFFFFF, 0x000000)
    static func mono(_ size: CGFloat, _ w: Font.Weight = .regular, _ style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: w, design: .monospaced)
    }
}

/// Zigzag top and bottom, like paper torn off the roll.
private struct Torn: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(), tooth: CGFloat = 8
        p.move(to: CGPoint(x: 0, y: tooth))
        var x: CGFloat = 0
        while x < r.width { p.addLine(to: CGPoint(x: x + tooth / 2, y: 0)); p.addLine(to: CGPoint(x: min(r.width, x + tooth), y: tooth)); x += tooth }
        p.addLine(to: CGPoint(x: r.width, y: r.height - tooth))
        while x > 0 { p.addLine(to: CGPoint(x: x - tooth / 2, y: r.height)); p.addLine(to: CGPoint(x: max(0, x - tooth), y: r.height - tooth)); x -= tooth }
        p.closeSubpath()
        return p
    }
}

private struct Dashes: View {
    var body: some View {
        Line().stroke(R.ink2, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1)
    }
    struct Line: Shape { func path(in r: CGRect) -> Path { Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: r.width, y: 0)) } } }
}

private struct Row: View {
    let k: String, v: String
    var body: some View {
        HStack(spacing: 4) {
            Text(k)
            Text(String(repeating: ".", count: 40)).lineLimit(1).foregroundStyle(R.ink2)
            Text(v).layoutPriority(1)
        }
        .font(R.mono(15)).foregroundStyle(R.ink)
        .accessibilityElement(children: .ignore).accessibilityLabel("\(k), \(v)")
    }
}

struct Look02: View {
    var body: some View {
        ConceptShell(tint: R.ink) { LookRecipe(model: $0) } timer: { Timer02(model: $0) }
            log: { Log02(model: $0) } journal: { Journal02(model: $0) }
    }
}

private struct Journal02: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("NEXT CUP\nBREW LOG").font(R.mono(30, .black)).multilineTextAlignment(.center)
                    .foregroundStyle(R.ink).frame(maxWidth: .infinity).padding(.top, 8)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(String(format: "%04d", 128 - i))").font(R.mono(13, .bold))
                            Spacer()
                            Text(Fmt.day(e.date).uppercased()).font(R.mono(13))
                        }
                        .foregroundStyle(R.ink2)
                        Text(e.bean.uppercased()).font(R.mono(19, .heavy)).foregroundStyle(R.ink)
                        Dashes()
                        Row(k: "METHOD", v: e.method.uppercased())
                        Row(k: "RATIO", v: "1:\(Fmt.num(e.ratio))")
                        Row(k: "TIME", v: Fmt.clock(e.timeS))
                        Dashes()
                        HStack {
                            Text("TOTAL").font(R.mono(17, .black))
                            Spacer()
                            Text(String(repeating: "★", count: e.ratingHalfSteps / 2) + String(repeating: "☆", count: 5 - e.ratingHalfSteps / 2))
                                .font(R.mono(17, .black))
                        }
                        .foregroundStyle(R.ink)
                        if let v = e.verdict {
                            Text("** \(v.label.uppercased()) **").font(R.mono(14, .bold)).foregroundStyle(R.hot)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 22)
                    .background(R.paper, in: Torn())
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(R.bg)
    }
}

private struct Timer02: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, frac = min(1, elapsed / Double(r.totalS))
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("[X] CLOSE") { model.showTimer = false }.font(R.mono(15, .bold)).frame(minHeight: 44)
                    Spacer()
                    Text(r.method.uppercased()).font(R.mono(15))
                }
                .foregroundStyle(R.ink)
                Text(String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                    .font(R.mono(110, .black)).minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(R.ink).padding(.top, 12)
                let filled = Int((frac * 24).rounded())
                Text("[" + String(repeating: "#", count: filled) + String(repeating: "·", count: 24 - filled) + "]")
                    .font(R.mono(17, .bold)).foregroundStyle(R.ink).lineLimit(1).minimumScaleFactor(0.5)
                    .accessibilityLabel("\(Int(frac * 100)) percent")
                Dashes().padding(.vertical, 16)
                ForEach(r.steps) { s in
                    let live = s.id == index
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(live ? ">" : " ").font(R.mono(17, .black))
                            Text(Fmt.clock(s.startS)).font(R.mono(15))
                            Text(s.kind.label.uppercased()).font(R.mono(17, live ? .black : .regular))
                            Spacer()
                            Text(s.cumulativeG.map { "\($0)G" } ?? "--").font(R.mono(15, .bold))
                        }
                        if live { Text(s.instruction.uppercased()).font(R.mono(13)).padding(.leading, 24) }
                    }
                    .foregroundStyle(live ? R.onHot : (s.id < index ? R.ink2 : R.ink))
                    .padding(.vertical, 6).padding(.horizontal, 6)
                    .background(live ? R.hot : .clear)
                    .strikethrough(s.id < index)
                }
                Spacer()
                GlassEffectContainer {
                    HStack(spacing: 0) {
                        Button(model.primaryTitle.uppercased()) { model.toggleTimer() }
                            .frame(maxWidth: .infinity, minHeight: 64)
                        Rectangle().fill(R.ink).frame(width: 2, height: 40)
                        Button("PRINT") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .font(R.mono(20, .black)).foregroundStyle(R.ink)
                    .lookGlass(nil, in: .rect, fallback: R.paper, clear: true)
                    .overlay(Rectangle().strokeBorder(R.ink, lineWidth: 3))
                }
            }
            .padding(20)
            .background(R.paper)
        }
    }
}

private struct Log02: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("RECEIPT").font(R.mono(34, .black)).foregroundStyle(R.ink)
                Text(model.draft.bean.uppercased()).font(R.mono(17, .bold)).foregroundStyle(R.ink2)
                Dashes()
                field("DOSE", "\(Fmt.num(model.draft.doseG)) G", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                field("WATER", "\(Fmt.num(model.draft.waterG)) G", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                field("TEMP", "\(Fmt.num(model.draft.tempC)) C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                Dashes()
                Text("TASTE").font(R.mono(15, .bold)).foregroundStyle(R.ink2)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Verdict.allCases) { v in
                        Button { model.draft.verdict = model.draft.verdict == v ? nil : v } label: {
                            Text("[\(model.draft.verdict == v ? "X" : " ")] \(v.label.uppercased())")
                                .font(R.mono(18, .bold)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .foregroundStyle(R.ink)
                        .accessibilityAddTraits(model.draft.verdict == v ? .isSelected : [])
                    }
                }
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: R.ink)
                Button("PRINT AND SAVE") { model.save() }
                    .font(R.mono(22, .black)).foregroundStyle(R.onHot)
                    .frame(maxWidth: .infinity, minHeight: 64).background(R.hot)
            }
            .padding(20)
        }
        .background(R.paper)
    }

    private func field(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        HStack(spacing: 0) {
            Text(k).font(R.mono(17, .bold)).frame(width: 80, alignment: .leading)
            Text(v).font(R.mono(26, .black)).frame(maxWidth: .infinity, alignment: .leading)
            Button("-", action: step.down).frame(width: 56, height: 56).border(R.ink, width: 3)
                .accessibilityLabel("Less \(k.lowercased())")
            Button("+", action: step.up).frame(width: 56, height: 56).border(R.ink, width: 3).padding(.leading, -3)
                .accessibilityLabel("More \(k.lowercased())")
        }
        .font(R.mono(28, .black)).foregroundStyle(R.ink)
    }
}
