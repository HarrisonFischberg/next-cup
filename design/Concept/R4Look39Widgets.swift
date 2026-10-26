import SwiftUI

// 39. Widgets (Apple Music radio widget, Perplexity widgets). Organizing idea: the app is its
// own home screen. Every screen is a stack of widget-shaped containers on a grey board: a large
// bean-coloured widget with a tile grid, a medium "brew" widget with buttons, small stat widgets.

private enum C {
    static let board = Color(0xD9D9DC, 0x0E0E10)
    static let widget = Color(0xFFFFFF, 0x1F1F22)
    static let well = Color(0xF1F1F3, 0x2C2C30)
    static let red = Color(0xE5484D, 0xF2555A)
}

private func widget<V: View>(_ tint: Color? = nil, @ViewBuilder _ v: () -> V) -> some View {
    v().padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(C.widget), in: .rect(cornerRadius: 24, style: .continuous))
}

struct Look39: View {
    var body: some View {
        ConceptShell(tint: C.red) { LookRecipe(model: $0) } timer: { Live39(model: $0) }
            log: { Log39(model: $0) } journal: { Board39(model: $0) }
    }
}

private struct Board39: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                widget(C.red) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Recent cups").font(.headline); Spacer(); Image(systemName: "cup.and.saucer.fill") }.foregroundStyle(.white)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                            ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 10).fill(.white).aspectRatio(1, contentMode: .fit)
                                        .overlay {
                                            VStack(spacing: 0) {
                                                Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.system(size: 30, weight: .heavy)).foregroundStyle(BeanArt.color(e.bean))
                                                Text(e.method).font(.system(size: 9, weight: .semibold)).foregroundStyle(.black.opacity(0.6)).lineLimit(1)
                                            }
                                        }
                                    Text(BeanArt.origin(e.bean)).font(.caption.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                                }
                                .accessibilityElement(children: .combine).assemble(i)
                            }
                        }
                    }
                }
                widget {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(C.red)
                            Button { model.tab = .recipes } label: {
                                Text("Brew the cone recipe").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 14)
                                    .background(C.well, in: .capsule)
                            }
                        }
                        HStack(spacing: 10) {
                            ForEach(["timer", "square.and.pencil", "camera", "chart.bar"], id: \.self) { s in
                                Image(systemName: s).font(.title3).foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 56).background(C.well, in: .rect(cornerRadius: 16))
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                HStack(spacing: 16) {
                    widget {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Streak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text("3").font(.system(size: 44, weight: .bold))
                            Text("days in a row").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(height: 110, alignment: .topLeading)
                    }
                    widget(BeanArt.color("Colombia")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Best").font(.caption.weight(.semibold)).opacity(0.8)
                            Text("4.5").font(.system(size: 44, weight: .bold))
                            Text("Inverted press").font(.caption)
                        }
                        .foregroundStyle(.white).frame(height: 110, alignment: .topLeading)
                    }
                }
            }
            .padding(20)
        }
        .background(C.board)
        .navigationTitle("Today")
    }
}

private struct Live39: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            VStack(spacing: 16) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).foregroundStyle(.primary)
                        .frame(width: 44, height: 44).background(C.widget, in: .circle)
                    Spacer()
                }
                widget(.black) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Next Cup", systemImage: "cup.and.saucer.fill").font(.caption).foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("9:40 – 9:43").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Label(s.kind.label, systemImage: s.kind.symbol).font(.title3)
                            Spacer()
                            Text(Fmt.clock(Int(elapsed))).font(.system(size: 44, weight: .semibold)).monospacedDigit().contentTransition(.numericText())
                        }
                        .foregroundStyle(.white)
                        ProgressView(value: elapsed, total: Double(r.totalS)).tint(.white)
                    }
                }
                widget(C.red) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Now").font(.caption.weight(.semibold)).opacity(0.8)
                        Text(s.instruction).font(.system(size: 28, weight: .bold))
                    }
                    .foregroundStyle(.white).frame(height: 170, alignment: .topLeading)
                }
                HStack(spacing: 16) {
                    widget {
                        Button { model.toggleTimer() } label: {
                            VStack(spacing: 8) {
                                Image(systemName: model.showsRunning ? "pause.fill" : "play.fill").font(.system(size: 34)).contentTransition(.symbolEffect(.replace))
                                Text(model.primaryTitle).font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110)
                        }
                        .foregroundStyle(.primary).buttonStyle(PressScale())
                    }
                    widget {
                        Button { model.finishBrew() } label: {
                            VStack(spacing: 8) { Image(systemName: "checkmark").font(.system(size: 34)); Text("Finish").font(.headline) }.frame(maxWidth: .infinity, minHeight: 110)
                        }
                        .foregroundStyle(.primary).buttonStyle(PressScale())
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(C.board.ignoresSafeArea())
        }
    }
}

private struct Log39: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    widget(BeanArt.color(model.draft.bean)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.draft.bean).font(.headline).foregroundStyle(.white)
                            LookRating(halfSteps: $model.draft.ratingHalfSteps, color: .white, size: 30)
                        }
                    }
                    widget {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 56)
                                    .foregroundStyle(on ? .white : .primary).background(on ? C.red : C.well, in: .rect(cornerRadius: 16))
                            }
                        }
                    }
                    HStack(spacing: 16) {
                        small("Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        small("Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                    }
                }
                .padding(20)
            }
            .background(C.board)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.red) }
            }
        }
    }

    private func small(_ k: String, _ v: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        widget {
            VStack(alignment: .leading, spacing: 6) {
                Text(k).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(v).font(.system(size: 30, weight: .bold)).monospacedDigit()
                HStack {
                    Button("Less \(k)", systemImage: "minus", action: st.down).frame(maxWidth: .infinity, minHeight: 44).background(C.well, in: .capsule)
                    Button("More \(k)", systemImage: "plus", action: st.up).frame(maxWidth: .infinity, minHeight: 44).background(C.well, in: .capsule)
                }
                .labelStyle(.iconOnly).foregroundStyle(.primary)
            }
        }
    }
}
