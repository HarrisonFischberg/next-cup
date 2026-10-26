import SwiftUI

// 8. Clay. Claymorphism: soft, puffy, toy-like pastels with inner and outer shadows and a
// chunky rounded face. The timer is a big clay mug that fills as you pour. Glass buttons
// take a pastel tint so they read as sugar glass on the clay.

private enum C {
    static let bg = Color(0xFCE9DD, 0x2A1F33)
    static let card = Color(0xFFF6EF, 0x3A2C46)
    static let ink = Color(0x3D2230, 0xFBEFF6)
    static let ink2 = Color(0x7A5566, 0xCDB6CB)
    static let peach = Color(0xE9805C, 0xFFAE8F)
    static let mint = Color(0x3E8F72, 0x8FE3C4)
    static let lilac = Color(0x8A6BC7, 0xC7B1FF)
    static let coffee = Color(0x8A4A2B, 0xC98A63)
    static let onPeach = Color(0x3D2230, 0x2A1F33)
    static func chunky(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

private extension View {
    /// The clay puff: a light highlight top-left, a soft shadow bottom-right.
    func clay(_ fill: Color, radius: CGFloat = 30) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                .shadow(color: .white.opacity(0.6), radius: 6, x: -5, y: -5)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 8, y: 10)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 2).blur(radius: 1).offset(x: 1, y: 1))
        )
    }
}

struct Look08: View {
    var body: some View {
        ConceptShell(tint: C.peach) { LookRecipe(model: $0) } timer: { Timer08(model: $0) }
            log: { Log08(model: $0) } journal: { Journal08(model: $0) }
    }
}

private struct Journal08: View {
    let model: FlowModel
    private let blobs = [C.peach, C.mint, C.lilac]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Cups!").font(C.chunky(48, .largeTitle)).foregroundStyle(C.ink)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 16) {
                        Image(systemName: "cup.and.saucer.fill").font(.system(size: 28)).foregroundStyle(.white)
                            .frame(width: 64, height: 64).clay(blobs[i % 3], radius: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.bean).font(C.chunky(19, .headline)).foregroundStyle(C.ink)
                            Text("\(e.method) · \(Fmt.clock(e.timeS))").font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(C.ink2)
                        }
                        Spacer()
                        Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(C.chunky(26)).foregroundStyle(C.ink)
                            .frame(width: 56, height: 56).clay(C.bg, radius: 28)
                    }
                    .padding(16).clay(C.card)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(22)
        }
        .background(C.bg)
    }
}

/// A clay mug: body, handle, and coffee rising to the current target.
private struct Mug: View {
    let level: Double
    let label: String
    var body: some View {
        HStack(spacing: -14) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 46, style: .continuous).fill(C.card)
                RoundedRectangle(cornerRadius: 40, style: .continuous).fill(C.coffee)
                    .frame(height: max(30, 230 * level)).padding(12)
                Text(label).font(C.chunky(64, .largeTitle)).monospacedDigit().foregroundStyle(C.ink)
                    .frame(maxHeight: .infinity).shadow(color: C.card, radius: 6)
            }
            .frame(width: 220, height: 260).clay(.clear, radius: 46)
            Circle().stroke(C.card, lineWidth: 26).frame(width: 90, height: 100)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 6, y: 8).zIndex(-1)
        }
    }
}

private struct Timer08: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index]
            let target = Double(r.steps[...index].compactMap(\.cumulativeG).last ?? 0)
            VStack(spacing: 22) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.title3.weight(.black)).foregroundStyle(C.ink).frame(width: 54, height: 54).clay(C.card, radius: 27)
                    Spacer()
                    Text("Step \(index + 1) of \(r.steps.count)").font(C.chunky(18)).foregroundStyle(C.ink2)
                }
                Spacer()
                Mug(level: target / r.waterG, label: Fmt.clock(Int(elapsed)))
                    .accessibilityElement().accessibilityLabel("\(Fmt.clock(Int(elapsed))) elapsed, \(Int(target)) of \(Int(r.waterG)) grams")
                Text(step.cumulativeG.map { "Pour to \($0) g" } ?? step.kind.label).font(C.chunky(30, .title)).foregroundStyle(C.peach)
                Text(step.instruction).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(C.ink2)
                    .multilineTextAlignment(.center)
                Spacer()
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        Button(model.primaryTitle) { model.toggleTimer() }.font(C.chunky(26)).foregroundStyle(C.onPeach)
                            .frame(maxWidth: .infinity, minHeight: 72).lookGlass(C.peach, in: .rect(cornerRadius: 36), fallback: C.peach)
                        Button("Done", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly)
                            .font(.title.weight(.black)).foregroundStyle(C.onPeach)
                            .frame(width: 72, height: 72).lookGlass(C.mint, in: .circle, fallback: C.mint)
                    }
                }
            }
            .padding(22)
            .background(C.bg)
        }
    }
}

private struct Log08: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Yum or yuck?").font(C.chunky(38, .largeTitle)).foregroundStyle(C.ink)
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.peach, size: 30)
                    .frame(maxWidth: .infinity).padding(10).clay(C.card)
                FlowLayout(spacing: 12) {
                    ForEach(Array(Verdict.allCases.enumerated()), id: \.element) { i, v in
                        let on = model.draft.verdict == v
                        Button(v.label) { model.draft.verdict = on ? nil : v }
                            .font(C.chunky(18)).foregroundStyle(on ? C.onPeach : C.ink)
                            .padding(.horizontal, 18).frame(minHeight: 52)
                            .clay(on ? [C.peach, C.mint, C.lilac][i % 3] : C.card, radius: 26)
                            .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                HStack(spacing: 16) {
                    puff("Dose", "\(Fmt.num(model.draft.doseG))g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                    puff("Water", "\(Fmt.num(model.draft.waterG))g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                }
                Button("Save it!") { model.save() }.font(C.chunky(26)).foregroundStyle(C.onPeach)
                    .frame(maxWidth: .infinity, minHeight: 70).lookGlass(C.peach, in: .rect(cornerRadius: 35), fallback: C.peach)
            }
            .padding(22)
        }
        .background(C.bg)
    }

    private func puff(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(spacing: 10) {
            Text(k).font(C.chunky(15)).foregroundStyle(C.ink2)
            Text(v).font(C.chunky(32)).foregroundStyle(C.ink)
            HStack(spacing: 12) {
                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down).frame(width: 48, height: 48).clay(C.bg, radius: 24)
                Button("More \(k.lowercased())", systemImage: "plus", action: step.up).frame(width: 48, height: 48).clay(C.bg, radius: 24)
            }
            .labelStyle(.iconOnly).font(.title3.weight(.black)).foregroundStyle(C.ink)
        }
        .padding(16).frame(maxWidth: .infinity).clay(C.card)
    }
}
