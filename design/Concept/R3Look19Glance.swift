import SwiftUI

// 19. Glance (Granola / Live Activities). Organizing idea: you shouldn't have to look at the app
// while brewing. Home is one big "Brew" control above a notification-style stack of recent cups.
// The timer is the Live Activity, blown up: an island pill on top and a lock-screen card.

private enum G {
    static let accent = Color(0xC4622D, 0xFF9A5C)
}

struct Look19: View {
    var body: some View {
        ConceptShell(tint: G.accent) { LookRecipe(model: $0) } timer: { Timer19(model: $0) }
            log: { Log19(model: $0) } journal: { Home19(model: $0) }
    }
}

private struct Home19: View {
    let model: FlowModel
    @State private var fanned = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Good morning").font(.title3.weight(.medium)).foregroundStyle(.secondary)
            Text("Ready for cup two?").font(.largeTitle.weight(.bold)).padding(.top, 2)
            Button { model.tab = .recipes; model.showTimer = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 44))
                    Text("Brew").font(.title3.weight(.semibold))
                    Text("Cone dripper · 3:00").font(.footnote).opacity(0.8)
                }
                .foregroundStyle(.white).frame(width: 190, height: 190)
                .glassEffect(.regular.tint(G.accent).interactive(), in: .circle)
            }
            .buttonStyle(PressScale(scale: 0.94)).padding(.vertical, 36)
            Spacer()
            // Recent cups as a stacked notification group; tap to fan out.
            ZStack(alignment: .top) {
                ForEach(Array(model.journal.prefix(3).enumerated()).reversed(), id: \.element.id) { i, e in
                    HStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer.fill").foregroundStyle(.white).frame(width: 38, height: 38)
                            .background(BeanArt.color(e.bean), in: .rect(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(e.bean).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(e.date, format: .dateTime.weekday(.abbreviated)).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(e.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
                    .scaleEffect(fanned ? 1 : 1 - CGFloat(i) * 0.05, anchor: .bottom)
                    .offset(y: fanned ? CGFloat(i) * 78 : CGFloat(i) * 10)
                    .opacity(fanned || i == 0 ? 1 : 0.9)
                }
            }
            .frame(height: fanned ? 240 : 100, alignment: .top)
            .contentShape(.rect)
            .onTapGesture { withAnimation(.spring(duration: 0.42, bounce: 0.2)) { fanned.toggle() } }
            .sensoryFeedback(.impact(weight: .light), trigger: fanned)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityHint(fanned ? "Collapses recent cups" : "Shows recent cups")
            Text(fanned ? "Show less" : "\(model.journal.count) cups this week").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.top, 6).padding(.bottom, 70)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct Timer19: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe, step = r.steps[index], frac = min(1, elapsed / Double(r.totalS))
            VStack(spacing: 20) {
                // The Dynamic Island, expanded.
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.2), lineWidth: 4)
                        Circle().trim(from: 0, to: frac).stroke(G.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)
                    Text(step.cumulativeG.map { "to \($0) g" } ?? step.kind.label).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(G.accent)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.white).padding(.horizontal, 16).frame(height: 52)
                .background(.black, in: .capsule).padding(.horizontal, 30)
                .accessibilityElement(children: .combine)
                Spacer()
                // The lock-screen Live Activity, at full size.
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Next Cup", systemImage: "cup.and.saucer.fill").font(.footnote.weight(.semibold)).foregroundStyle(G.accent)
                        Spacer()
                        Text("\(index + 1) of \(r.steps.count)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.clock(Int(elapsed))).font(.system(size: 64, weight: .semibold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText())
                        Spacer()
                        Text(step.cumulativeG.map { "\($0) g" } ?? "—").font(.system(.title, design: .rounded, weight: .semibold)).foregroundStyle(G.accent)
                    }
                    Text(step.instruction).font(.body).foregroundStyle(.secondary)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemFill))
                            Capsule().fill(G.accent).frame(width: g.size.width * frac)
                            ForEach(r.steps.dropFirst()) { s in
                                Circle().fill(Double(s.startS) <= elapsed ? .white : Color(.tertiaryLabel)).frame(width: 6, height: 6)
                                    .offset(x: g.size.width * Double(s.startS) / Double(r.totalS) - 3)
                            }
                        }
                    }
                    .frame(height: 10).accessibilityHidden(true)
                }
                .padding(20)
                .background(.regularMaterial, in: .rect(cornerRadius: 30, style: .continuous))
                Text("This keeps running on your Lock Screen. Put the phone down.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        Button("Done", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly).font(.title2).foregroundStyle(.primary)
                            .frame(width: 68, height: 68).glassEffect(.regular.interactive(), in: .circle)
                        Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                            .labelStyle(.iconOnly).font(.title).foregroundStyle(.white).contentTransition(.symbolEffect(.replace))
                            .frame(width: 84, height: 84).glassEffect(.regular.tint(G.accent).interactive(), in: .circle)
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.title2).foregroundStyle(.primary)
                            .frame(width: 68, height: 68).glassEffect(.regular.interactive(), in: .circle)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct Log19: View {
    @Bindable var model: FlowModel
    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color(.tertiaryLabel)).frame(width: 36, height: 5).padding(.top, 8)
            Text("How was it?").font(.title.weight(.bold))
            Text("\(model.draft.bean) · \(Fmt.clock(model.draft.timeS))").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                face("Meh", "face.dashed", 4)
                face("Good", "face.smiling", 7)
                face("Great", "star.fill", 10)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? .white : .primary).padding(.horizontal, 14).frame(minHeight: 44)
                            .background(on ? G.accent : Color(.tertiarySystemFill), in: .capsule)
                            .buttonStyle(PressScale()).accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
            Text("Dose \(Fmt.num(model.draft.doseG)) g · Water \(Fmt.num(model.draft.waterG)) g · \(Fmt.num(model.draft.tempC)) °C  ·  Edit")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("Save Cup") { model.save() }.font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56).glassEffect(.regular.tint(G.accent).interactive(), in: .capsule)
        }
        .padding(20)
        .presentationDetents([.medium, .large])
    }

    private func face(_ label: String, _ symbol: String, _ halfSteps: Int) -> some View {
        let on = model.draft.ratingHalfSteps == halfSteps
        return Button { withAnimation(.snappy(duration: 0.24)) { model.draft.ratingHalfSteps = halfSteps } } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 34)).symbolEffect(.bounce, value: on)
                Text(label).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(on ? .white : .primary).frame(maxWidth: .infinity, minHeight: 100)
            .background(on ? G.accent : Color(.secondarySystemFill), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(PressScale()).sensoryFeedback(.selection, trigger: on).accessibilityAddTraits(on ? .isSelected : [])
    }
}
