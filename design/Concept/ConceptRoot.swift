import SwiftUI
import UIKit

// The F01 flow in the Steel & Kraft system: recipe -> timer -> log -> journal.
// Every color, font and control comes from design/DesignSystem. This file is
// layout and wiring only.

private typealias T = DS

struct ConceptRoot: View {
    var body: some View {
        ConceptShell(tint: T.signal, appearance: configureBars) { model in
            RecipeScreen(model: model)
        } timer: { model in
            TimerScreen(model: model)
        } log: { model in
            LogScreen(model: model)
        } journal: { model in
            JournalScreen(model: model)
        }
    }

    private func configureBars() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(T.bg)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        let ink = UIColor(T.ink)
        nav.largeTitleTextAttributes = [.foregroundColor: ink, .font: UIFont(name: "DINCondensed-Bold", size: 40) ?? .boldSystemFont(ofSize: 40)]
        nav.titleTextAttributes = [.foregroundColor: ink, .font: UIFont(name: "DINCondensed-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

private func ratioText(_ ratio: Double) -> String { "1:\(Fmt.num((ratio * 10).rounded() / 10))" }

// MARK: - S07 Recipe

private struct RecipeScreen: View {
    let model: FlowModel
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        let r = model.recipe
        ScrollView {
            VStack(alignment: .leading, spacing: T.Space.lg) {
                Text(r.name.uppercased()).font(T.Font.display).foregroundStyle(T.ink)
                PaperBox {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        if dts.isAccessibilitySize {
                            SpecCell(label: "Dose", value: "\(Fmt.num(r.doseG)) g"); Hairline()
                            SpecCell(label: "Water", value: "\(Fmt.num(r.waterG)) g"); Hairline()
                            SpecCell(label: "Ratio", value: r.ratioText); Hairline()
                            SpecCell(label: "Temp", value: "\(Fmt.num(r.tempC)) °C"); Hairline()
                            SpecCell(label: "Time", value: Fmt.clock(r.totalS)); Hairline()
                            SpecCell(label: "Steps", value: "\(r.steps.count)")
                        } else {
                            GridRow { SpecCell(label: "Dose", value: "\(Fmt.num(r.doseG)) g"); vline; SpecCell(label: "Water", value: "\(Fmt.num(r.waterG)) g") }
                            Hairline()
                            GridRow { SpecCell(label: "Ratio", value: r.ratioText); vline; SpecCell(label: "Temp", value: "\(Fmt.num(r.tempC)) °C") }
                            Hairline()
                            GridRow { SpecCell(label: "Time", value: Fmt.clock(r.totalS)); vline; SpecCell(label: "Steps", value: "\(r.steps.count)") }
                        }
                    }
                }
                VStack(spacing: 0) {
                    ColumnHeader(leading: "T+", middle: "Operation", trailing: "Scale")
                    ForEach(r.steps) { step in
                        OperationRow(time: Fmt.clock(step.startS), name: step.kind.label, instruction: step.instruction,
                                     scale: step.cumulativeG.map { "\($0) g" } ?? "—")
                            .accessibilityLabel("\(step.kind.label), \(Fmt.clock(step.startS))\(step.cumulativeG.map { ", target \($0) grams" } ?? ""). \(step.instruction)")
                    }
                }
                .overlay(Rectangle().strokeBorder(T.line, lineWidth: T.rule))
                KraftNote {
                    VStack(alignment: .leading, spacing: T.Space.xs) {
                        Text(r.tuningNote).font(T.Font.note).foregroundStyle(T.onKraft)
                        Text(r.credit).font(T.Font.typewriter(12, relativeTo: .caption)).foregroundStyle(T.onKraft.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, T.Space.lg).padding(.top, T.Space.xs).padding(.bottom, T.Space.lg)
        }
        .background(T.bg)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            SteelButton(title: "Start brew") { model.showTimer = true }
                .padding(.horizontal, T.Space.lg).padding(.vertical, T.Space.sm).background(T.bg)
        }
    }

    private var vline: some View { Rectangle().fill(T.line).frame(width: T.rule) }
}

// MARK: - S05 Timer

private struct TimerScreen: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: T.Space.md) {
                HStack {
                    Text(r.name.uppercased()).font(T.Font.din(17, relativeTo: .body)).foregroundStyle(T.ink2).lineLimit(1)
                    Spacer()
                    Button { model.pauseTimer(); model.showTimer = false } label: {
                        Image(systemName: "xmark").font(.body.weight(.bold)).frame(width: T.Size.minTap, height: T.Size.minTap)
                            .background(T.paper, ignoresSafeAreaEdges: [])
                            .overlay(Rectangle().strokeBorder(T.line, lineWidth: T.rule))
                    }
                    .foregroundStyle(T.ink).accessibilityLabel("Close timer")
                }
                InstrumentPanel {
                    VStack(alignment: .leading, spacing: T.Space.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("ELAPSED").font(T.Font.label).foregroundStyle(T.onSteel.opacity(0.75))
                            Spacer()
                            Text(model.hasStarted ? "STEP \(index + 1)/\(r.steps.count)" : "READY")
                                .font(T.Font.label).foregroundStyle(T.signalOnSteel)
                        }
                        Text(Fmt.clock(Int(elapsed))).font(T.Font.readout)
                            .dynamicTypeSize(...T.readoutCap)
                            .minimumScaleFactor(0.4).lineLimit(1).foregroundStyle(T.onSteel)
                            .accessibilityLabel("Elapsed \(Int(elapsed) / 60) minutes \(Int(elapsed) % 60) seconds")
                        ReadoutBar(fraction: elapsed / Double(r.totalS))
                    }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(r.steps) { s in
                            let state: RowState = !model.hasStarted ? .upcoming : (s.id == index ? .live : (s.id < index ? .done : .upcoming))
                            OperationRow(time: Fmt.clock(s.startS), name: s.kind.label, instruction: s.instruction,
                                         scale: s.cumulativeG.map { "\($0) g" }, state: state, showsInstruction: false)
                        }
                    }
                    .overlay(Rectangle().strokeBorder(T.line, lineWidth: T.rule))
                }
                .scrollBounceBehavior(.basedOnSize)
                HStack(spacing: T.Space.md - 2) {
                    if model.hasStarted && !model.isDone {
                        SteelButton(title: "End + log", kind: .secondary) { model.finishBrew() }
                    }
                    SteelButton(title: model.isDone ? "Log it" : (!model.hasStarted ? "Start" : (model.isRunning ? "Pause" : "Resume"))) {
                        model.isDone ? model.finishBrew() : model.toggleTimer()
                    }
                }
            }
            .padding(.horizontal, T.Space.lg).padding(.bottom, T.Space.sm)
            .background(T.bg.ignoresSafeArea())
        }
    }
}

// MARK: - S02 Log

private struct LogScreen: View {
    @Bindable var model: FlowModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: T.Space.md + 2) {
                    Text("RECORD ACTUALS. TARGET SHOWN BELOW EACH VALUE.").font(T.Font.label).foregroundStyle(T.ink2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: T.Space.md - 2), count: dts.isAccessibilitySize ? 1 : 2), spacing: T.Space.md - 2) {
                        StepperTile(title: "Dose", value: Fmt.num(model.draft.doseG), unit: "g", target: "\(Fmt.num(model.recipe.doseG)) g",
                                    down: { model.draft.doseG = max(0.5, model.draft.doseG - 0.5) }, up: { model.draft.doseG += 0.5 })
                        StepperTile(title: "Water", value: Fmt.num(model.draft.waterG), unit: "g", target: "\(Fmt.num(model.recipe.waterG)) g",
                                    down: { model.draft.waterG = max(1, model.draft.waterG - 5) }, up: { model.draft.waterG += 5 })
                        StepperTile(title: "Temp", value: Fmt.num(model.draft.tempC), unit: "°C", target: "\(Fmt.num(model.recipe.tempC)) °C",
                                    down: { model.draft.tempC = max(50, model.draft.tempC - 1) }, up: { model.draft.tempC = min(100, model.draft.tempC + 1) })
                        StepperTile(title: "Time", value: Fmt.clock(model.draft.timeS), target: Fmt.clock(model.recipe.totalS),
                                    down: { model.draft.timeS = max(1, model.draft.timeS - 5) }, up: { model.draft.timeS += 5 })
                        StepperTile(title: "Grind", value: "\(model.draft.grind)",
                                    down: { model.draft.grind = max(1, model.draft.grind - 1) }, up: { model.draft.grind += 1 },
                                    minusLabel: "Finer", plusLabel: "Coarser")
                        if let ratio = model.draft.ratio { ReadoutTile(title: "Ratio", value: ratioText(ratio)) }
                    }
                    Text("TASTE").font(T.Font.din(18, relativeTo: .headline)).foregroundStyle(T.ink)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: T.Space.sm), count: dts.isAccessibilitySize ? 1 : 3), spacing: T.Space.sm) {
                        ForEach(Verdict.allCases) { v in
                            ChoiceButton(title: v.label, isSelected: model.draft.verdict == v) {
                                model.draft.verdict = model.draft.verdict == v ? nil : v
                            }
                        }
                    }
                    Text("GRADE  \(Fmt.stars(model.draft.ratingHalfSteps).uppercased())").font(T.Font.din(18, relativeTo: .headline)).foregroundStyle(T.ink)
                    GradeScale(halfSteps: $model.draft.ratingHalfSteps)
                    KraftNote {
                        VStack(alignment: .leading, spacing: T.Space.xs + 2) {
                            Text("NOTE").font(T.Font.label).foregroundStyle(T.onKraft.opacity(0.8))
                            TextField("Tasted like, change next", text: $model.draft.notes, axis: .vertical)
                                .font(T.Font.note).lineLimit(3...6).foregroundStyle(T.onKraft)
                        }
                    }
                    if let err = model.saveError { StateBanner(kind: .error, message: err) }
                }
                .padding(.horizontal, T.Space.lg).padding(.top, T.Space.xs).padding(.bottom, T.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(T.bg)
            .navigationTitle(model.draft.bean)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                SteelButton(title: "Save brew") { model.save() }
                    .disabled(!model.draft.canSave)
                    .padding(.horizontal, T.Space.lg).padding(.vertical, T.Space.sm).background(T.bg)
            }
        }
    }
}

// MARK: - S01 Journal

private struct JournalScreen: View {
    let model: FlowModel

    var body: some View {
        Group {
            if model.journal.isEmpty {
                ScrollView {
                    PaperBox {
                        EmptyState(title: "No brews yet", message: "Log your first brew to start the journal.", actionTitle: "Log a brew") { newLog() }
                    }
                    .padding(T.Space.lg)
                }
                .background(T.bg)
            } else {
                list
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newLog() } label: {
                    Image(systemName: "plus").font(.body.weight(.heavy)).frame(width: T.Size.minTap, height: T.Size.minTap)
                }
                .accessibilityLabel("Log a brew")
            }
        }
    }

    private func newLog() { model.prefillFromRecipe(measuredS: 180); model.showLog = true }

    private var list: some View {
        List {
            Section {
                ForEach(model.journal) { e in
                    VStack(alignment: .leading, spacing: T.Space.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(e.bean.uppercased()).font(T.Font.din(21, relativeTo: .headline)).foregroundStyle(T.ink)
                            Spacer(minLength: 6)
                            GradeBadge(halfSteps: e.ratingHalfSteps)
                        }
                        Text("\(Fmt.day(e.date)) · \(e.method)").font(T.Font.mono(.caption)).foregroundStyle(T.ink2)
                        Text("\(Fmt.num(e.doseG))g / \(Fmt.num(e.waterG))g · \(ratioText(e.ratio)) · \(Fmt.clock(e.timeS)) · \(Int(e.tempC))°C · G\(e.grind)\(e.verdict.map { " · " + $0.label.lowercased() } ?? "")")
                            .font(T.Font.mono(.caption, .bold)).foregroundStyle(T.ink)
                        if !e.note.isEmpty { Text(e.note).font(T.Font.typewriter(13, relativeTo: .footnote)).foregroundStyle(T.ink2) }
                    }
                    .padding(.vertical, T.Space.xs)
                    .listRowBackground(T.paper).listRowSeparatorTint(T.line)
                    .accessibilityElement(children: .combine)
                    .swipeActions { Button("Delete", role: .destructive) { model.journal.removeAll { $0.id == e.id } } }
                }
            } header: {
                Text("\(model.journal.count) ENTRIES").font(T.Font.label).foregroundStyle(T.ink2)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(T.bg)
    }
}
