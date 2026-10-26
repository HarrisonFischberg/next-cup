import SwiftUI

// 12. Checklist (Things 3). Organizing idea: everything is plain text until you touch it.
// The journal reads like a quiet list grouped by day; one entry is open inline. The timer is
// the recipe as a checklist: steps tick themselves off with a check that draws in.

private enum K {
    static let accent = Color(0x2E6FD8, 0x5C9BFF)
    static let warm = Color(0xC0731F, 0xF0A048)
}

struct Look12: View {
    var body: some View {
        ConceptShell(tint: K.accent) { LookRecipe(model: $0) } timer: { Timer12(model: $0) }
            log: { Log12(model: $0) } journal: { Journal12(model: $0) }
    }
}

private struct Journal12: View {
    let model: FlowModel
    @State private var open: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(K.warm)
                    Text("Journal").font(.largeTitle.weight(.bold))
                }
                .padding(.bottom, 16)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    if i == 0 || !Calendar.current.isDate(e.date, inSameDayAs: model.journal[i - 1].date) {
                        Text(Fmt.day(e.date)).font(.subheadline.weight(.bold)).foregroundStyle(K.accent)
                            .padding(.top, 18).padding(.bottom, 4)
                        Divider()
                    }
                    row(e).assemble(i)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear { open = model.journal.first?.id }
    }

    private func row(_ e: JournalEntry) -> some View {
        let isOpen = open == e.id
        return Button {
            withAnimation(.snappy(duration: 0.28)) { open = isOpen ? nil : e.id }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: e.ratingHalfSteps >= 8 ? "star.fill" : "circle")
                        .font(.body.weight(.medium)).foregroundStyle(e.ratingHalfSteps >= 8 ? K.warm : Color(.tertiaryLabel))
                        .frame(width: 22)
                    Text(e.bean).font(.body)
                    Spacer()
                    Text(e.method).font(.subheadline).foregroundStyle(.tertiary)
                }
                if isOpen {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(e.note).font(.body).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            tag("1:\(Fmt.num(e.ratio))", "scalemass")
                            tag(Fmt.clock(e.timeS), "timer")
                            tag("\(Fmt.num(e.tempC))°", "thermometer.medium")
                            if let v = e.verdict { tag(v.label, "tag") }
                        }
                    }
                    .padding(.leading, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 12).padding(.horizontal, isOpen ? 14 : 0)
            .background(isOpen ? Color(.secondarySystemBackground) : .clear, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(isOpen ? 0.06 : 0), radius: 10, y: 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Collapses details" : "Shows details")
    }

    private func tag(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1).fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4).background(Color(.tertiarySystemFill), in: .capsule)
    }
}

private struct Timer12: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Done") { model.showTimer = false }.font(.body.weight(.semibold)).frame(minHeight: 44)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.title3.weight(.semibold)).monospacedDigit()
                        .contentTransition(.numericText())
                }
                Text(r.name).font(.title.weight(.bold)).padding(.top, 20)
                Text("\(r.method) · \(Fmt.num(r.doseG)) g · \(Fmt.num(r.waterG)) g · \(Fmt.num(r.tempC))°").font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 4).padding(.bottom, 24)
                ForEach(r.steps) { s in
                    let done = s.id < index, live = s.id == index
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(done ? K.accent : Color(.tertiaryLabel), lineWidth: 1.5)
                                .background(done ? K.accent : .clear, in: .rect(cornerRadius: 6))
                            if done { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white).transition(.symbolEffect(.drawOn)) }
                        }
                        .frame(width: 22, height: 22).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(s.kind.label + (s.cumulativeG.map { " to \($0) g" } ?? "")).font(live ? .title3.weight(.semibold) : .body)
                                    .foregroundStyle(done ? .tertiary : .primary).strikethrough(done, color: Color(.tertiaryLabel))
                                Spacer()
                                Text(Fmt.clock(s.startS)).font(.subheadline).foregroundStyle(.tertiary).monospacedDigit()
                            }
                            if live {
                                Text(s.instruction).font(.body).foregroundStyle(.secondary)
                                ProgressView(value: elapsed - Double(s.startS), total: Double(r.endS(of: s) - s.startS)).tint(K.accent)
                            }
                        }
                    }
                    .padding(.vertical, 10).padding(.horizontal, live ? 12 : 0)
                    .background(live ? K.accent.opacity(0.08) : .clear, in: .rect(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(done ? "Done" : (live ? "Now" : "Upcoming"))
                }
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Finish and Log") { model.finishBrew() }.font(.body.weight(.semibold)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 52).glassEffect(.regular.interactive(), in: .capsule)
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.body.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52).glassEffect(.regular.tint(K.accent).interactive(), in: .capsule)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct Log12: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Bean", text: $model.draft.bean).font(.title.weight(.bold))
                    TextField("Notes", text: $model.draft.notes, axis: .vertical).font(.body).foregroundStyle(.secondary).lineLimit(1...6)
                    Divider()
                    HStack(spacing: 8) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { withAnimation(.snappy(duration: 0.24)) { model.draft.verdict = on ? nil : v } }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(on ? .white : .secondary)
                                .padding(.horizontal, 10).frame(minHeight: 44)
                                .background(on ? K.accent : Color(.tertiarySystemFill), in: .capsule)
                                .buttonStyle(PressScale()).sensoryFeedback(.selection, trigger: on)
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: K.warm, size: 24)
                    VStack(spacing: 0) {
                        line("scalemass", "Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        Divider().padding(.leading, 36)
                        line("drop", "Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        Divider().padding(.leading, 36)
                        line("thermometer.medium", "Temperature", "\(Fmt.num(model.draft.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(K.accent) }
            }
        }
    }

    private func line(_ symbol: String, _ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 24)
            Text(k)
            Spacer()
            Text(v).monospacedDigit().foregroundStyle(.secondary).contentTransition(.numericText())
            Button("Less \(k.lowercased())", systemImage: "minus", action: step.down).frame(width: 44, height: 44)
            Button("More \(k.lowercased())", systemImage: "plus", action: step.up).frame(width: 44, height: 44)
        }
        .labelStyle(.iconOnly).buttonStyle(PressScale(scale: 0.9))
    }
}
