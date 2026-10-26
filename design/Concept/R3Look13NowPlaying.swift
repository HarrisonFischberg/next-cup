import SwiftUI

// 13. Now Playing (Apple Music). Organizing idea: a brew is a track and each bean is an album.
// Home is a shelf of bean "covers" (colour from origin) above recent plays. The timer is the
// Now Playing screen: big cover, a scrubber with step chapters, glass transport controls.

private enum P {
    static let accent = Color(0xC2412D, 0xFF6B57)
}

/// A bean bag rendered as album art: origin colour, a soft sheen, big type. No image assets.
private struct Cover: View {
    let bean: String
    var size: CGFloat
    var body: some View {
        let c = BeanArt.color(bean)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [c, c.mix(with: .black, by: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: size * 0.9).offset(x: size * 0.45, y: -size * 0.55)
            VStack(alignment: .leading, spacing: 0) {
                Text(BeanArt.origin(bean)).font(.system(size: size * 0.16, weight: .heavy))
                Text(bean.split(separator: " ").dropFirst().joined(separator: " ")).font(.system(size: size * 0.08, weight: .semibold)).opacity(0.8)
            }
            .foregroundStyle(.white).padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.06, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct Look13: View {
    var body: some View {
        ConceptShell(tint: P.accent) { LookRecipe(model: $0) } timer: { Timer13(model: $0) }
            log: { Log13(model: $0) } journal: { Shelf13(model: $0) }
    }
}

private struct Shelf13: View {
    let model: FlowModel
    var body: some View {
        let beans = Array(Set(model.journal.map(\.bean))).sorted()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your beans").font(.title2.weight(.bold)).padding(.horizontal, 20)
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(Array(beans.enumerated()), id: \.element) { i, b in
                            VStack(alignment: .leading, spacing: 6) {
                                Cover(bean: b, size: 160).shadow(color: BeanArt.color(b).opacity(0.35), radius: 14, y: 8)
                                Text(b).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text("\(model.journal.filter { $0.bean == b }.count) brews").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(width: 160).assemble(i)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                Text("Recently brewed").font(.title2.weight(.bold)).padding(.horizontal, 20).padding(.top, 10)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        Cover(bean: e.bean, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.method).font(.body)
                            Text("\(e.bean) · \(Fmt.clock(e.timeS))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "ellipsis").foregroundStyle(.secondary).frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Brew")
    }
}

private struct Timer13: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], bean = "Kenya Kiambu AA"
            VStack(spacing: 0) {
                Capsule().fill(.white.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 8)
                    .onTapGesture { model.showTimer = false }.accessibilityLabel("Close").accessibilityAddTraits(.isButton)
                Spacer()
                Cover(bean: bean, size: 320).shadow(color: .black.opacity(0.35), radius: 30, y: 18)
                    .scaleEffect(model.showsRunning ? 1 : 0.86)
                    .animation(.spring(duration: 0.42, bounce: 0.16), value: model.showsRunning)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.kind.label + (step.cumulativeG.map { " to \($0) g" } ?? "")).font(.title2.weight(.bold))
                    Text(step.instruction).font(.title3).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Scrubber with a tick at each step change, like chapters.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25)).frame(height: 6)
                        Capsule().fill(.white).frame(width: g.size.width * min(1, elapsed / Double(r.totalS)), height: 6)
                        ForEach(r.steps.dropFirst()) { s in
                            Rectangle().fill(.black.opacity(0.4)).frame(width: 2, height: 6).offset(x: g.size.width * Double(s.startS) / Double(r.totalS))
                        }
                    }
                }
                .frame(height: 6).padding(.top, 20).accessibilityHidden(true)
                HStack {
                    Text(Fmt.clock(Int(elapsed))).monospacedDigit().contentTransition(.numericText())
                    Spacer()
                    Text("-" + Fmt.clock(r.totalS - Int(elapsed))).monospacedDigit()
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7)).padding(.top, 8)
                GlassEffectContainer(spacing: 40) {
                    HStack(spacing: 40) {
                        Button("Restart", systemImage: "backward.fill") { model.resetTimer() }.font(.title)
                            .frame(width: 64, height: 64).glassEffect(.clear.interactive(), in: .circle)
                        Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                            .font(.system(size: 40)).contentTransition(.symbolEffect(.replace))
                            .frame(width: 88, height: 88).glassEffect(.regular.interactive(), in: .circle)
                        Button("Finish", systemImage: "forward.end.fill") { model.finishBrew() }.font(.title)
                            .frame(width: 64, height: 64).glassEffect(.clear.interactive(), in: .circle)
                    }
                    .labelStyle(.iconOnly).foregroundStyle(.white)
                }
                .padding(.vertical, 28)
            }
            .padding(.horizontal, 28)
            .foregroundStyle(.white)
            .background {
                // The cover's colour, blurred, as the backdrop (Music's ambient background).
                ZStack { Color.black; Cover(bean: bean, size: 900).blur(radius: 90).opacity(0.85) }.ignoresSafeArea()
            }
        }
    }
}

private struct Log13: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Cover(bean: model.draft.bean, size: 88)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.draft.bean).font(.headline)
                            Text("\(model.recipe.method) · \(Fmt.clock(model.draft.timeS))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: P.accent, size: 28).frame(maxWidth: .infinity)
                }
                Section("Taste") {
                    ForEach(Verdict.allCases) { v in
                        Button { model.draft.verdict = model.draft.verdict == v ? nil : v } label: {
                            HStack {
                                Text(v.label).foregroundStyle(.primary)
                                Spacer()
                                if model.draft.verdict == v { Image(systemName: "checkmark").foregroundStyle(P.accent) }
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(model.draft.verdict == v ? .isSelected : [])
                    }
                }
                Section("Measured") {
                    Stepper("Dose  \(Fmt.num(model.draft.doseG)) g", value: $model.draft.doseG, in: 1...100, step: 0.5).monospacedDigit()
                    Stepper("Water  \(Fmt.num(model.draft.waterG)) g", value: $model.draft.waterG, in: 10...1000, step: 5).monospacedDigit()
                }
            }
            .navigationTitle("Rate this brew").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Add to Journal") { model.save() }.buttonStyle(.glassProminent).tint(P.accent) }
            }
        }
    }
}
