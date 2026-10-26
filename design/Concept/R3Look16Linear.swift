import SwiftUI

// 16. Board (Linear). Organizing idea: brews are issues sorted by status. Dense, monochrome,
// hairlines, a status glyph per taste (balanced = done, sour/bitter = needs a fix) and the
// next fix written in place. A glass command bar floats at the bottom of the list.

private enum L {
    static let accent = Color(0x5E5CE6, 0x8E8CFF)
    static func status(_ v: Verdict?) -> (String, Color) {
        switch v {
        case .balanced: ("checkmark.circle.fill", Color(0x2E8B57, 0x4CC38A))
        case .sour, .weak: ("arrow.down.circle", Color(0xC27C0E, 0xF2B544))
        case .bitter, .strong: ("arrow.up.circle", Color(0xC2412D, 0xFF7A66))
        case nil: ("circle.dashed", .secondary)
        }
    }
    static func fix(_ v: Verdict?) -> String {
        switch v {
        case .sour: "Grind one step finer"
        case .bitter: "Grind one step coarser"
        case .weak: "Use 20 g less water"
        case .strong: "Use 20 g more water"
        case .balanced: "Keep this recipe"
        case nil: "Rate to get a fix"
        }
    }
}

struct Look16: View {
    var body: some View {
        ConceptShell(tint: L.accent) { LookRecipe(model: $0) } timer: { Timer16(model: $0) }
            log: { Log16(model: $0) } journal: { Board16(model: $0) }
    }
}

private struct Board16: View {
    let model: FlowModel
    var body: some View {
        let groups: [(String, [JournalEntry])] = [
            ("Needs a fix", model.journal.filter { $0.verdict != .balanced }),
            ("Dialed in", model.journal.filter { $0.verdict == .balanced }),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.0) { title, items in
                    HStack(spacing: 8) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text("\(items.count)").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "plus").font(.subheadline).foregroundStyle(.secondary).frame(width: 44, height: 36)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
                    .background(Color(.secondarySystemBackground))
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                        let s = L.status(e.verdict)
                        HStack(spacing: 12) {
                            Image(systemName: s.0).foregroundStyle(s.1).font(.body.weight(.semibold)).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("NC-\(140 - i * 3)").font(.caption.monospaced()).foregroundStyle(.tertiary)
                                    Text(e.bean).font(.subheadline.weight(.medium)).lineLimit(1)
                                }
                                Text(L.fix(e.verdict)).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(e.method.split(separator: " ").first.map(String.init) ?? "").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2).overlay(Capsule().strokeBorder(Color(.separator)))
                            Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 56)
                        .accessibilityElement(children: .combine)
                        .assemble(i)
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.bottom, 90)
        }
        .overlay(alignment: .bottom) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Label("Search brews", systemImage: "magnifyingglass").font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 16)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    Button("New Brew", systemImage: "plus") { model.tab = .recipes; model.showTimer = true }.labelStyle(.iconOnly)
                        .font(.headline).foregroundStyle(.white).frame(width: 48, height: 48)
                        .glassEffect(.regular.tint(L.accent).interactive(), in: .circle)
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .navigationTitle("Brews").navigationBarTitleDisplayMode(.inline)
    }
}

private struct Timer16: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary).frame(width: 44, height: 44)
                    Text("NC-141").font(.subheadline.monospaced()).foregroundStyle(.tertiary)
                    Spacer()
                    Label("In progress", systemImage: "circle.lefthalf.filled").font(.footnote.weight(.medium)).foregroundStyle(L.accent)
                }
                Text(r.name).font(.title2.weight(.semibold)).padding(.top, 12)
                Text("\(r.method) · Kenya Kiambu AA").font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 56, weight: .semibold)).monospacedDigit().contentTransition(.numericText())
                    Text("/ \(Fmt.clock(r.totalS))").font(.title3).foregroundStyle(.tertiary)
                }
                .padding(.top, 24)
                HStack(spacing: 3) {
                    ForEach(r.steps) { s in
                        RoundedRectangle(cornerRadius: 2).fill(s.id < index ? Color.primary : (s.id == index ? L.accent : Color(.systemFill)))
                            .frame(height: 4).frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                ForEach(r.steps) { s in
                    let live = s.id == index, done = s.id < index
                    HStack(spacing: 12) {
                        Image(systemName: done ? "checkmark.circle.fill" : (live ? "circle.lefthalf.filled" : "circle"))
                            .foregroundStyle(done ? .secondary : (live ? L.accent : Color(.tertiaryLabel))).frame(width: 20)
                        Text(s.kind.label + (s.cumulativeG.map { " · \($0) g" } ?? "")).font(.subheadline.weight(live ? .semibold : .regular))
                            .foregroundStyle(done ? .secondary : .primary)
                        Spacer()
                        Text(Fmt.clock(s.startS)).font(.footnote.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 40)
                    if live { Text(s.instruction).font(.footnote).foregroundStyle(.secondary).padding(.leading, 32).padding(.bottom, 6) }
                    Divider().padding(.leading, 32)
                }
                Spacer()
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Mark Done") { model.finishBrew() }.font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 50).glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        Button(model.primaryTitle) { model.toggleTimer() }.font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50).glassEffect(.regular.tint(L.accent).interactive(), in: .rect(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct Log16: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Bean", text: $model.draft.bean).font(.title3.weight(.semibold))
                    TextField("Add a note…", text: $model.draft.notes, axis: .vertical).foregroundStyle(.secondary)
                }
                Section("Taste") {
                    Picker("Status", selection: $model.draft.verdict) {
                        ForEach(Verdict.allCases) { v in
                            Label(v.label, systemImage: L.status(v).0).tag(Verdict?.some(v))
                        }
                    }
                    .pickerStyle(.inline).labelsHidden()
                    LabeledContent("Next time", value: L.fix(model.draft.verdict)).foregroundStyle(.secondary)
                }
                Section("Properties") {
                    Stepper("Dose  \(Fmt.num(model.draft.doseG)) g", value: $model.draft.doseG, in: 1...100, step: 0.5).monospacedDigit()
                    Stepper("Water  \(Fmt.num(model.draft.waterG)) g", value: $model.draft.waterG, in: 10...1000, step: 5).monospacedDigit()
                    LabeledContent("Rating") { LookRating(halfSteps: $model.draft.ratingHalfSteps, color: L.accent, size: 18) }
                }
            }
            .navigationTitle("Close brew").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(L.accent) }
            }
        }
    }
}
