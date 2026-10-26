import SwiftUI

// 5. Field Notes. Anti-polish: a ruled notebook in blue ink, Noteworthy handwriting, tape
// strips and a drawn carafe that fills as you pour. Glass is clear, like a loupe laid on the page.

private enum F {
    static let page = Color(0xFBF7EC, 0x1D2026)
    static let rule = Color(0xBCD3E8, 0x2E3A4A)
    static let margin = Color(0xE7A3A3, 0x6B3B3B)
    static let ink = Color(0x1D3A8A, 0xC9D8FF)
    static let pencil = Color(0x4F4A40, 0xA9A396)
    static let tape = Color(0xF1E3A6, 0x5A5236)
    static let marker = Color(0xB4321E, 0xFF8C70)
    static let onMarker = Color(0xFFFFFF, 0x1D2026)
    static func hand(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font {
        .custom("Noteworthy-Bold", size: size, relativeTo: style)
    }
}

/// Notebook paper: blue rules every 32 pt and a red margin line.
private struct Paper: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 32
            while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(F.rule)); y += 32 }
            ctx.fill(Path(CGRect(x: 44, y: 0, width: 1.5, height: size.height)), with: .color(F.margin))
        }
        .background(F.page)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct Look05: View {
    var body: some View {
        ConceptShell(tint: F.ink) { LookRecipe(model: $0) } timer: { Timer05(model: $0) }
            log: { Log05(model: $0) } journal: { Journal05(model: $0) }
    }
}

private struct Journal05: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Coffee notebook").font(F.hand(40, .largeTitle)).foregroundStyle(F.ink)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(Fmt.day(e.date)).font(F.hand(15)).foregroundStyle(F.pencil)
                            Spacer()
                            Text(String(repeating: "✶", count: e.ratingHalfSteps / 2)).font(.title3).foregroundStyle(F.marker)
                                .accessibilityLabel(Fmt.stars(e.ratingHalfSteps))
                        }
                        Text(e.bean).font(F.hand(24, .title2)).foregroundStyle(F.ink)
                            .underline(e.ratingHalfSteps >= 8, color: F.marker)
                        Text("\(Fmt.num(e.doseG))g in, \(Fmt.num(e.waterG))g water, \(Fmt.clock(e.timeS)) on the \(e.method.lowercased())")
                            .font(F.hand(16)).foregroundStyle(F.pencil)
                        Text("“\(e.note)”").font(F.hand(17)).foregroundStyle(F.ink)
                    }
                    .padding(.leading, 40).padding(.trailing, 8)
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? -0.6 : 0.5))
                    .overlay(alignment: .topTrailing) {
                        if i == 0 { Rectangle().fill(F.tape.opacity(0.85)).frame(width: 80, height: 24).rotationEffect(.degrees(12)).offset(x: 6, y: -14) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .background(Paper())
    }
}

/// A carafe outline drawn with a slight wobble, filled to the current target.
private struct Carafe: View {
    let level: Double
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { g in
                Rectangle().fill(F.ink.opacity(0.25))
                    .frame(height: g.size.height * level).frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 46, bottomTrailingRadius: 50, topTrailingRadius: 26))
            UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 46, bottomTrailingRadius: 50, topTrailingRadius: 26)
                .stroke(F.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [40, 2, 60, 3]))
        }
        .accessibilityHidden(true)
    }
}

private struct Timer05: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            let target = Double(r.steps[...index].compactMap(\.cumulativeG).last ?? 0)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("close") { model.showTimer = false }.font(F.hand(20)).foregroundStyle(F.ink)
                        .padding(.horizontal, 16).frame(minHeight: 44).lookGlass(nil, in: .capsule, fallback: F.page, clear: true)
                    Spacer()
                }
                Text("pour no. \(index + 1)").font(F.hand(22)).foregroundStyle(F.pencil).padding(.leading, 40)
                Text(Fmt.clock(Int(elapsed))).font(F.hand(96, .largeTitle)).monospacedDigit().foregroundStyle(F.ink)
                    .padding(.leading, 36)
                HStack(alignment: .bottom, spacing: 18) {
                    Carafe(level: target / r.waterG).frame(width: 150, height: 210)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.cumulativeG.map { "to \($0) g" } ?? step.kind.label.lowercased())
                            .font(F.hand(34, .title)).foregroundStyle(F.marker)
                        Text(step.instruction).font(F.hand(19)).foregroundStyle(F.ink)
                        if let next = model.nextStep(after: index) {
                            Text("then \(next.kind.label.lowercased()) at \(Fmt.clock(next.startS))").font(F.hand(16)).foregroundStyle(F.pencil)
                        }
                    }
                }
                .padding(.leading, 40).padding(.top, 10)
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle.lowercased()) { model.toggleTimer() }
                            .font(F.hand(28)).foregroundStyle(F.onMarker)
                            .frame(maxWidth: .infinity, minHeight: 64).lookGlass(F.marker, in: .capsule, fallback: F.marker)
                        Button("write it up") { model.finishBrew() }
                            .font(F.hand(22)).foregroundStyle(F.ink)
                            .frame(maxWidth: .infinity, minHeight: 64).lookGlass(nil, in: .capsule, fallback: F.page, clear: true)
                    }
                }
            }
            .padding(16)
            .background(Paper())
        }
    }
}

private struct Log05: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tasting notes").font(F.hand(36, .largeTitle)).foregroundStyle(F.ink)
                Text(model.draft.bean).font(F.hand(22)).foregroundStyle(F.pencil)
                line("dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                line("water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                line("temp", "\(Fmt.num(model.draft.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                Text("it tasted…").font(F.hand(20)).foregroundStyle(F.pencil)
                FlowLayout {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button(v.label.lowercased()) { model.draft.verdict = on ? nil : v }
                            .font(F.hand(22)).foregroundStyle(on ? F.marker : F.ink)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .overlay { if on { Ellipse().stroke(F.marker, lineWidth: 2.5).padding(-2) } }
                            .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: F.marker, size: 28)
                TextField("notes…", text: $model.draft.notes, axis: .vertical).font(F.hand(20)).foregroundStyle(F.ink)
                    .lineLimit(3...6)
                Button("save to notebook") { model.save() }.font(F.hand(26)).foregroundStyle(F.onMarker)
                    .frame(maxWidth: .infinity, minHeight: 62).lookGlass(F.marker, in: .capsule, fallback: F.marker)
            }
            .padding(.leading, 56).padding(.trailing, 16).padding(.top, 20)
        }
        .background(Paper())
    }

    private func line(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Text("\(k):").font(F.hand(20)).foregroundStyle(F.pencil).frame(width: 70, alignment: .leading)
            Text(v).font(F.hand(28, .title2)).foregroundStyle(F.ink)
            Spacer()
            Button("Less \(k)", systemImage: "minus.circle", action: step.down)
            Button("More \(k)", systemImage: "plus.circle", action: step.up)
        }
        .labelStyle(.iconOnly).font(.title).foregroundStyle(F.ink).frame(minHeight: 44)
    }
}

/// Wraps chips onto new lines; the iOS layout protocol, no third-party flow layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing; row = max(row, s.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; row = max(row, s.height)
        }
    }
}
