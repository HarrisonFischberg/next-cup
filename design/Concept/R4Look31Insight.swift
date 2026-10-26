import SwiftUI

// 31. Insight (Oura). Organizing idea: the app speaks in one sentence with one highlighted word,
// over a smoky gradient, and a layered area chart is the proof. The journal leads with what
// your cups say; the timer draws the pour curve as it happens; the log reads as a sentence.

private enum C {
    static let gold = Color(0xA8741A, 0xF3D08A)
    static let fog = Color(0xE8E4DF, 0x1A1816)
    static let deep = Color(0xC9C1B8, 0x3A3029)
}

private struct Smoke: View {
    var body: some View {
        LinearGradient(colors: [C.deep, C.fog, C.fog], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}

/// A soft area chart: values 0...1 drawn as a filled curve.
private struct Area: Shape {
    var values: [Double]
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        let pts = values.enumerated().map { CGPoint(x: r.minX + r.width * Double($0.offset) / Double(values.count - 1), y: r.maxY - r.height * $0.element) }
        p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: pts[0])
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            p.addCurve(to: b, control1: CGPoint(x: (a.x + b.x) / 2, y: a.y), control2: CGPoint(x: (a.x + b.x) / 2, y: b.y))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

struct Look31: View {
    var body: some View {
        ConceptShell(tint: C.gold) { LookRecipe(model: $0) } timer: { Timer31(model: $0) }
            log: { Log31(model: $0) } journal: { Story31(model: $0) }
    }
}

private struct Story31: View {
    let model: FlowModel
    var body: some View {
        let ratings = model.journal.reversed().map { Double($0.ratingHalfSteps) / 10 }
        ScrollView {
            VStack(spacing: 22) {
                (Text("Your best cups land near ") + Text("94 °C").foregroundStyle(C.gold) + Text(", in about three minutes"))
                    .font(.system(size: 30, weight: .light)).multilineTextAlignment(.center).padding(.top, 20)
                HStack(spacing: 14) {
                    ForEach([("Low", 0.35), ("Medium", 0.6), ("High", 1.0)], id: \.0) { k, o in
                        HStack(spacing: 5) { Circle().fill(Color.primary.opacity(o)).frame(width: 10, height: 10); Text(k).font(.footnote) }
                    }
                }
                ZStack {
                    Area(values: ratings.map { $0 * 0.55 }).fill(Color.primary.opacity(0.25))
                    Area(values: ratings.map { $0 * 0.8 }).fill(Color.primary.opacity(0.35))
                    Area(values: ratings).fill(LinearGradient(colors: [Color.primary.opacity(0.9), Color.primary.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                }
                .frame(height: 170).accessibilityLabel("Ratings over the last \(ratings.count) cups")
                HStack { ForEach(["Oct 5", "Oct 8", "Oct 11", "Oct 13"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) } }
                Text("Kenya Kiambu AA scored highest twice. Sour cups came from coarser grinds, so one step finer is the safer bet next time.")
                    .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(0..<model.journal.count, id: \.self) { i in Capsule().fill(Color.primary.opacity(i == 0 ? 0.9 : 0.25)).frame(height: 3) }
                }
                .padding(.top, 10)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack {
                        Text(e.bean).font(.body)
                        Spacer()
                        Text(Fmt.day(e.date)).font(.subheadline).foregroundStyle(.secondary)
                        Text(Fmt.num(Double(e.ratingHalfSteps) / 2)).font(.body.weight(.medium)).monospacedDigit().frame(width: 34, alignment: .trailing)
                    }
                    .padding(.vertical, 6).accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Smoke())
        .navigationTitle("Insights").navigationBarTitleDisplayMode(.inline)
    }
}

private struct Timer31: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            // water in the cup at each sample up to now, poured evenly across each pour step
            let now = Int(elapsed / Double(r.totalS) * 36)
            let curve = (0...max(1, now)).map { k -> Double in
                let t = Double(k) * Double(r.totalS) / 36
                var g = 0.0
                for st in r.steps where Double(st.startS) <= t {
                    guard let target = st.cumulativeG else { continue }
                    let span = Double(r.endS(of: st) - st.startS)
                    g += (Double(target) - g) * min(1, (t - Double(st.startS)) / (span * 0.7))
                }
                return g / r.waterG
            }
            VStack(spacing: 18) {
                HStack {
                    Button("Close", systemImage: "chevron.down") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).frame(width: 44, height: 44)
                    Spacer()
                    Text(r.method.uppercased()).font(.caption.weight(.medium)).tracking(3)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                (Text("You're on the ") + Text("\(ordinal(index + 1)) step").foregroundStyle(C.gold) + Text(". \(s.instruction)"))
                    .font(.system(size: 28, weight: .light)).multilineTextAlignment(.center)
                Spacer()
                ZStack(alignment: .bottom) {
                    Area(values: (0...36).map { Double($0) / 36 * 0.95 }).fill(Color.primary.opacity(0.12))
                    GeometryReader { g in
                        Area(values: curve).fill(LinearGradient(colors: [Color.primary.opacity(0.85), Color.primary.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            .frame(width: g.size.width * Double(curve.count - 1) / 36)
                    }
                }
                .frame(height: 210).accessibilityHidden(true)
                HStack { Text("0:00"); Spacer(); Text("1:30"); Spacer(); Text("3:00") }.font(.caption).foregroundStyle(.secondary)
                Text(Fmt.clock(Int(elapsed))).font(.system(size: 60, weight: .thin)).monospacedDigit().contentTransition(.numericText())
                Spacer()
                HStack(spacing: 12) {
                    Button("Finish") { model.finishBrew() }.frame(maxWidth: .infinity, minHeight: 54).overlay(Capsule().stroke(Color.primary.opacity(0.4)))
                    Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 54).background(Color.primary, in: .capsule).foregroundStyle(C.fog)
                }
                .font(.headline).foregroundStyle(.primary).buttonStyle(PressScale())
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(Smoke())
        }
    }

    private func ordinal(_ n: Int) -> String { ["first", "second", "third", "fourth", "fifth", "sixth"][min(5, n - 1)] }
}

private struct Log31: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    (Text("This cup tasted ") + Text(model.draft.verdict?.label.lowercased() ?? "…").foregroundStyle(C.gold))
                        .font(.system(size: 32, weight: .light)).multilineTextAlignment(.center).padding(.top, 20)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 46)
                                .foregroundStyle(on ? C.fog : .primary).background(on ? Color.primary : Color.primary.opacity(0.06), in: .capsule)
                        }
                    }
                    (Text("and earned ") + Text(Fmt.stars(model.draft.ratingHalfSteps).lowercased()).foregroundStyle(C.gold))
                        .font(.system(size: 26, weight: .light))
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: .primary)
                    TextField("Anything to remember?", text: $model.draft.notes, axis: .vertical).font(.title3.weight(.light)).multilineTextAlignment(.center).lineLimit(2...5)
                }
                .padding(24)
            }
            .background(Smoke())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { model.save() } }
            }
        }
    }
}
