import SwiftUI

// 3. Bauhaus. Primary red, blue and yellow blocks, Futura, hard offset shadows. The timer is
// a poster: one big circle filling in quarters. Glass buttons are square and cast a hard
// shadow, the way the rest of the poster does.

private enum B {
    static let bg = Color(0xF0EDE4, 0x121212)
    static let ink = Color(0x121212, 0xF0EDE4)
    static let red = Color(0xC81E1E, 0xF0524A)
    static let blue = Color(0x1440B8, 0x5C86FF)
    static let yellow = Color(0xF0C020, 0xF0C020)
    static let onColor = Color(0xFFFFFF, 0x121212)
    static func futura(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font {
        .custom("Futura-Bold", size: size, relativeTo: style)
    }
}

private extension View {
    func block(_ fill: Color) -> some View {
        background(fill).overlay(Rectangle().strokeBorder(B.ink, lineWidth: 3))
            .background(B.ink.offset(x: 5, y: 5))
    }
}

struct Look03: View {
    var body: some View {
        ConceptShell(tint: B.red) { LookRecipe(model: $0) } timer: { Timer03(model: $0) }
            log: { Log03(model: $0) } journal: { Journal03(model: $0) }
    }
}

private struct Journal03: View {
    let model: FlowModel
    private let colors = [B.red, B.blue, B.yellow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 10) {
                    Circle().fill(B.red).frame(width: 46)
                    Rectangle().fill(B.blue).frame(width: 46, height: 46)
                    Triangle().fill(B.yellow).frame(width: 50, height: 46)
                }
                .accessibilityHidden(true)
                Text("BREWS").font(B.futura(56, .largeTitle)).foregroundStyle(B.ink)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        let fill = colors[i % 3], text = i % 3 == 2 ? B.ink : B.onColor
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(B.futura(44, .title))
                            Text(e.bean.uppercased()).font(B.futura(15, .headline)).lineLimit(2)
                            Text("\(e.method) · 1:\(Fmt.num(e.ratio))").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(i % 3 == 2 ? Color(0x121212, 0x121212) : text)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading).padding(14)
                        .block(fill)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(20)
        }
        .background(B.bg)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: r.midX, y: r.minY)); $0.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); $0.addLine(to: CGPoint(x: r.minX, y: r.maxY)); $0.closeSubpath() }
    }
}

private struct Timer03: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], frac = min(1, elapsed / Double(r.totalS))
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.title2.weight(.black)).foregroundStyle(B.ink).frame(width: 48, height: 48).block(B.bg)
                    Spacer()
                    Text("STEP \(index + 1)/\(r.steps.count)").font(B.futura(20)).foregroundStyle(B.ink)
                }
                ZStack(alignment: .bottomLeading) {
                    Rectangle().fill(B.blue).frame(width: 150, height: 150).offset(x: -20, y: 30)
                    Circle().fill(B.yellow).overlay(
                        Circle().trim(from: 0, to: frac).stroke(B.red, lineWidth: 150).rotationEffect(.degrees(-90)).padding(75)
                    ).overlay(Circle().strokeBorder(B.ink, lineWidth: 4))
                    .frame(width: 300, height: 300).frame(maxWidth: .infinity)
                    Text(Fmt.clock(Int(elapsed))).font(B.futura(84, .largeTitle)).monospacedDigit()
                        .foregroundStyle(B.ink).padding(.horizontal, 12).background(B.bg)
                        .overlay(Rectangle().strokeBorder(B.ink, lineWidth: 4))
                }
                .accessibilityElement(children: .combine)
                Text(step.kind.label.uppercased()).font(B.futura(48, .largeTitle)).foregroundStyle(B.red).padding(.top, 30)
                Text(step.instruction).font(.title3.weight(.semibold)).foregroundStyle(B.ink)
                Spacer()
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        Button(model.primaryTitle.uppercased()) { model.toggleTimer() }
                            .font(B.futura(24)).foregroundStyle(B.onColor)
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .lookGlass(B.blue, in: .rect, fallback: B.blue)
                            .background(B.ink.offset(x: 5, y: 5))
                        Button("DONE") { model.finishBrew() }
                            .font(B.futura(24)).foregroundStyle(Color(0x121212, 0x121212))
                            .frame(width: 120, height: 66)
                            .lookGlass(B.yellow, in: .rect, fallback: B.yellow)
                            .background(B.ink.offset(x: 5, y: 5))
                    }
                }
            }
            .padding(20)
            .background(B.bg)
        }
    }
}

private struct Log03: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("RATE IT").font(B.futura(52, .largeTitle)).foregroundStyle(B.ink)
                HStack(spacing: 16) {
                    big("DOSE", "\(Fmt.num(model.draft.doseG))g", B.red, B.onColor, $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                    big("WATER", "\(Fmt.num(model.draft.waterG))g", B.blue, B.onColor, $model.draft.waterG.stepped(by: 5, in: 10...1000))
                }
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: B.ink, size: 30)
                    .frame(maxWidth: .infinity).padding(.vertical, 6).block(B.yellow)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button(v.label.uppercased()) { model.draft.verdict = on ? nil : v }
                            .font(B.futura(15)).foregroundStyle(on ? B.onColor : B.ink)
                            .frame(maxWidth: .infinity, minHeight: 48).block(on ? B.red : B.bg)
                            .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Button("SAVE") { model.save() }.font(B.futura(28)).foregroundStyle(B.onColor)
                    .frame(maxWidth: .infinity, minHeight: 66).block(B.red)
            }
            .padding(20)
        }
        .background(B.bg)
    }

    private func big(_ k: String, _ v: String, _ fill: Color, _ fg: Color, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(k).font(B.futura(15))
            Text(v).font(B.futura(36, .title))
            HStack {
                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down)
                Spacer()
                Button("More \(k.lowercased())", systemImage: "plus", action: step.up)
            }
            .labelStyle(.iconOnly).font(.title.weight(.black)).frame(minHeight: 44)
        }
        .foregroundStyle(fg).padding(14).frame(maxWidth: .infinity).block(fill)
    }
}
