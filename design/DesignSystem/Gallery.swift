import SwiftUI

/// Every design-system component in every state, in one scroll. Launch the
/// concept app with `-gallery` to see it. This is the system's visual check:
/// screenshot it in light, dark and the largest text size.
struct Gallery: View {
    @State private var grade = 7
    @State private var verdict: String? = "Balanced"
    @Environment(\.dynamicTypeSize) private var dts

    /// `-galleryGroup "Value entry"` scrolls to a group, for repeatable screenshots.
    private var startGroup: String? {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-galleryGroup").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                Text("STEEL & KRAFT").font(DS.Font.display).foregroundStyle(DS.ink)

                group("Buttons") {
                    SteelButton(title: "Start brew") {}
                    SteelButton(title: "End + log", kind: .secondary) {}
                    SteelButton(title: "Save brew", isLoading: true) {}
                    SteelButton(title: "Save brew") {}.disabled(true)
                }
                group("Spec grid") {
                    PaperBox {
                        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                            GridRow { SpecCell(label: "Dose", value: "20 g"); Rectangle().fill(DS.line).frame(width: DS.rule); SpecCell(label: "Water", value: "320 g") }
                            Hairline()
                            GridRow { SpecCell(label: "Ratio", value: "1:16"); Rectangle().fill(DS.line).frame(width: DS.rule); SpecCell(label: "Temp", value: "94 °C") }
                        }
                    }
                }
                group("Operation table") {
                    VStack(spacing: 0) {
                        ColumnHeader(leading: "T+", middle: "Operation", trailing: "Scale")
                        OperationRow(time: "0:00", name: "Bloom", instruction: "Wet every bit of the grounds.", scale: "60 g", state: .done)
                        OperationRow(time: "0:45", name: "Pour", instruction: "Pour to 160 g.", scale: "160 g", state: .live)
                        OperationRow(time: "1:15", name: "Pour", instruction: "Pour to 240 g.", scale: "240 g")
                    }
                    .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
                }
                group("Instrument panel") {
                    InstrumentPanel {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text("ELAPSED").font(DS.Font.label).foregroundStyle(DS.onSteel.opacity(0.75))
                            Text("1:18").font(DS.Font.readout).dynamicTypeSize(...DS.readoutCap)
                                .minimumScaleFactor(0.4).lineLimit(1).foregroundStyle(DS.onSteel)
                            ReadoutBar(fraction: 0.43)
                        }
                    }
                }
                group("Value entry") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dts.isAccessibilitySize ? 300 : 150), spacing: DS.Space.md)], spacing: DS.Space.md) {
                        StepperTile(title: "Dose", value: "20", unit: "g", target: "20 g", down: {}, up: {})
                        StepperTile(title: "Time", value: "3:04", target: "3:00", down: {}, up: {})
                        ReadoutTile(title: "Ratio", value: "1:16")
                    }
                    GradeScale(halfSteps: $grade)
                }
                group("Choices") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dts.isAccessibilitySize ? 300 : 100), spacing: DS.Space.sm)], spacing: DS.Space.sm) {
                        ForEach(["Sour", "Bitter", "Weak", "Strong", "Balanced"], id: \.self) { v in
                            ChoiceButton(title: v, isSelected: verdict == v) { verdict = verdict == v ? nil : v }
                        }
                    }
                }
                group("Notes and grades") {
                    KraftNote { Text("Sour or thin: grind one step finer.").font(DS.Font.note).foregroundStyle(DS.onKraft) }
                    HStack(spacing: DS.Space.sm) { GradeBadge(halfSteps: 8); GradeBadge(halfSteps: 7); GradeBadge(halfSteps: 0) }
                }
                group("Feedback") {
                    SteelToast(message: "Saved Kenya Kiambu AA", actionTitle: "Undo") {}
                    StateBanner(kind: .error, message: "Couldn't save. Your entry is kept.", actionTitle: "Retry") {}
                    StateBanner(kind: .offline, message: "Offline. The AI request is queued.", actionTitle: "Cancel") {}
                    StateBanner(kind: .info, message: "Nothing is sent without your key and a tap.")
                }
                group("Empty and loading") {
                    PaperBox { EmptyState(title: "No brews yet", message: "Log your first brew to start the journal.", actionTitle: "Log a brew") {} }
                    SkeletonRow()
                }
            }
            .padding(DS.Space.lg)
        }
        .background(DS.bg)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            if let g = startGroup { proxy.scrollTo(g, anchor: .top) }
        }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text(title.uppercased()).font(DS.Font.din(22, relativeTo: .title3)).foregroundStyle(DS.ink)
            content()
        }
        .id(title)
    }
}
