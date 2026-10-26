import SwiftUI

// 10. Hardware. A pocket synth-style brewing device: grey enclosure, a recessed LCD,
// an orange rotary dial that tracks the brew, chunky keys. The keys are glass with an
// orange or grey tint so they press like real caps.

private enum H {
    static let body = Color(0xD8D8D3, 0x2B2B2B)
    static let panel = Color(0xC9C9C3, 0x222222)
    static let lcd = Color(0xB7C4A6, 0x0F1A12)
    static let lcdInk = Color(0x1E2A16, 0x8CFF9E)
    static let ink = Color(0x161616, 0xEDEDED)
    static let ink2 = Color(0x4C4C48, 0xA2A29C)
    static let orange = Color(0xFF5A1F, 0xFF6A2F)
    static let onOrange = Color(0x161616, 0x161616)
    static func lcdFont(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .default).width(.expanded) }
}

private struct LCD<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .foregroundStyle(H.lcdInk).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(H.lcd, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.35), lineWidth: 3).blur(radius: 1.5).clipShape(.rect(cornerRadius: 8)))
            .padding(6).background(H.panel, in: .rect(cornerRadius: 12))
    }
}

/// The rotary dial: 36 ticks, the done ones lit orange, and a pointer at now.
private struct Dial: View {
    let fraction: Double
    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { i in
                Capsule().fill(Double(i) / 36 <= fraction ? H.orange : H.ink2.opacity(0.4))
                    .frame(width: 3, height: i % 3 == 0 ? 16 : 9).offset(y: -128).rotationEffect(.degrees(Double(i) * 10))
            }
            Circle().fill(H.orange).frame(width: 190)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2).padding(4))
            Capsule().fill(H.onOrange).frame(width: 8, height: 46).offset(y: -62).rotationEffect(.degrees(fraction * 360))
        }
        .frame(width: 270, height: 270)
        .accessibilityHidden(true)
    }
}

struct Look10: View {
    var body: some View {
        ConceptShell(tint: H.orange) { LookRecipe(model: $0) } timer: { Timer10(model: $0) }
            log: { Log10(model: $0) } journal: { Journal10(model: $0) }
    }
}

private struct Journal10: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("NC-1").font(H.label(30)).foregroundStyle(H.ink)
                    Spacer()
                    Circle().fill(H.orange).frame(width: 14).accessibilityHidden(true)
                    Text("MEMORY").font(H.label(13)).foregroundStyle(H.ink2)
                }
                LCD {
                    Text("PATCH  BEAN            RT").font(H.lcdFont(12)).opacity(0.7)
                    ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                        Text(String(format: "%02d", i + 1) + "  " + e.bean.uppercased().padding(toLength: 18, withPad: " ", startingAt: 0) + " " + Fmt.num(Double(e.ratingHalfSteps) / 2))
                            .font(H.lcdFont(15)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(model.journal.prefix(4)) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.method.uppercased()).font(H.label(11)).foregroundStyle(H.ink2)
                            Text(e.bean).font(.headline).foregroundStyle(H.ink).lineLimit(1)
                            HStack {
                                Text("1:\(Fmt.num(e.ratio))").font(H.lcdFont(15)).foregroundStyle(H.ink)
                                Spacer()
                                Text(Fmt.clock(e.timeS)).font(H.lcdFont(15)).foregroundStyle(H.orange)
                            }
                        }
                        .padding(12).background(H.panel, in: .rect(cornerRadius: 14))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(18)
        }
        .background(H.body)
    }
}

private struct Timer10: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            VStack(spacing: 18) {
                HStack {
                    Button("Close", systemImage: "power") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.title3.weight(.bold)).foregroundStyle(H.ink).frame(width: 48, height: 48)
                        .lookGlass(nil, in: .circle, fallback: H.panel)
                    Spacer()
                    Text("NC-1 · BREW").font(H.label(16)).foregroundStyle(H.ink)
                }
                LCD {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.clock(Int(elapsed))).font(H.lcdFont(58)).monospacedDigit()
                        Spacer()
                        Text(step.cumulativeG.map { "\($0)G" } ?? "--").font(H.lcdFont(28))
                    }
                    Text("STEP \(index + 1)/\(r.steps.count) \(step.kind.label.uppercased())").font(H.lcdFont(16))
                    Text(step.instruction.uppercased()).font(H.lcdFont(12)).opacity(0.8)
                }
                Dial(fraction: min(1, elapsed / Double(r.totalS)))
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        key(model.primaryTitle.uppercased(), H.orange, H.onOrange) { model.toggleTimer() }
                        key("RESET", nil, H.ink) { model.resetTimer() }
                        key("REC", nil, H.ink) { model.finishBrew() }
                    }
                }
            }
            .padding(18)
            .background(H.body)
        }
    }

    private func key(_ t: String, _ tint: Color?, _ fg: Color, action: @escaping () -> Void) -> some View {
        Button(t, action: action).font(H.label(17)).foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 72)
            .lookGlass(tint, in: .rect(cornerRadius: 14), fallback: tint ?? H.panel)
    }
}

private struct Log10: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SAVE PATCH").font(H.label(28)).foregroundStyle(H.ink)
                LCD {
                    Text(model.draft.bean.uppercased()).font(H.lcdFont(17))
                    Text("DOSE \(Fmt.num(model.draft.doseG))G  H2O \(Fmt.num(model.draft.waterG))G  \(Fmt.num(model.draft.tempC))C").font(H.lcdFont(14))
                    Text("TASTE \(model.draft.verdict?.label.uppercased() ?? "----")  RATE \(Fmt.stars(model.draft.ratingHalfSteps).uppercased())").font(H.lcdFont(14))
                }
                HStack(spacing: 12) {
                    knob("DOSE", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                    knob("WATER", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                    knob("TEMP", $model.draft.tempC.stepped(by: 1, in: 50...100))
                }
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: H.orange).frame(maxWidth: .infinity)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button(String(v.label.prefix(3)).uppercased()) { model.draft.verdict = on ? nil : v }
                            .font(H.label(13)).foregroundStyle(on ? H.onOrange : H.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(on ? H.orange : H.panel, in: .rect(cornerRadius: 10))
                            .accessibilityLabel(v.label).accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Button("WRITE") { model.save() }.font(H.label(22)).foregroundStyle(H.onOrange)
                    .frame(maxWidth: .infinity, minHeight: 66).lookGlass(H.orange, in: .rect(cornerRadius: 14), fallback: H.orange)
            }
            .padding(18)
        }
        .background(H.body)
    }

    private func knob(_ k: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(spacing: 8) {
            Text(k).font(H.label(11)).foregroundStyle(H.ink2)
            HStack(spacing: 6) {
                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down).frame(width: 44, height: 44)
                Button("More \(k.lowercased())", systemImage: "plus", action: step.up).frame(width: 44, height: 44)
            }
            .labelStyle(.iconOnly).font(.headline.weight(.black)).foregroundStyle(H.ink)
        }
        .padding(10).frame(maxWidth: .infinity).background(H.panel, in: .rect(cornerRadius: 14))
    }
}
