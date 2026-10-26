import SwiftUI

// 28. Route (Lyft ride + rating). Organizing idea: a brew is a trip. The timer draws the recipe
// as a route with a stop for every step and the cup moving along it, under a ride sheet with
// the ETA; the journal is past trips; the log is the end-of-ride rating.

private enum C {
    static let brand = Color(0x7A1FA2, 0xC07BE0)
    static let star = Color(0xF29A1F, 0xF5A93A)
    static let map = Color(0xEEF0F2, 0x1C1E22)
    static let road = Color(0xFFFFFF, 0x2E3138)
    static let page = Color(0xFFFFFF, 0x111214)
}

/// Stops laid on a winding path; fraction 0...1 places the marker.
private struct RouteMap: View {
    let stops: Int
    let fraction: Double
    let index: Int

    private func point(_ t: Double, _ s: CGSize) -> CGPoint {
        CGPoint(x: s.width * (0.15 + 0.7 * (0.5 + 0.5 * sin(t * .pi * 2.2))), y: s.height * (0.9 - 0.8 * t))
    }

    var body: some View {
        GeometryReader { g in
            let size = g.size
            ZStack {
                ForEach(0..<9, id: \.self) { i in
                    Rectangle().fill(C.road).frame(height: 10).rotationEffect(.degrees(i.isMultiple(of: 2) ? 18 : -24))
                        .offset(y: CGFloat(i) * 90 - 360)
                }
                Path { p in
                    p.move(to: point(0, size))
                    for k in 1...60 { p.addLine(to: point(Double(k) / 60, size)) }
                }
                .stroke(C.brand.opacity(0.3), style: .init(lineWidth: 7, lineCap: .round))
                Path { p in
                    p.move(to: point(0, size))
                    for k in 1...60 where Double(k) / 60 <= fraction { p.addLine(to: point(Double(k) / 60, size)) }
                }
                .stroke(C.brand, style: .init(lineWidth: 7, lineCap: .round))
                ForEach(0..<stops, id: \.self) { i in
                    Circle().fill(i <= index ? C.brand : C.page).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(C.brand, lineWidth: 3)).position(point(Double(i) / Double(stops), size))
                }
                Image(systemName: "cup.and.saucer.fill").font(.title3).foregroundStyle(.white).frame(width: 40, height: 40)
                    .background(Color.primary, in: .circle).shadow(radius: 6, y: 3).position(point(fraction, size))
            }
            .clipped()
        }
        .background(C.map)
        .accessibilityHidden(true)
    }
}

struct Look28: View {
    var body: some View {
        ConceptShell(tint: C.brand) { LookRecipe(model: $0) } timer: { Ride28(model: $0) }
            log: { Rate28(model: $0) } journal: { Trips28(model: $0) }
    }
}

private struct Trips28: View {
    let model: FlowModel
    var body: some View {
        List(Array(model.journal.enumerated()), id: \.element.id) { i, e in
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Circle().stroke(C.brand, lineWidth: 2.5).frame(width: 10, height: 10)
                    Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 2, height: 20)
                    Rectangle().fill(C.brand).frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(e.method) · bloom 0:00").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(e.bean) · done \(Fmt.clock(e.timeS))").font(.body.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Fmt.day(e.date)).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 2) { Image(systemName: "star.fill").foregroundStyle(C.star); Text(Fmt.num(Double(e.ratingHalfSteps) / 2)) }.font(.subheadline.weight(.semibold))
                }
            }
            .padding(.vertical, 6).accessibilityElement(children: .combine).assemble(i)
        }
        .listStyle(.plain)
        .navigationTitle("Your brews")
    }
}

private struct Ride28: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            ZStack(alignment: .bottom) {
                RouteMap(stops: r.steps.count, fraction: elapsed / Double(r.totalS), index: index).ignoresSafeArea()
                VStack {
                    HStack {
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline).foregroundStyle(.primary)
                            .frame(width: 48, height: 48).background(C.page, in: .circle).shadow(radius: 4, y: 2)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(16)
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 5).frame(maxWidth: .infinity)
                    Text(s.instruction).font(.title2.weight(.bold))
                    HStack {
                        Text("Done at 9:43 AM").font(.subheadline.weight(.semibold))
                        Text("· \(Fmt.clock(r.totalS - Int(elapsed))) left").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    if let n = model.nextStep(after: index) {
                        Label("Next: \(n.kind.label) at \(Fmt.clock(n.startS))", systemImage: n.kind.symbol).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button("End") { model.finishBrew() }.frame(width: 96, height: 56).background(Color.secondary.opacity(0.15), in: .capsule).foregroundStyle(.primary)
                        Button(model.primaryTitle) { model.toggleTimer() }.frame(maxWidth: .infinity, minHeight: 56).background(C.brand, in: .capsule).foregroundStyle(.white)
                    }
                    .font(.headline).buttonStyle(PressScale())
                }
                .padding(20).padding(.bottom, 10)
                .background(C.page, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

private struct Rate28: View {
    @Bindable var model: FlowModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How was your \(model.draft.bean)?").font(.system(size: 30, weight: .heavy))
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.star, size: 34)
                    Text(["Rate it", "Bad", "Poor", "Okay", "Good", "Great"][(model.draft.ratingHalfSteps + 1) / 2]).font(.title3.weight(.bold)).foregroundStyle(.secondary)
                    Text("What went well?").font(.title3.weight(.heavy))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Verdict.allCases) { v in
                            let on = model.draft.verdict == v
                            Button(v.label) { model.draft.verdict = on ? nil : v }.font(.subheadline.weight(.bold)).frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(on ? .white : C.brand).background(on ? C.brand : C.brand.opacity(0.12), in: .rect(cornerRadius: 10))
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading) { Text("Your dose").font(.title3.weight(.heavy)); Text("\(Fmt.num(model.draft.doseG)) g into \(Fmt.num(model.draft.waterG)) g").foregroundStyle(.secondary) }
                        Spacer()
                        let st = $model.draft.doseG.stepped(by: 0.5, in: 1...100)
                        Button("Less", systemImage: "minus", action: st.down).frame(width: 44, height: 44).background(Color.secondary.opacity(0.12), in: .circle)
                        Button("More", systemImage: "plus", action: st.up).frame(width: 44, height: 44).background(Color.secondary.opacity(0.12), in: .circle)
                    }
                    .labelStyle(.iconOnly).foregroundStyle(.primary)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Send") { model.save() }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                    .background(C.brand, in: .capsule).buttonStyle(PressScale()).padding(.horizontal, 20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false } } }
        }
    }
}
