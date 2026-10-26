import SwiftUI

// 1. Glass Lab. Liquid Glass as the hero: a slow coffee-coloured mesh behind everything,
// controls float on glass and morph inside one container. Reading surfaces sit on thick
// material, not glass (ui-ux-pro-max: no glass on dense content).

private enum G {
    static let a = Color(0xF3D9B8, 0x2A160C)
    static let b = Color(0xD99A6C, 0x5B2D14)
    static let c = Color(0xF7EEE3, 0x120A06)
    static let d = Color(0xB5643A, 0x8A4A22)
    static let ink = Color(0x24140B, 0xFBF1E6)
    static let ink2 = Color(0x5E4636, 0xD9C3AF)
    static let accent = Color(0x8C3F12, 0xF2A65E)
    static let onAccent = Color(0xFFFFFF, 0x1A0D05)
}

private struct Mesh: View {
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.6, 0.45], [1, 0.5], [0, 1], [0.5, 1], [1, 1],
        ], colors: [G.a, G.c, G.b, G.c, G.a, G.d, G.b, G.c, G.a])
        .ignoresSafeArea()
    }
}

struct Look01: View {
    var body: some View {
        ConceptShell(tint: G.accent) { LookRecipe(model: $0) } timer: { Timer01(model: $0) }
            log: { Log01(model: $0) } journal: { Journal01(model: $0) }
    }
}

private struct Journal01: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your cups").font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(G.ink)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(["All", "Cone", "Press", "Espresso"], id: \.self) { f in
                            Text(f).font(.subheadline.weight(.semibold)).foregroundStyle(f == "All" ? G.onAccent : G.ink)
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .lookGlass(f == "All" ? G.accent : nil, in: .capsule, fallback: G.c)
                        }
                    }
                }
                ForEach(model.journal) { e in
                    HStack(alignment: .top, spacing: 14) {
                        Text(Fmt.num(Double(e.ratingHalfSteps) / 2))
                            .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(G.accent)
                            .frame(width: 56, height: 56).background(G.accent.opacity(0.12), in: .circle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.bean).font(.headline).foregroundStyle(G.ink)
                            Text("\(e.method) · 1:\(Fmt.num(e.ratio)) · \(Fmt.clock(e.timeS))")
                                .font(.subheadline).foregroundStyle(G.ink2)
                            Text(e.note).font(.footnote).foregroundStyle(G.ink2).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(.thickMaterial, in: .rect(cornerRadius: 28))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Mesh())
        .toolbar { Button("Brew", systemImage: "plus") { model.tab = .recipes; model.showTimer = true } }
    }
}

private struct Timer01: View {
    let model: FlowModel
    @Namespace private var ns

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], next = model.nextStep(after: index)
            VStack(spacing: 24) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }
                        .labelStyle(.iconOnly).font(.title3).foregroundStyle(G.ink)
                        .frame(width: 48, height: 48).lookGlass(nil, in: .circle, fallback: G.c)
                    Spacer()
                    Text(r.method).font(.headline).foregroundStyle(G.ink)
                        .padding(.horizontal, 16).frame(minHeight: 44).lookGlass(nil, in: .capsule, fallback: G.c)
                }
                Spacer()
                ZStack {
                    Circle().trim(from: 0, to: min(1, elapsed / Double(r.totalS)))
                        .stroke(G.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90)).padding(10)
                    VStack(spacing: 6) {
                        Text(Fmt.clock(Int(elapsed))).font(.system(size: 76, weight: .semibold, design: .rounded))
                            .monospacedDigit().foregroundStyle(G.ink)
                        Text(step.cumulativeG.map { "to \($0) g" } ?? step.kind.label)
                            .font(.title2.weight(.semibold)).foregroundStyle(G.accent)
                    }
                }
                .frame(width: 290, height: 290)
                .lookGlass(nil, in: .circle, fallback: G.c)
                .onTapGesture { model.toggleTimer() }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                VStack(spacing: 6) {
                    Text(step.instruction).font(.title3).foregroundStyle(G.ink).multilineTextAlignment(.center)
                    if let next {
                        Text("Next: \(next.kind.label) in \(Fmt.clock(next.startS - Int(elapsed)))")
                            .font(.subheadline.weight(.medium)).foregroundStyle(G.ink2)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Reset", systemImage: "arrow.counterclockwise") { model.resetTimer() }
                            .labelStyle(.iconOnly).font(.title2).foregroundStyle(G.ink)
                            .frame(width: 64, height: 64).lookGlass(nil, in: .circle, fallback: G.c)
                            .glassEffectID("reset", in: ns)
                        Button(model.primaryTitle) { model.toggleTimer() }
                            .font(.title2.weight(.bold)).foregroundStyle(G.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .lookGlass(G.accent, in: .capsule, fallback: G.accent)
                            .glassEffectID("primary", in: ns)
                        Button("Done", systemImage: "checkmark") { model.finishBrew() }
                            .labelStyle(.iconOnly).font(.title2).foregroundStyle(G.ink)
                            .frame(width: 64, height: 64).lookGlass(nil, in: .circle, fallback: G.c)
                            .glassEffectID("done", in: ns)
                    }
                }
            }
            .padding(20)
        }
        .background(Mesh())
    }
}

private struct Log01: View {
    @Bindable var model: FlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How was it?").font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(G.ink)
                Text(model.draft.bean).font(.title3.weight(.semibold)).foregroundStyle(G.ink2)
                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: G.accent, size: 30)
                    .padding(.vertical, 6).frame(maxWidth: .infinity)
                    .background(.thickMaterial, in: .rect(cornerRadius: 24))
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        value("Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        value("Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        value("Temp", "\(Fmt.num(model.draft.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                }
                Text("Taste").font(.headline).foregroundStyle(G.ink)
                FlowChips(selection: $model.draft.verdict)
                Button("Save cup") { model.save() }
                    .font(.title3.weight(.bold)).foregroundStyle(G.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 60).lookGlass(G.accent, in: .capsule, fallback: G.accent)
            }
            .padding(20)
        }
        .background(Mesh())
    }

    private func value(_ label: String, _ text: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Button("Less \(label)", systemImage: "minus", action: step.down).labelStyle(.iconOnly)
                .frame(width: 52, height: 52).lookGlass(nil, in: .circle, fallback: G.c)
            Spacer()
            VStack {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(G.ink2)
                Text(text).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(G.ink)
            }
            Spacer()
            Button("More \(label)", systemImage: "plus", action: step.up).labelStyle(.iconOnly)
                .frame(width: 52, height: 52).lookGlass(nil, in: .circle, fallback: G.c)
        }
        .foregroundStyle(G.ink).padding(8)
        .lookGlass(nil, in: .capsule, fallback: G.c)
        .accessibilityElement(children: .contain)
    }

    private struct FlowChips: View {
        @Binding var selection: Verdict?
        var body: some View {
            ScrollView(.horizontal) {
              GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Verdict.allCases) { v in
                        Button(v.label) { selection = selection == v ? nil : v }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection == v ? G.onAccent : G.ink)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .lookGlass(selection == v ? G.accent : nil, in: .capsule, fallback: G.c)
                            .accessibilityAddTraits(selection == v ? .isSelected : [])
                    }
                }
              }
            }
            .scrollIndicators(.hidden)
        }
    }
}
