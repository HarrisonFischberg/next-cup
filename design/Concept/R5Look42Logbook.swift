import SwiftUI

// 42. Logbook (Beanconqueror). Organizing idea: a tidy coffee logbook on warm grey. Four quiet
// stat tiles, then brews as white cards: a date block, the bean, a thin tan rule and a two-column
// label/value grid. The log is the same card filled in; the timer stays light and plain.

private enum C {
    static let bg = Color(0xF1EFEC, 0x121110)
    static let card = Color(0xFFFFFF, 0x1E1C1A)
    static let tan = Color(0xA9825E, 0xC9A27C)
    static let rule = Color(0xD9CBBE, 0x4A3E33)
}

private func labelValue(_ k: String, _ v: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(k).font(.caption).foregroundStyle(.secondary)
        Text(v).font(.subheadline).monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

struct Look42: View {
    var body: some View {
        ConceptShell(tint: C.tan) { LookRecipe(model: $0) } timer: { Timer42(model: $0) }
            log: { Log42(model: $0) } journal: { Overview42(model: $0) }
    }
}

private struct Overview42: View {
    let model: FlowModel
    @State private var tab = "Latest"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tile("\(model.journal.count)", "brews this fortnight")
                    tile("\(Int(model.journal.map(\.doseG).reduce(0, +)))g", "beans used")
                    tile(Fmt.num(Double(model.journal.map(\.ratingHalfSteps).reduce(0, +)) / Double(max(1, model.journal.count)) / 2), "average rating")
                    tile("4", "beans discovered")
                }
                HStack(spacing: 40) {
                    ForEach(["Latest", "Archive"], id: \.self) { t in
                        Button(t) { tab = t }.font(.body.weight(tab == t ? .medium : .regular)).foregroundStyle(tab == t ? .primary : .secondary)
                            .frame(minHeight: 44).overlay(alignment: .bottom) { if tab == t { Rectangle().fill(Color.primary).frame(height: 1.5) } }
                    }
                }
                .padding(.top, 4)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Text(e.date.formatted(.dateTime.day())).font(.system(.title2, design: .rounded)).foregroundStyle(C.tan)
                            Text(e.date.formatted(.dateTime.month(.abbreviated))).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 44).padding(.top, 2)
                        Rectangle().fill(C.rule).frame(width: 1)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(e.bean).font(.system(.headline, design: .rounded, weight: .regular))
                                Spacer()
                                HStack(spacing: 1) {
                                    ForEach(1...5, id: \.self) { s in Image(systemName: e.ratingHalfSteps >= s * 2 ? "star.fill" : (e.ratingHalfSteps == s * 2 - 1 ? "star.leadinghalf.filled" : "star")) }
                                }
                                .font(.caption2).foregroundStyle(C.tan)
                            }
                            HStack { labelValue("Method", e.method); labelValue("Ratio", "\(Fmt.num(e.doseG))g / \(Fmt.num(e.waterG))g") }
                            HStack { labelValue("Grind", "\(e.grind)"); labelValue("Brew time", Fmt.clock(e.timeS)) }
                        }
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 14))
                    .accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(C.bg)
        .navigationTitle("Overview")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Log a brew", systemImage: "plus") { model.prefillFromRecipe(measuredS: 180); model.showLog = true } } }
    }

    private func tile(_ v: String, _ k: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.system(.title2, design: .rounded)).foregroundStyle(C.tan).monospacedDigit()
            Text(k).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 76).background(C.card, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct Timer42: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44).foregroundStyle(.primary)
                    Spacer()
                    Text(r.method).font(.system(.headline, design: .rounded, weight: .regular))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                VStack(spacing: 6) {
                    Text(Fmt.clock(Int(elapsed))).font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                    Text("\(Int(pouredGrams(r, at: elapsed))) g of \(Fmt.num(r.waterG)) g").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    ProgressView(value: elapsed, total: Double(r.totalS)).tint(C.tan).padding(.top, 8)
                }
                .padding(20).frame(maxWidth: .infinity).background(C.card, in: .rect(cornerRadius: 14))
                VStack(spacing: 0) {
                    ForEach(r.steps) { s in
                        HStack(spacing: 14) {
                            Text(Fmt.clock(s.startS)).font(.subheadline).monospacedDigit().foregroundStyle(s.id == index ? C.tan : .secondary).frame(width: 44, alignment: .leading)
                            Text(s.instruction).font(.subheadline.weight(s.id == index ? .medium : .regular)).foregroundStyle(s.id < index ? .secondary : .primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 52)
                        .background(s.id == index ? C.tan.opacity(0.12) : .clear)
                        .overlay(alignment: .leading) { if s.id == index { Rectangle().fill(C.tan).frame(width: 3) } }
                    }
                }
                .background(C.card, in: .rect(cornerRadius: 14)).clipShape(.rect(cornerRadius: 14))
                Spacer()
                HStack(spacing: 12) {
                    Button("Finish") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 52).background(C.card, in: .capsule).foregroundStyle(.primary)
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 52).background(C.tan, in: .capsule).foregroundStyle(.white)
                }
                .font(.headline).buttonStyle(PressScale())
            }
            .padding(16)
            .background(C.bg.ignoresSafeArea())
        }
    }
}

private struct Log42: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.draft.bean).font(.system(.title3, design: .rounded))
                        Rectangle().fill(C.rule).frame(height: 1)
                        field("Dose", "\(Fmt.num(model.draft.doseG)) g", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                        field("Water", "\(Fmt.num(model.draft.waterG)) g", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                        field("Temperature", "\(Fmt.num(model.draft.tempC)) °C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                        HStack { labelValue("Brew time", Fmt.clock(model.draft.timeS)); labelValue("Grind", "\(model.draft.grind)") }
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating").font(.caption).foregroundStyle(.secondary)
                        LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.tan)
                        Text("Taste").font(.caption).foregroundStyle(.secondary)
                        Picker("Taste", selection: $model.draft.verdict) {
                            Text("–").tag(Verdict?.none)
                            ForEach(Verdict.allCases) { Text($0.label).tag(Verdict?.some($0)) }
                        }
                        .pickerStyle(.segmented)
                        TextField("Notes", text: $model.draft.notes, axis: .vertical).lineLimit(2...5)
                    }
                    .padding(16).background(C.card, in: .rect(cornerRadius: 14))
                }
                .padding(16)
            }
            .background(C.bg)
            .navigationTitle("Add brew").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() }.buttonStyle(.glassProminent).tint(C.tan) }
            }
        }
    }

    private func field(_ k: String, _ v: String, _ st: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Text(k).font(.subheadline).foregroundStyle(Color.secondary)
            Spacer()
            Button("Less \(k)", systemImage: "minus", action: st.down).frame(width: 44, height: 44).foregroundStyle(C.tan)
            Text(v).font(.body).monospacedDigit().frame(minWidth: 70)
            Button("More \(k)", systemImage: "plus", action: st.up).frame(width: 44, height: 44).foregroundStyle(C.tan)
        }
        .labelStyle(.iconOnly)
    }
}
