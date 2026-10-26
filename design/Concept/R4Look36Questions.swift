import SwiftUI

// 36. Questions (Starbucks order status + feedback). Organizing idea: a deep green header that
// tells you when your cup is ready, over cards that ask one question at a time ("Question 2
// of 3") with outlined chips, Next and Skip. The journal is a rewards-style header and orders.

private enum C {
    static let house = Color(0x1E3932, 0x1E3932)
    static let accent = Color(0x00704A, 0x2FB37E)
    static let page = Color(0xF2F0EB, 0x121212)
    static let card = Color(0xFFFFFF, 0x1F1F1F)
    static let gold = Color(0xCBA258, 0xCBA258)
}

private struct Chip: View {
    let title: String
    let on: Bool
    var body: some View {
        Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 40)
            .foregroundStyle(on ? .white : C.accent).background(on ? C.accent : .clear, in: .capsule)
            .overlay(Capsule().stroke(C.accent, lineWidth: 1.5)).frame(minHeight: 44)
    }
}

struct Look36: View {
    var body: some View {
        ConceptShell(tint: C.accent) { LookRecipe(model: $0) } timer: { Status36(model: $0) }
            log: { Ask36(model: $0) } journal: { Rewards36(model: $0) }
    }
}

private struct Rewards36: View {
    let model: FlowModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(model.journal.count)").font(.system(size: 54, weight: .bold)).monospacedDigit()
                        Image(systemName: "star.fill").foregroundStyle(C.gold)
                        Spacer()
                        Text("Cups logged").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }
                    ProgressView(value: Double(model.journal.count), total: 10).tint(C.gold)
                    Text("\(10 - model.journal.count) more cups to see your best recipe").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                .padding(20).foregroundStyle(.white).background(C.house, in: .rect(cornerRadius: 16))
                Text("Recent").font(.title3.weight(.bold)).padding(.top, 6)
                ForEach(Array(model.journal.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 14) {
                        Circle().fill(BeanArt.color(e.bean)).frame(width: 52, height: 52).overlay { Image(systemName: "cup.and.saucer.fill").foregroundStyle(.white) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.bean).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                            Text(e.method).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            Text(Fmt.day(e.date)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Brew again").font(.subheadline.weight(.semibold)).foregroundStyle(C.accent)
                            .padding(.horizontal, 12).frame(minHeight: 34).overlay(Capsule().stroke(C.accent, lineWidth: 1.5))
                    }
                    .padding(14).background(C.card, in: .rect(cornerRadius: 14)).accessibilityElement(children: .combine).assemble(i)
                }
            }
            .padding(16)
        }
        .background(C.page)
        .navigationTitle("Your cups")
    }
}

private struct Status36: View {
    let model: FlowModel

    var body: some View {
        TimerClock(model: model) { elapsed, index in
            let r = model.recipe
            let s = r.steps[index]
            let left = r.totalS - Int(elapsed)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button("Close", systemImage: "xmark") { model.showTimer = false }.labelStyle(.iconOnly).font(.headline)
                            .frame(width: 40, height: 40).background(.white.opacity(0.2), in: .circle).frame(width: 44, height: 44)
                    }
                    Text("Brewing your cup").font(.system(size: 30, weight: .bold))
                    Text("Ready around 9:43 AM (in \(left / 60) min \(left % 60) s)").font(.headline).monospacedDigit()
                    ProgressView(value: elapsed, total: Double(r.totalS)).tint(.white).padding(.top, 8)
                }
                .foregroundStyle(.white).padding(20).background(C.house.ignoresSafeArea(edges: .top))
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chevron.left").foregroundStyle(.secondary)
                            Text("Step \(index + 1) of \(r.steps.count)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(s.instruction).font(.title2.weight(.bold))
                        Text("Coming up").font(.subheadline).foregroundStyle(.secondary)
                        FlowLayout {
                            ForEach(r.steps.filter { $0.id > index }) { n in Chip(title: "\(n.kind.label) \(Fmt.clock(n.startS))", on: false) }
                        }
                        HStack(spacing: 18) {
                            Button(model.primaryTitle) { model.toggleTimer() }.font(.headline).foregroundStyle(.white).padding(.horizontal, 26).frame(minHeight: 48).background(C.accent, in: .capsule)
                            Button("Finish early") { model.finishBrew() }.font(.headline).foregroundStyle(C.accent)
                        }
                        .buttonStyle(PressScale())
                    }
                    .padding(20).background(C.card, in: .rect(cornerRadius: 16)).padding(16)
                }
            }
            .background(C.page.ignoresSafeArea())
        }
    }
}

private struct Ask36: View {
    @Bindable var model: FlowModel
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nice brew.").font(.system(size: 30, weight: .bold))
                    Text("\(model.draft.bean) · \(Fmt.clock(model.draft.timeS))").font(.headline).opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).padding(20).background(C.house)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Button("Back", systemImage: "chevron.left") { page = max(0, page - 1) }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(page == 0)
                            Text("Question \(page + 1) of 3").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Group {
                            switch page {
                            case 0:
                                Text("How did it taste?").font(.title2.weight(.bold))
                                Text("(Optional) Pick one.").font(.subheadline).foregroundStyle(.secondary)
                                FlowLayout {
                                    ForEach(Verdict.allCases) { v in
                                        Button { model.draft.verdict = model.draft.verdict == v ? nil : v } label: { Chip(title: v.label, on: model.draft.verdict == v) }
                                    }
                                }
                            case 1:
                                Text("How many stars?").font(.title2.weight(.bold))
                                LookRating(halfSteps: $model.draft.ratingHalfSteps, color: C.gold, size: 32)
                            default:
                                Text("Anything to remember?").font(.title2.weight(.bold))
                                TextField("Optional note", text: $model.draft.notes, axis: .vertical).lineLimit(3...6)
                                    .padding(12).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4)))
                            }
                        }
                        HStack(spacing: 22) {
                            Button(page == 2 ? "Save" : "Next") { if page == 2 { model.save() } else { page += 1 } }
                                .font(.headline).foregroundStyle(.white).padding(.horizontal, 26).frame(minHeight: 48).background(C.accent, in: .capsule)
                            Button("Skip") { if page == 2 { model.save() } else { page += 1 } }.font(.headline).foregroundStyle(C.accent)
                        }
                        .buttonStyle(PressScale())
                    }
                    .padding(20).background(C.card, in: .rect(cornerRadius: 16)).padding(16)
                    .animation(.spring(duration: 0.3), value: page)
                }
            }
            .background(C.page)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { model.showLog = false }.tint(.white) } }
            .toolbarBackground(C.house, for: .navigationBar).toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }
}
