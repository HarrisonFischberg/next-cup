import SwiftUI

// 17. Step Cards (Mela). Organizing idea: one thing at a time, big enough to read from the
// counter. The timer is a horizontal deck of step cards (the live one centred, neighbours
// peeking); the journal is a two-column grid of cup cards with the bean colour as a band.

private enum C {
    static let accent = Color(0xB4532A, 0xF0915F)
    static let card = Color(.secondarySystemGroupedBackground)
}

struct Look17: View {
    var body: some View {
        ConceptShell(tint: C.accent) { LookRecipe(model: $0) } timer: { Timer17(model: $0) }
            log: { Log17(model: $0) } journal: { Grid17(model: $0) }
    }
}

private struct Grid17: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .bottomLeading) {
                            BeanArt.color(e.bean)
                            Text(BeanArt.origin(e.bean)).font(.title2.weight(.bold)).foregroundStyle(.white).padding(12)
                        }
                        .frame(height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.method).font(.headline).lineLimit(1)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(C.accent)
                                Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.subheadline.weight(.semibold)).monospacedDigit()
                                Text("· \(Fmt.clock(e.timeS))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text(e.note).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .padding(12)
                    }
                    .background(C.card).clipShape(.rect(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cups")
    }
}

private struct Timer17: View {
    let model: FlowModel
    @State private var page: Int?

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: 18) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                        .foregroundStyle(.primary).frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 16).frame(minHeight: 44).glassEffect(.regular, in: .capsule)
                }
                .padding(.horizontal, 20)
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(r.steps) { s in
                            let live = s.id == index
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("\(s.id + 1)").font(.headline).foregroundStyle(live ? .white : .secondary)
                                        .frame(width: 34, height: 34).background(live ? C.accent : Color(.tertiarySystemFill), in: .circle)
                                    Spacer()
                                    Image(systemName: s.kind.symbol).font(.title2).foregroundStyle(live ? C.accent : .secondary)
                                        .symbolEffect(.pulse, isActive: live && model.showsRunning)
                                }
                                Spacer()
                                Text(s.kind.label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                Text(s.cumulativeG.map { "\($0) g" } ?? Fmt.clock(r.endS(of: s) - s.startS))
                                    .font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                                Text(s.instruction).font(.title3).fixedSize(horizontal: false, vertical: true)
                                if live {
                                    ProgressView(value: elapsed - Double(s.startS), total: Double(r.endS(of: s) - s.startS)).tint(C.accent)
                                }
                            }
                            .padding(22)
                            .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 14)
                            .frame(height: 400)
                            .background(C.card, in: .rect(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(live ? 0.10 : 0), radius: 18, y: 10)
                            .scaleEffect(live ? 1 : 0.94).opacity(live ? 1 : 0.6)
                            .id(s.id)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $page, anchor: .center)
                .safeAreaPadding(.horizontal, 40)
                .scrollIndicators(.hidden)
                .onAppear { page = index }
                .onChange(of: index) { _, new in withAnimation(.spring(duration: 0.42, bounce: 0.16)) { page = new } }
                HStack(spacing: 6) {
                    ForEach(r.steps) { s in
                        Capsule().fill(s.id == index ? C.accent : Color(.tertiaryLabel)).frame(width: s.id == index ? 22 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.32, bounce: 0.15), value: index)
                .accessibilityLabel("Step \(index + 1) of \(r.steps.count)")
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Finish", systemImage: "checkmark") { model.finishBrew() }.labelStyle(.iconOnly).font(.title2)
                            .foregroundStyle(.primary).frame(width: 64, height: 64).glassEffect(.regular.interactive(), in: .circle)
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.title3.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 64).glassEffect(.regular.tint(C.accent).interactive(), in: .capsule)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct Log17: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 10) {
                        Text("How was it?").font(.title2.weight(.bold))
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.accent, size: 34)
                    }
                    .padding(20).frame(maxWidth: .infinity).background(C.card, in: .rect(cornerRadius: 22))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { model.draft.verdict = on ? nil : v }.font(.headline)
                                .foregroundStyle(on ? .white : .primary).frame(maxWidth: .infinity, minHeight: 56)
                                .background(on ? C.accent : C.card, in: .rect(cornerRadius: 16))
                                .buttonStyle(PressScale()).sensoryFeedback(.selection, trigger: on).accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    HStack(spacing: 10) {
                        big("Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        big("Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.accent) }
            }
        }
    }

    private func big(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        VStack(spacing: 8) {
            Text(k).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(v).font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit().contentTransition(.numericText())
            HStack {
                Button("Less \(k.lowercased())", systemImage: "minus", action: step.down).frame(width: 44, height: 44).background(Color(.tertiarySystemFill), in: .circle)
                Spacer()
                Button("More \(k.lowercased())", systemImage: "plus", action: step.up).frame(width: 44, height: 44).background(Color(.tertiarySystemFill), in: .circle)
            }
            .labelStyle(.iconOnly).font(.headline).foregroundStyle(.primary).buttonStyle(PressScale(scale: 0.9))
        }
        .padding(16).frame(maxWidth: .infinity).background(C.card, in: .rect(cornerRadius: 22))
    }
}
