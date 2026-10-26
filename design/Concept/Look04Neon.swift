import SwiftUI

// 4. Neon Bar. A late-night espresso bar sign: glowing tubes on deep violet, condensed
// italic headings, LED-style digits. Controls are magenta-tinted glass that glows on press.
// Light mode is a daylit sign: pale lilac with the tubes turned off to solid ink colors.

private enum N {
    static let bg = Color(0xEEE8F7, 0x0B0614)
    static let panel = Color(0xFFFFFF, 0x160C26)
    static let ink = Color(0x1C0F33, 0xF4ECFF)
    static let ink2 = Color(0x56497A, 0xB3A6D6)
    static let pink = Color(0xB3126F, 0xFF4FB8)
    static let cyan = Color(0x006B85, 0x4FF0FF)
    static let onPink = Color(0xFFFFFF, 0x0B0614)
    static func head(_ size: CGFloat, _ style: Font.TextStyle = .title) -> Font {
        .custom("AvenirNextCondensed-HeavyItalic", size: size, relativeTo: style)
    }
}

private extension View {
    /// Glow only in dark mode; in light it would smear the text.
    func neon(_ color: Color, _ scheme: ColorScheme) -> some View {
        shadow(color: scheme == .dark ? color.opacity(0.9) : .clear, radius: 10)
            .shadow(color: scheme == .dark ? color.opacity(0.6) : .clear, radius: 2)
    }
}

struct Look04: View {
    var body: some View {
        ConceptShell(tint: N.pink) { LookRecipe(model: $0) } timer: { Timer04(model: $0) }
            log: { Log04(model: $0) } journal: { Journal04(model: $0) }
    }
}

private struct Journal04: View {
    let model: FlowModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("OPEN LATE").font(N.head(52, .largeTitle)).foregroundStyle(N.pink).neon(N.pink, scheme)
                Text("last \(model.journal.count) pulls").font(.system(.headline, design: .monospaced)).foregroundStyle(N.cyan)
                    .neon(N.cyan, scheme)
                ForEach(model.journal) { e in
                    let color = e.ratingHalfSteps >= 7 ? N.cyan : N.pink
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6).neon(color, scheme)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.bean.uppercased()).font(N.head(22, .headline)).foregroundStyle(N.ink)
                            Text("\(e.method) // 1:\(Fmt.num(e.ratio)) // \(Fmt.clock(e.timeS))")
                                .font(.system(.footnote, design: .monospaced)).foregroundStyle(N.ink2)
                        }
                        Spacer()
                        Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(color).neon(color, scheme)
                    }
                    .padding(14).frame(minHeight: 80)
                    .background(N.panel, in: .rect(cornerRadius: 14))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(20)
        }
        .background(N.bg)
    }
}

private struct Timer04: View {
    let model: FlowModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            VStack(spacing: 22) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.title3.weight(.bold)).foregroundStyle(N.ink).frame(width: 48, height: 48)
                        .lookGlass(nil, in: .circle, fallback: N.panel)
                    Spacer()
                    Text("NOW POURING").font(N.head(20)).foregroundStyle(N.cyan).neon(N.cyan, scheme)
                }
                Spacer()
                Text(Fmt.clock(Int(elapsed))).font(.system(size: 120, weight: .heavy, design: .monospaced))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(N.pink).neon(N.pink, scheme)
                HStack(spacing: 5) {
                    ForEach(r.steps) { s in
                        let lit = s.id <= index
                        Capsule().fill(lit ? N.cyan : N.ink2.opacity(0.25)).frame(height: 10)
                            .neon(lit ? N.cyan : .clear, scheme)
                    }
                }
                .accessibilityLabel("Step \(index + 1) of \(r.steps.count)")
                Text(step.kind.label.uppercased()).font(N.head(46, .largeTitle)).foregroundStyle(N.ink)
                Text(step.instruction).font(.title3).foregroundStyle(N.ink2).multilineTextAlignment(.center)
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle.uppercased()) { model.toggleTimer() }
                            .font(N.head(28)).foregroundStyle(N.onPink)
                            .frame(maxWidth: .infinity, minHeight: 68).lookGlass(N.pink, in: .capsule, fallback: N.pink)
                            .neon(N.pink, scheme)
                        Button("LAST CALL") { model.finishBrew() }
                            .font(N.head(22)).foregroundStyle(N.cyan)
                            .frame(width: 140, height: 68).lookGlass(nil, in: .capsule, fallback: N.panel)
                    }
                }
            }
            .padding(20)
            .background(N.bg)
        }
    }
}

private struct Log04: View {
    @Bindable var model: FlowModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("RATE THE PULL").font(N.head(44, .largeTitle)).foregroundStyle(N.pink).neon(N.pink, scheme)
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: N.cyan, size: 32).neon(N.cyan, scheme)
                ForEach([("DOSE", "g", \BrewDraft.doseG, 0.5, 1.0...100), ("WATER", "g", \.waterG, 5, 10...1000), ("TEMP", "°C", \.tempC, 1, 50...100)],
                        id: \.0) { k, unit, path, by, range in
                    let step = Binding(get: { model.draft[keyPath: path] }, set: { model.draft[keyPath: path] = $0 }).stepped(by: by, in: range)
                    HStack {
                        Text(k).font(N.head(22)).foregroundStyle(N.ink2).frame(width: 90, alignment: .leading)
                        Text("\(Fmt.num(model.draft[keyPath: path])) \(unit)").font(.system(.title, design: .monospaced, weight: .bold))
                            .foregroundStyle(N.ink)
                        Spacer()
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down)
                                    .frame(width: 50, height: 50).lookGlass(nil, in: .circle, fallback: N.panel)
                                Button("More \(k.lowercased())", systemImage: "plus", action: step.up)
                                    .frame(width: 50, height: 50).lookGlass(N.cyan.opacity(0.5), in: .circle, fallback: N.panel)
                            }
                            .labelStyle(.iconOnly).font(.title3.weight(.bold)).foregroundStyle(N.ink)
                        }
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label.uppercased()) { model.draft.verdict = on ? nil : v }
                                .font(N.head(18)).foregroundStyle(on ? N.onPink : N.ink)
                                .padding(.horizontal, 14).frame(minHeight: 46)
                                .background(on ? N.pink : N.panel, in: .capsule)
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Button("SAVE THE PULL") { model.save() }.font(N.head(28)).foregroundStyle(N.onPink)
                    .frame(maxWidth: .infinity, minHeight: 66).lookGlass(N.pink, in: .capsule, fallback: N.pink)
            }
            .padding(20)
        }
        .background(N.bg)
    }
}
