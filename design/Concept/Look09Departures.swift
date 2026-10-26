import SwiftUI

// 9. Departures. A split-flap station board: every character sits on its own flap tile,
// amber on black, condensed caps. The journal is a departures list; the timer is the
// boarding board with the live step "NOW BOARDING". Glass buttons are the station's
// glass push panels. Light mode is a daylight platform sign, black flaps on white.

private enum S {
    static let bg = Color(0xE8E6E1, 0x0A0A0A)
    static let board = Color(0x1A1A1A, 0x161616)
    static let flap = Color(0x2A2A2A, 0x232323)
    static let amber = Color(0xFFB000, 0xFFB000)
    static let white = Color(0xF2F2F2, 0xF2F2F2)
    static let dim = Color(0x9A9A9A, 0x8A8A8A)
    static let ink = Color(0x111111, 0xF2F2F2)
    static let green = Color(0x48D06A, 0x48D06A)
    static let onAmber = Color(0x111111, 0x111111)
    static func cond(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font {
        .custom("DINCondensed-Bold", size: size, relativeTo: style)
    }
}

/// One split-flap tile per character, with the hinge line across the middle.
private struct Flaps: View {
    let text: String
    var size: CGFloat = 22
    var color = S.amber
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, ch in
                Text(String(ch)).font(S.cond(size)).foregroundStyle(color)
                    .frame(width: size * 0.72, height: size * 1.25)
                    .background(S.flap, in: .rect(cornerRadius: 2))
                    .overlay(Rectangle().fill(.black.opacity(0.6)).frame(height: 1))
            }
        }
        .accessibilityElement().accessibilityLabel(text)
    }
}

struct Look09: View {
    var body: some View {
        ConceptShell(tint: S.amber) { LookRecipe(model: $0) } timer: { Timer09(model: $0) }
            log: { Log09(model: $0) } journal: { Journal09(model: $0) }
    }
}

private struct Journal09: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill").font(.title)
                    Text("DEPARTURES").font(S.cond(40, .largeTitle))
                }
                .foregroundStyle(S.ink)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("BEAN").frame(maxWidth: .infinity, alignment: .leading)
                        Text("RATIO").frame(width: 66, alignment: .leading)
                        Text("RATE").frame(width: 46, alignment: .leading)
                    }
                    .font(S.cond(14)).foregroundStyle(S.dim)
                    ForEach(model.journal) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Flaps(text: String(e.bean.split(separator: " ").first ?? ""), size: 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Flaps(text: Fmt.num(e.ratio), size: 20, color: S.white).frame(width: 66, alignment: .leading)
                                Flaps(text: Fmt.num(Double(e.ratingHalfSteps) / 2), size: 20, color: S.white).frame(width: 46, alignment: .leading)
                            }
                            Text("\(e.method.uppercased()) · \(Fmt.day(e.date).uppercased())  \(e.verdict.map { "· \($0.label.uppercased())" } ?? "")")
                                .font(S.cond(15)).foregroundStyle(e.verdict == .balanced ? S.green : S.dim)
                        }
                        .accessibilityElement(children: .combine)
                        Rectangle().fill(S.flap).frame(height: 1)
                    }
                }
                .padding(14).background(S.board, in: .rect(cornerRadius: 10))
            }
            .padding(16)
        }
        .background(S.bg)
    }
}

private struct Timer09: View {
    let model: FlowModel
    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly)
                        .font(.title3.weight(.bold)).foregroundStyle(S.ink).frame(width: 48, height: 48)
                        .lookGlass(nil, in: .rect(cornerRadius: 10), fallback: S.bg)
                    Spacer()
                    Text("PLATFORM 1 · \(r.method.uppercased())").font(S.cond(18)).foregroundStyle(S.ink)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Flaps(text: Fmt.clock(Int(elapsed)), size: 74)
                        .frame(maxWidth: .infinity)
                    ForEach(r.steps) { s in
                        let live = s.id == index, gone = s.id < index
                        HStack(spacing: 10) {
                            Text(Fmt.clock(s.startS)).font(S.cond(20)).foregroundStyle(gone ? S.dim : S.white).frame(width: 46, alignment: .leading)
                            Text(s.kind.label.uppercased()).font(S.cond(22)).foregroundStyle(live ? S.amber : (gone ? S.dim : S.white))
                            Spacer()
                            Text(s.cumulativeG.map { "\($0) G" } ?? "").font(S.cond(20)).foregroundStyle(gone ? S.dim : S.white)
                            Text(live ? "NOW BOARDING" : (gone ? "DEPARTED" : "ON TIME"))
                                .font(S.cond(14)).foregroundStyle(live ? S.onAmber : (gone ? S.dim : S.green))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(live ? S.amber : .clear, in: .rect(cornerRadius: 3))
                                .frame(width: 104, alignment: .trailing)
                        }
                        if live {
                            Text(s.instruction.uppercased()).font(S.cond(18)).foregroundStyle(S.amber).padding(.leading, 56)
                        }
                    }
                }
                .padding(16).background(S.board, in: .rect(cornerRadius: 12))
                Spacer()
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.primaryTitle.uppercased()) { model.toggleTimer() }.font(S.cond(28)).foregroundStyle(S.onAmber)
                            .frame(maxWidth: .infinity, minHeight: 66).lookGlass(S.amber, in: .rect(cornerRadius: 12), fallback: S.amber)
                        Button("ARRIVE") { model.finishBrew() }.font(S.cond(26)).foregroundStyle(S.ink)
                            .frame(maxWidth: .infinity, minHeight: 66).lookGlass(nil, in: .rect(cornerRadius: 12), fallback: S.bg)
                    }
                }
            }
            .padding(16)
            .background(S.bg)
        }
    }
}

private struct Log09: View {
    @Bindable var model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ARRIVAL REPORT").font(S.cond(38, .largeTitle)).foregroundStyle(S.ink)
                VStack(alignment: .leading, spacing: 14) {
                    Flaps(text: String(model.draft.bean.prefix(14)), size: 22)
                    row("DOSE", "\(Fmt.num(model.draft.doseG))G", $model.draft.doseG.stepped(by: 0.5, in: 1...100))
                    row("WATER", "\(Fmt.num(model.draft.waterG))G", $model.draft.waterG.stepped(by: 5, in: 10...1000))
                    row("TEMP", "\(Fmt.num(model.draft.tempC))C", $model.draft.tempC.stepped(by: 1, in: 50...100))
                    LookRating(halfSteps: $model.draft.ratingHalfSteps, color: S.amber)
                }
                .padding(14).background(S.board, in: .rect(cornerRadius: 12))
                FlowLayout {
                    ForEach(Verdict.allCases) { v in
                        let on = model.draft.verdict == v
                        Button(v.label.uppercased()) { model.draft.verdict = on ? nil : v }
                            .font(S.cond(20)).foregroundStyle(on ? S.onAmber : S.ink)
                            .padding(.horizontal, 14).frame(minHeight: 46)
                            .background(on ? S.amber : .clear, in: .rect(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(S.ink.opacity(0.5)))
                            .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Button("FILE REPORT") { model.save() }.font(S.cond(28)).foregroundStyle(S.onAmber)
                    .frame(maxWidth: .infinity, minHeight: 64).lookGlass(S.amber, in: .rect(cornerRadius: 12), fallback: S.amber)
            }
            .padding(16)
        }
        .background(S.bg)
    }

    private func row(_ k: String, _ v: String, _ step: (down: () -> Void, up: () -> Void)) -> some View {
        HStack {
            Text(k).font(S.cond(18)).foregroundStyle(S.dim).frame(width: 64, alignment: .leading)
            Flaps(text: v, size: 26, color: S.white)
            Spacer()
            Button("Less \(k.lowercased())", systemImage: "chevron.down", action: step.down).frame(width: 46, height: 46)
                .background(S.flap, in: .rect(cornerRadius: 6))
            Button("More \(k.lowercased())", systemImage: "chevron.up", action: step.up).frame(width: 46, height: 46)
                .background(S.flap, in: .rect(cornerRadius: 6))
        }
        .labelStyle(.iconOnly).font(.title3.weight(.bold)).foregroundStyle(S.amber)
    }
}
