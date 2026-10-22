import SwiftUI

/// The navigation frame every concept shares: two tabs (Journal, Recipes), the
/// guided timer as a full-screen cover, the log form as a sheet, and an Undo
/// toast after saving. System navigation and modality stay platform-standard
/// (HIG); each concept supplies the four screens and its own tint.
struct ConceptShell<RV: View, TV: View, LV: View, JV: View>: View {
    @State private var model = FlowModel()
    let tint: Color
    let appearance: () -> Void
    let recipeScreen: (FlowModel) -> RV
    let timerScreen: (FlowModel) -> TV
    let logScreen: (FlowModel) -> LV
    let journalScreen: (FlowModel) -> JV

    init(tint: Color,
         appearance: @escaping () -> Void = {},
         @ViewBuilder recipe: @escaping (FlowModel) -> RV,
         @ViewBuilder timer: @escaping (FlowModel) -> TV,
         @ViewBuilder log: @escaping (FlowModel) -> LV,
         @ViewBuilder journal: @escaping (FlowModel) -> JV) {
        self.tint = tint
        self.appearance = appearance
        self.recipeScreen = recipe
        self.timerScreen = timer
        self.logScreen = log
        self.journalScreen = journal
        appearance()
    }

    var body: some View {
        TabView(selection: $model.tab) {
            Tab("Journal", systemImage: "book.closed", value: AppTab.journal) {
                NavigationStack { journalScreen(model) }
            }
            Tab("Recipes", systemImage: "cup.and.saucer", value: AppTab.recipes) {
                NavigationStack { recipeScreen(model) }
            }
        }
        .tint(tint)
        .fullScreenCover(isPresented: $model.showTimer) { timerScreen(model).tint(tint) }
        .sheet(isPresented: $model.showLog) { logScreen(model).tint(tint) }
        .overlay(alignment: .bottom) { toast }
        .tint(tint)
        .sensoryFeedback(.success, trigger: model.journal.count)
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            model.applyLaunchStage()
        }
    }

    @ViewBuilder private var toast: some View {
        if let saved = model.lastSaved {
            HStack(spacing: 16) {
                Text("Saved \(saved.bean)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Undo") { withAnimation { model.undoSave() } }
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: .rect(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.bottom, 64)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: saved.id) {
                try? await Task.sleep(for: .seconds(7))
                withAnimation { model.dismissToast() }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Wraps the running timer: re-renders about four times a second while
/// running and fires one haptic per step change.
struct TimerClock<Content: View>: View {
    let model: FlowModel
    @ViewBuilder let content: (_ elapsed: TimeInterval, _ stepIndex: Int) -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let elapsed = model.elapsed(at: context.date)
            let index = model.stepIndex(at: elapsed)
            content(elapsed, index)
                .sensoryFeedback(.impact(weight: .medium), trigger: index)
        }
    }
}

/// Half-step rating helpers shared by every concept's rating control.
extension BrewDraft {
    mutating func setRating(_ halfSteps: Int) {
        ratingHalfSteps = ratingHalfSteps == halfSteps ? 0 : min(10, max(0, halfSteps))
    }
}

extension Binding where Value == Double {
    /// Steps a Double by `step`, clamped; used by every concept's stepper.
    func stepped(by step: Double, in range: ClosedRange<Double>) -> (down: () -> Void, up: () -> Void) {
        ({ wrappedValue = Swift.max(range.lowerBound, wrappedValue - step) },
         { wrappedValue = Swift.min(range.upperBound, wrappedValue + step) })
    }
}
