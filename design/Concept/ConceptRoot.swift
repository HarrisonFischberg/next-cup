import SwiftUI
import UIKit

// Concept 4 — Steel & Kraft
// Industrial and utilitarian: spec-sheet tables, hard corners, hairline rules,
// kraft-paper label for notes, one signal orange. Dense, readable at arm's
// length. The timer is an instrument panel that shows every step at once.

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private enum T {
    static let bg = Color(light: 0xD9C4A0, dark: 0x1B1D1F)          // kraft / gunmetal
    static let paper = Color(light: 0xEFE6D3, dark: 0x26292C)       // sheet
    static let steel = Color(light: 0x2B2F33, dark: 0x30353A)       // instrument panel
    static let onSteel = Color(light: 0xE8EAEC, dark: 0xE8EAEC)
    static let ink = Color(light: 0x1E1E1C, dark: 0xECEAE4)
    static let ink2 = Color(light: 0x4A463E, dark: 0xB4B1A8)
    static let line = Color(light: 0x1E1E1C, dark: 0x6A6F74)
    static let signal = Color(light: 0xC2410C, dark: 0xFF7A3D)
    static let signalOnSteel = Color(light: 0xFF7A3D, dark: 0xFF7A3D) // 6.1:1 on the steel panel
    static let onSignal = Color(light: 0xFFFFFF, dark: 0x1B1D1F)
    static let kraft = Color(light: 0xC9AE82, dark: 0xC9AE82)
    static let onKraft = Color(light: 0x1E1E1C, dark: 0x1E1E1C)
    static let error = Color(light: 0x9A1B0A, dark: 0xFF9C85)

    static func din(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("DINCondensed-Bold", size: size, relativeTo: style)
    }
    static func mono(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
    static func typewriter(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("AmericanTypewriter", size: size, relativeTo: style)
    }
}

private struct Hairline: View {
    var body: some View { Rectangle().fill(T.line).frame(height: 1.5) }
}

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
        tab.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x1B1D1F) : UIColor(hex: 0xD9C4A0) }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xECEAE4) : UIColor(hex: 0x1E1E1C) }
        nav.largeTitleTextAttributes = [.foregroundColor: ink, .font: UIFont(name: "DINCondensed-Bold", size: 40) ?? .boldSystemFont(ofSize: 40)]
        nav.titleTextAttributes = [.foregroundColor: ink, .font: UIFont(name: "DINCondensed-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

private struct SteelButton: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primary ? T.onSignal : T.onSteel)
            .background(primary ? T.signal : T.steel, in: .rect(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(T.line, lineWidth: 1.5))
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - S07 Recipe

private struct RecipeScreen: View {
    let model: FlowModel
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        let r = model.recipe
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(r.name.uppercased()).font(T.din(34, relativeTo: .title)).foregroundStyle(T.ink)
                VStack(spacing: 0) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        if dts.isAccessibilitySize {
                            cell("Dose", "\(Fmt.num(r.doseG)) g"); Hairline()
                            cell("Water", "\(Fmt.num(r.waterG)) g"); Hairline()
                            cell("Ratio", r.ratioText); Hairline()
                            cell("Temp", "\(Fmt.num(r.tempC)) °C"); Hairline()
                            cell("Time", Fmt.clock(r.totalS)); Hairline()
                            cell("Steps", "\(r.steps.count)")
                        } else {
                            GridRow { cell("Dose", "\(Fmt.num(r.doseG)) g"); vline; cell("Water", "\(Fmt.num(r.waterG)) g") }
                            Hairline()
                            GridRow { cell("Ratio", r.ratioText); vline; cell("Temp", "\(Fmt.num(r.tempC)) °C") }
                            Hairline()
                            GridRow { cell("Time", Fmt.clock(r.totalS)); vline; cell("Steps", "\(r.steps.count)") }
                        }
                    }
                }
                .background(T.paper, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))

                VStack(spacing: 0) {
                    HStack {
                        Text("T+").frame(width: 56, alignment: .leading)
                        Text("Operation"); Spacer(); Text("Scale")
                    }
                    .font(T.din(15, relativeTo: .footnote)).textCase(.uppercase).foregroundStyle(T.onSteel)
                    .padding(.horizontal, 10).frame(minHeight: 32).background(T.steel, ignoresSafeAreaEdges: [])
                    ForEach(r.steps) { step in
                        VStack(spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(Fmt.clock(step.startS)).font(T.mono(.callout, .bold)).fixedSize().frame(minWidth: 56, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.kind.label.uppercased()).font(T.din(20, relativeTo: .headline))
                                    Text(step.instruction).font(.footnote).foregroundStyle(T.ink2)
                                }
                                Spacer(minLength: 8)
                                Text(step.cumulativeG.map { "\($0) g" } ?? "—").font(T.mono(.callout, .bold))
                            }
                            .foregroundStyle(T.ink)
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            Rectangle().fill(T.line.opacity(0.5)).frame(height: 1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(step.kind.label), \(Fmt.clock(step.startS))\(step.cumulativeG.map { ", target \($0) grams" } ?? ""). \(step.instruction)")
                    }
                }
                .background(T.paper, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(r.tuningNote).font(T.typewriter(15)).foregroundStyle(T.onKraft)
                    Text(r.credit).font(T.typewriter(12, relativeTo: .caption)).foregroundStyle(T.onKraft.opacity(0.75))
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.kraft, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().strokeBorder(T.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
        }
        .background(T.bg)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { model.showTimer = true } label: {
                Text("START BREW").font(T.din(26, relativeTo: .title2)).tracking(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(SteelButton())
            .padding(.horizontal, 16).padding(.vertical, 8).background(T.bg)
        }
    }

    private var vline: some View { Rectangle().fill(T.line).frame(width: 1.5) }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(T.din(15, relativeTo: .footnote)).foregroundStyle(T.ink2)
            Text(value).font(T.mono(.title2, .bold)).foregroundStyle(T.ink).minimumScaleFactor(0.6).lineLimit(1)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - S05 Timer (instrument panel)

private struct TimerScreen: View {
    let model: FlowModel
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(spacing: 12) {
                HStack {
                    Text(r.name.uppercased()).font(T.din(17, relativeTo: .body)).foregroundStyle(T.ink2).lineLimit(1)
                    Spacer()
                    Button { model.pauseTimer(); model.showTimer = false } label: {
                        Image(systemName: "xmark").font(.body.weight(.bold)).frame(width: 44, height: 44)
                            .background(T.paper, ignoresSafeAreaEdges: [])
                            .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))
                    }
                    .foregroundStyle(T.ink).accessibilityLabel("Close timer")
                }
                // Readout
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("ELAPSED").font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.onSteel.opacity(0.75))
                        Spacer()
                        Text(model.hasStarted ? "STEP \(index + 1)/\(r.steps.count)" : "READY")
                            .font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.signalOnSteel)
                    }
                    Text(Fmt.clock(Int(elapsed)))
                        .font(.system(size: 104, weight: .bold, design: .monospaced))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .minimumScaleFactor(0.4).lineLimit(1).foregroundStyle(T.onSteel)
                        .accessibilityLabel("Elapsed \(Int(elapsed) / 60) minutes \(Int(elapsed) % 60) seconds")
                    ProgressBar(fraction: elapsed / Double(r.totalS))
                }
                .padding(14).background(T.steel, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))
                // All steps at once; the live one lights up.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(r.steps) { s in
                            let on = model.hasStarted && s.id == index
                            let done = model.hasStarted && s.id < index
                            (dts.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))) {
                                Text(Fmt.clock(s.startS)).font(T.mono(.callout, .bold)).fixedSize().frame(minWidth: 52, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.kind.label.uppercased()).font(T.din(on ? 26 : 20, relativeTo: .title3))
                                    if on { Text(s.instruction).font(.subheadline) }
                                }
                                if !dts.isAccessibilitySize { Spacer(minLength: 6) }
                                Text(s.cumulativeG.map { "\($0) g" } ?? "").font(T.mono(on ? .title3 : .callout, .bold))
                            }
                            .foregroundStyle(on ? T.onSignal : (done ? T.ink2 : T.ink))
                            .padding(.horizontal, 10).padding(.vertical, on ? 12 : 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(on ? T.signal : T.paper)
                            .overlay(alignment: .bottom) { Rectangle().fill(T.line.opacity(0.5)).frame(height: 1) }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))
                }
                .scrollBounceBehavior(.basedOnSize)
                HStack(spacing: 10) {
                    if model.hasStarted && !model.isDone {
                        Button { model.finishBrew() } label: {
                            Text("END + LOG").font(T.din(22, relativeTo: .title3)).dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(SteelButton(primary: false))
                    }
                    Button { model.isDone ? model.finishBrew() : model.toggleTimer() } label: {
                        Text(model.isDone ? "LOG IT" : (!model.hasStarted ? "START" : (model.isRunning ? "PAUSE" : "RESUME")))
                            .font(T.din(30, relativeTo: .title)).tracking(1).dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(SteelButton())
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            .background(T.bg.ignoresSafeArea())
        }
    }
}

private struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        Rectangle().fill(T.onSteel.opacity(0.2)).frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { g in Rectangle().fill(T.signalOnSteel).frame(width: g.size.width * min(1, max(0, fraction))) }
            }
            .accessibilityHidden(true)
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
                VStack(alignment: .leading, spacing: 14) {
                    Text("RECORD ACTUALS. TARGET SHOWN BELOW EACH VALUE.").font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.ink2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dts.isAccessibilitySize ? 1 : 2), spacing: 10) {
                        tile("Dose", value: Fmt.num(model.draft.doseG), unit: "g", target: "\(Fmt.num(model.recipe.doseG)) g",
                             down: { model.draft.doseG = max(0.5, model.draft.doseG - 0.5) }, up: { model.draft.doseG += 0.5 })
                        tile("Water", value: Fmt.num(model.draft.waterG), unit: "g", target: "\(Fmt.num(model.recipe.waterG)) g",
                             down: { model.draft.waterG = max(1, model.draft.waterG - 5) }, up: { model.draft.waterG += 5 })
                        tile("Temp", value: Fmt.num(model.draft.tempC), unit: "°C", target: "\(Fmt.num(model.recipe.tempC)) °C",
                             down: { model.draft.tempC = max(50, model.draft.tempC - 1) }, up: { model.draft.tempC = min(100, model.draft.tempC + 1) })
                        tile("Time", value: Fmt.clock(model.draft.timeS), unit: "", target: Fmt.clock(model.recipe.totalS),
                             down: { model.draft.timeS = max(1, model.draft.timeS - 5) }, up: { model.draft.timeS += 5 })
                        tile("Grind", value: "\(model.draft.grind)", unit: "", target: nil,
                             down: { model.draft.grind = max(1, model.draft.grind - 1) }, up: { model.draft.grind += 1 },
                             minus: "Finer", plus: "Coarser")
                        tile("Grade", value: model.draft.ratingHalfSteps == 0 ? "—" : Fmt.num(Double(model.draft.ratingHalfSteps) / 2), unit: "/5", target: nil,
                             down: { model.draft.ratingHalfSteps = max(0, model.draft.ratingHalfSteps - 1) },
                             up: { model.draft.ratingHalfSteps = min(10, model.draft.ratingHalfSteps + 1) },
                             minus: "Lower grade", plus: "Raise grade")
                    }
                    if let ratio = model.draft.ratio {
                        Text("RATIO  1:\(Fmt.num((ratio * 10).rounded() / 10))").font(T.din(22, relativeTo: .title3)).foregroundStyle(T.ink)
                    }
                    Text("TASTE").font(T.din(18, relativeTo: .headline)).foregroundStyle(T.ink)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dts.isAccessibilitySize ? 1 : 3), spacing: 8) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button { model.draft.verdict = on ? nil : v } label: {
                                Text(v.label.uppercased()).font(T.din(20, relativeTo: .headline))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .foregroundStyle(on ? T.onSignal : T.ink)
                                    .background(on ? T.signal : T.paper)
                                    .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))
                            }
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE").font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.onKraft.opacity(0.8))
                        TextField("Tasted like, change next", text: $model.draft.notes, axis: .vertical)
                            .font(T.typewriter(16)).lineLimit(3...6).foregroundStyle(T.onKraft)
                    }
                    .padding(12).background(T.kraft, ignoresSafeAreaEdges: [])
                    .overlay(Rectangle().strokeBorder(T.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                    if let err = model.saveError { Text(err).font(.callout.weight(.bold)).foregroundStyle(T.error) }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(T.bg)
            .navigationTitle(model.draft.bean)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button { model.save() } label: {
                    Text("SAVE BREW").font(T.din(26, relativeTo: .title2)).tracking(1).dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(SteelButton()).disabled(!model.draft.canSave)
                .padding(.horizontal, 16).padding(.vertical, 8).background(T.bg)
            }
        }
    }

    private func tile(_ title: String, value: String, unit: String, target: String?, down: @escaping () -> Void,
                      up: @escaping () -> Void, minus: String? = nil, plus: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.ink2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(T.mono(.title, .bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(unit).font(T.mono(.callout))
                }
                .foregroundStyle(T.ink)
                Text(target.map { "TARGET \($0)" } ?? " ").font(T.mono(.caption2)).foregroundStyle(T.ink2)
            }
            .padding(10)
            Hairline()
            HStack(spacing: 0) {
                stepButton("minus", label: minus ?? "Decrease \(title)", action: down)
                Rectangle().fill(T.line).frame(width: 1.5)
                stepButton("plus", label: plus ?? "Increase \(title)", action: up)
            }
        }
        .background(T.paper, ignoresSafeAreaEdges: [])
        .overlay(Rectangle().strokeBorder(T.line, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.heavy)).frame(maxWidth: .infinity, minHeight: 48)
        }
        .foregroundStyle(T.ink)
        .accessibilityLabel(label)
    }
}

// MARK: - S01 Journal (ledger)

private struct JournalScreen: View {
    let model: FlowModel

    var body: some View {
        List {
            Section {
                ForEach(model.journal) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(e.bean.uppercased()).font(T.din(21, relativeTo: .headline)).foregroundStyle(T.ink)
                            Spacer(minLength: 6)
                            Text(e.ratingHalfSteps == 0 ? "—" : Fmt.num(Double(e.ratingHalfSteps) / 2))
                                .font(T.mono(.title3, .bold)).foregroundStyle(T.onSignal)
                                .frame(minWidth: 44, minHeight: 32).background(T.signal)
                                .accessibilityLabel("Grade \(Fmt.stars(e.ratingHalfSteps))")
                        }
                        Text("\(Fmt.day(e.date)) · \(e.method)").font(T.mono(.caption)).foregroundStyle(T.ink2)
                        Text("\(Fmt.num(e.doseG))g / \(Fmt.num(e.waterG))g · 1:\(Fmt.num((e.ratio * 10).rounded() / 10)) · \(Fmt.clock(e.timeS)) · \(Int(e.tempC))°C · G\(e.grind)\(e.verdict.map { " · " + $0.label.lowercased() } ?? "")")
                            .font(T.mono(.caption, .bold)).foregroundStyle(T.ink)
                        if !e.note.isEmpty { Text(e.note).font(T.typewriter(13, relativeTo: .footnote)).foregroundStyle(T.ink2) }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(T.paper).listRowSeparatorTint(T.line)
                    .accessibilityElement(children: .combine)
                    .swipeActions { Button("Delete", role: .destructive) { model.journal.removeAll { $0.id == e.id } } }
                }
            } header: {
                Text("\(model.journal.count) ENTRIES").font(T.din(16, relativeTo: .footnote)).foregroundStyle(T.ink2)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(T.bg)
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.prefillFromRecipe(measuredS: 180); model.showLog = true } label: {
                    Image(systemName: "plus").font(.body.weight(.heavy)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Log a brew")
            }
        }
    }
}
