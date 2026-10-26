import SwiftUI

// 33. Sets (Bevel workout logger). Organizing idea: each pour is a "set" row with two value
// pills (grams, seconds) and a play button, rest chips between rows, and a floating mini player
// for the live step. Soft white cards on a pale grey canvas; numbers live in pills everywhere.

private enum C {
    static let canvas = Color(0xEEEFF1, 0x0C0C0D)
    static let card = Color(0xFFFFFF, 0x1B1B1D)
    static let pill = Color(0xF5F5F7, 0x262629)
    static let stroke = Color(0xDADBDF, 0x38383C)
    static let salmon = Color(0xE7624F, 0xFF8A78)
}

private struct ValuePill: View {
    let value: String
    let unit: String
    var body: some View {
        HStack(spacing: 4) {
            Text(value).font(.body.weight(.semibold)).monospacedDigit()
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(C.pill, in: .rect(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(C.stroke))
    }
}

struct Look33: View {
    var body: some View {
        ConceptShell(tint: C.salmon) { LookRecipe(model: $0) } timer: { Session33(model: $0) }
            log: { Log33(model: $0) } journal: { Cards33(model: $0) }
    }
}

private struct Cards33: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10).fill(BeanArt.color(e.bean).opacity(0.18)).frame(width: 44, height: 44)
                                .overlay { Image(systemName: "cup.and.saucer.fill").foregroundStyle(BeanArt.color(e.bean)) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.bean).font(.headline)
                                Text("\(e.method) • \(Fmt.day(e.date))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.subheadline.weight(.bold)).foregroundStyle(Color(.systemBackground))
                                .frame(width: 36, height: 28).background(Color.primary, in: .rect(cornerRadius: 8))
                        }
                        HStack(spacing: 8) {
                            ValuePill(value: Fmt.num(e.doseG), unit: "g")
                            ValuePill(value: Fmt.num(e.waterG), unit: "g")
                            ValuePill(value: Fmt.clock(e.timeS), unit: "")
                        }
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 22))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(C.canvas)
        .navigationTitle("Sessions")
    }
}

private struct Session33: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 34, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                                    Image(systemName: "pause.fill").foregroundStyle(.secondary)
                                }
                                Text(r.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Finish") { model.finishBrew() }.font(.headline).foregroundStyle(C.salmon).padding(.horizontal, 18).frame(minHeight: 44)
                                .background(C.salmon.opacity(0.15), in: .capsule)
                            Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).foregroundStyle(.primary)
                                .frame(width: 44, height: 44).background(C.card, in: .circle)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: "drop.fill").frame(width: 40, height: 40).background(C.pill, in: .rect(cornerRadius: 10))
                                VStack(alignment: .leading) { Text(r.method).font(.headline); Text("Dripper • \(r.steps.count) sets").font(.subheadline).foregroundStyle(.secondary) }
                                Spacer()
                                Image(systemName: "timer").foregroundStyle(Color(.systemBackground)).frame(width: 34, height: 34).background(Color.primary, in: .rect(cornerRadius: 8))
                            }
                            .padding(.bottom, 8)
                            ForEach(r.steps) { st in
                                HStack(spacing: 8) {
                                    Text("\(st.id + 1)").font(.subheadline.weight(.semibold)).frame(width: 30, height: 30).overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                                    ValuePill(value: st.cumulativeG.map(String.init) ?? "–", unit: "g")
                                    ValuePill(value: "\(r.endS(of: st) - st.startS)", unit: "s")
                                    Image(systemName: st.id < index ? "checkmark" : "play.fill").font(.subheadline.weight(.bold))
                                        .foregroundStyle(st.id < index ? Color(.systemBackground) : (st.id == index ? C.salmon : .primary))
                                        .frame(width: 36, height: 36).background(st.id < index ? Color.primary : .clear, in: .circle)
                                }
                                .opacity(st.id < index ? 0.55 : 1)
                                if st.id < r.steps.count - 1 {
                                    Text(Fmt.clock(r.endS(of: st))).font(.caption.weight(.semibold)).monospacedDigit().padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(C.card, in: .capsule).overlay(Capsule().stroke(C.stroke)).frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(16).background(C.card, in: .rect(cornerRadius: 24))
                    }
                    .padding(12).padding(.bottom, 90)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.kind.label + (s.cumulativeG.map { " to \($0) g" } ?? "")).font(.headline)
                        Text(Fmt.clock(r.endS(of: s) - Int(elapsed)) + " left").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Button(model.primaryTitle, systemImage: model.showsRunning ? "pause.fill" : "play.fill") { model.toggleTimer() }
                        .labelStyle(.iconOnly).font(.title2).foregroundStyle(.primary).frame(width: 52, height: 52).contentTransition(.symbolEffect(.replace))
                }
                .padding(.leading, 20).padding(.trailing, 8).padding(.vertical, 8)
                .lookGlass(nil, in: RoundedRectangle(cornerRadius: 28), fallback: C.card)
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
            .background(C.canvas.ignoresSafeArea())
        }
    }
}

private struct Log33: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Actuals").font(.headline)
                        edit("Dose", Fmt.num(model.draft.doseG), "g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        edit("Water", Fmt.num(model.draft.waterG), "g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        edit("Temp", Fmt.num(model.draft.tempC), "°C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rating").font(.headline)
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.salmon)
                        HStack(spacing: 6) {
                            ForEach(Verdict.allCases) { v in
                                let on = model.draft.verdict == v
                                Button(v.label) { model.draft.verdict = on ? nil : v }.font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(on ? .white : .primary).background(on ? Color.primary : C.pill, in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 24))
                }
                .padding(12)
            }
            .background(C.canvas)
            .navigationTitle(model.draft.bean).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.salmon) }
            }
        }
    }

    private func edit(_ k: String, _ v: String, _ u: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        HStack(spacing: 8) {
            Text(k).font(.subheadline).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 44, height: 44).background(C.pill, in: .circle)
            ValuePill(value: v, unit: u)
            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 44, height: 44).background(C.pill, in: .circle)
        }
        .labelStyle(.iconOnly).foregroundStyle(.primary).buttonStyle(PressScale(scale: 0.9))
    }
}
