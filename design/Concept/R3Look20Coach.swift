import SwiftUI

// 20. Coach (Messages). Organizing idea: brewing is a conversation with a barista who knows
// your history. The journal is a thread list; the timer is the chat, each step arriving as a
// message on time; tasting is a reply with quick-reply chips. Native bubbles, glass composer.

private enum M {
    static let accent = Color(0x8A4B2A, 0xE0A070)
    static let theirs = Color(.secondarySystemBackground)
}

private struct Bubble: View {
    let text: String
    var mine = false
    var body: some View {
        Text(text).font(.body).foregroundStyle(mine ? .white : .primary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(mine ? M.accent : M.theirs, in: .rect(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 290, alignment: mine ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}

struct Look20: View {
    var body: some View {
        ConceptShell(tint: M.accent) { LookRecipe(model: $0) } timer: { Timer20(model: $0) }
            log: { Log20(model: $0) } journal: { Threads20(model: $0) }
    }
}

private struct Threads20: View {
    let model: FlowModel
    var body: some View {
        List {
            ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                HStack(spacing: 12) {
                    Text(String(BeanArt.origin(e.bean).prefix(1))).font(.title3.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(BeanArt.color(e.bean), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(e.bean).font(.headline).lineLimit(1)
                            Spacer()
                            Text(e.date, format: .dateTime.weekday(.abbreviated)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(i == 0 ? "Coach: Nailed it. Same again tomorrow?" : "You: \(e.note)").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Coach")
        .toolbar { Button("New Brew", systemImage: "square.and.pencil") { model.tab = .recipes; model.showTimer = true } }
    }
}

private struct Timer20: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: 0) {
                HStack {
                    Button("Close", systemImage: "chevron.left") { model.showTimer = false }.labelStyle(.iconOnly).font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "cup.and.saucer.fill").foregroundStyle(.white).frame(width: 36, height: 36).background(M.accent, in: .circle)
                        Text("Coach · \(Fmt.clock(Int(elapsed)))").font(.caption.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 12)
                Divider()
                ScrollView {
                    VStack(spacing: 6) {
                        Text("Today \(Fmt.clock(0))").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                        Bubble(text: "Kenya again, on the cone. 20 g in, 320 g water at 94°. Start the clock when you're ready.")
                        Bubble(text: "Go", mine: true)
                        ForEach(r.steps.prefix(index + 1)) { s in
                            Bubble(text: (s.cumulativeG.map { "Pour to \($0) g. " } ?? "") + s.instruction)
                                .transition(.asymmetric(insertion: .scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity), removal: .opacity))
                        }
                        if let next = model.nextStep(after: index) {
                            HStack(spacing: 4) {
                                ForEach(0..<3) { _ in Circle().fill(.secondary).frame(width: 7, height: 7) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12).background(M.theirs, in: .capsule)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Next: \(next.kind.label) in \(Fmt.clock(next.startS - Int(elapsed)))")
                        }
                    }
                    .padding(.horizontal, 14)
                    .animation(.spring(duration: 0.42, bounce: 0.2), value: index)
                }
                .defaultScrollAnchor(.bottom)
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.body.weight(.semibold)).foregroundStyle(.primary)
                            .padding(.horizontal, 18).frame(minHeight: 48).glassEffect(.regular.interactive(), in: .capsule)
                        Button("Done, how did it taste?") { model.finishBrew() }.font(.body.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48).glassEffect(.regular.tint(M.accent).interactive(), in: .capsule)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
    }
}

private struct Log20: View {
    @Bindable var model: FlowModel
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(.tertiaryLabel)).frame(width: 36, height: 5).padding(.top, 8)
            ScrollView {
                VStack(spacing: 6) {
                    Bubble(text: "3:04, nice and steady. How did it taste?")
                    if let v = model.draft.verdict { Bubble(text: v.label, mine: true) }
                    if model.draft.verdict == .sour { Bubble(text: "Next time grind one step finer. I'll remember that.") }
                    if model.draft.verdict == .balanced { Bubble(text: "Saving this as your Kenya recipe.") }
                    Bubble(text: "And out of five?")
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: M.accent, size: 26)
                        .padding(.horizontal, 8).background(M.theirs, in: .capsule).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .animation(.spring(duration: 0.42, bounce: 0.2), value: model.draft.verdict)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Verdict.allCases) { v in
                        Button(v.label) { model.draft.verdict = v }.font(.subheadline.weight(.semibold)).foregroundStyle(M.accent)
                            .padding(.horizontal, 14).frame(minHeight: 44).overlay(Capsule().strokeBorder(M.accent.opacity(0.5)))
                            .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 10) {
                TextField("Add a note", text: $model.draft.notes).padding(.horizontal, 16).frame(minHeight: 44)
                    .glassEffect(.regular.interactive(), in: .capsule)
                Button("Save", systemImage: "arrow.up") { model.save() }.labelStyle(.iconOnly).font(.headline).foregroundStyle(.white)
                    .frame(width: 44, height: 44).glassEffect(.regular.tint(M.accent).interactive(), in: .circle)
            }
            .padding(14)
        }
        .presentationDetents([.medium, .large])
    }
}
