import SwiftUI

// 40. Storybook (Tolan journal). Organizing idea: the journal is a book of illustrated pages on
// cream paper; each cup gets a drawn scene (hills, sun, steam) in its bean's colours, a serif
// excerpt and a byline. The timer turns pages, one step per page; the log is a blank page.

private enum C {
    static let cream = Color(0xFAF6EC, 0x1A1712)
    static let card = Color(0xFFFFFF, 0x24201A)
    static let ink = Color(0x2B2620, 0xEDE6D8)
    static let new = Color(0x7BC043, 0x8ED357)
}

/// A small flat illustration built from shapes; `level` raises the coffee line.
private struct Scene: View {
    let tint: Color
    var level: Double = 0.4
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: [tint.mix(with: .white, by: 0.55), tint.mix(with: .orange, by: 0.25)], startPoint: .top, endPoint: .bottom)
                Circle().fill(.white.opacity(0.75)).frame(width: w * 0.22).position(x: w * 0.78, y: h * 0.28)
                Ellipse().fill(tint.mix(with: .black, by: 0.15)).frame(width: w * 1.3, height: h * 0.7).position(x: w * 0.25, y: h * 1.02)
                Ellipse().fill(tint.mix(with: .black, by: 0.35)).frame(width: w * 1.1, height: h * 0.55).position(x: w * 0.85, y: h * 1.08)
                // the cup
                UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26).fill(.white)
                    .frame(width: w * 0.3, height: h * 0.34).position(x: w * 0.42, y: h * 0.6)
                Rectangle().fill(Color(0x5A3A24, 0x5A3A24)).frame(width: w * 0.3 - 10, height: h * 0.3 * level)
                    .position(x: w * 0.42, y: h * 0.6 + h * 0.15 - h * 0.15 * level)
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(.white.opacity(0.7)).frame(width: 5, height: h * 0.12).rotationEffect(.degrees(Double(i - 1) * 10))
                        .position(x: w * (0.36 + 0.06 * Double(i)), y: h * 0.32)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct Look40: View {
    var body: some View {
        ConceptShell(tint: C.new) { LookRecipe(model: $0) } timer: { Pages40(model: $0) }
            log: { Page40(model: $0) } journal: { Book40(model: $0) }
    }
}

private struct Book40: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    VStack(alignment: .leading, spacing: 0) {
                        Scene(tint: BeanArt.color(e.bean), level: Double(e.ratingHalfSteps) / 10).frame(height: 180)
                            .overlay(alignment: .topLeading) {
                                if i == 0 {
                                    Text("NEW!").font(.caption.weight(.heavy)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(C.new, in: .rect(cornerRadius: 6)).padding(12)
                                }
                            }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The \(e.bean) came out \(e.verdict?.label.lowercased() ?? "fine"). \(e.note)")
                                .font(.system(.body, design: .serif)).foregroundStyle(C.ink).lineLimit(3)
                            HStack { Text("\(e.method)"); Spacer(); Text(e.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) }
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                    .background(C.card).clipShape(.rect(cornerRadius: 16)).shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                    .accessibilityElement(children: .combine).assemble(i)
                }
                Text("THAT'S ALL SO FAR").font(.subheadline.weight(.bold)).tracking(1).foregroundStyle(.secondary.opacity(0.6)).padding(.vertical, 20)
            }
            .padding(.horizontal, 16)
        }
        .background(C.cream)
        .navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
    }
}

private struct Pages40: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let g = Double(r.steps[...index].compactMap(\.cumulativeG).last ?? 0)
            VStack(spacing: 20) {
                HStack {
                    Button("Close", systemImage: "chevron.left") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                    Spacer()
                    Text("Page \(index + 1) of \(r.steps.count)").font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
                    Spacer()
                    Text(Fmt.clock(Int(elapsed))).font(.subheadline.monospacedDigit()).frame(width: 44)
                }
                .foregroundStyle(C.ink)
                Scene(tint: BeanArt.color(model.draft.bean), level: g / r.waterG).frame(height: 300).clipShape(.rect(cornerRadius: 20))
                    .animation(.spring(duration: 0.6), value: index)
                Text(s.instruction).font(.system(size: 30, design: .serif)).foregroundStyle(C.ink).multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                if let n = model.nextStep(after: index) {
                    Text("Next, at \(Fmt.clock(n.startS)): \(n.kind.label.lowercased()).").font(.system(.body, design: .serif)).italic().foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(r.steps) { st in Circle().fill(st.id == index ? C.ink : Color.secondary.opacity(0.3)).frame(width: 7, height: 7) }
                }
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    Button("The end") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 54).overlay(Capsule().stroke(C.ink.opacity(0.4)))
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 54).background(C.ink, in: .capsule).foregroundStyle(C.cream)
                }
                .font(.system(.headline, design: .serif)).foregroundStyle(C.ink).buttonStyle(PressScale())
            }
            .padding(20)
            .background(C.cream.ignoresSafeArea())
        }
    }
}

private struct Page40: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Scene(tint: BeanArt.color(model.draft.bean), level: Double(model.draft.ratingHalfSteps) / 10).frame(height: 150).clipShape(.rect(cornerRadius: 16))
                    Text(SampleData.today.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.caption).foregroundStyle(.secondary)
                    Text("Today's \(BeanArt.origin(model.draft.bean))…").font(.system(size: 30, design: .serif)).foregroundStyle(C.ink)
                    TextField("tasted of… and next time I'll…", text: $model.draft.notes, axis: .vertical)
                        .font(.system(.title3, design: .serif)).lineLimit(4...10).foregroundStyle(C.ink)
                    Divider()
                    HStack {
                        Text("How full was the cup?").font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.ink, size: 24)
                    HStack(spacing: 6) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label.lowercased()) { model.draft.verdict = on ? nil : v }.font(.system(.subheadline, design: .serif)).italic()
                                .padding(.horizontal, 10).frame(minHeight: 44).foregroundStyle(on ? C.cream : C.ink).background(on ? C.ink : .clear, in: .capsule)
                        }
                    }
                }
                .padding(24)
            }
            .background(C.cream)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "chevron.left") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Keep page") { model.save() }.buttonStyle(.glassProminent).tint(C.ink) }
            }
        }
    }
}
