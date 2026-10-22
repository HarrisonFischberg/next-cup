import SwiftUI
import UIKit

enum AppTab: Hashable { case journal, recipes }

/// All state for the F01 flow, shared by every concept so the five worlds
/// differ in presentation only: same data, same validation, same timer.
@MainActor @Observable
final class FlowModel {
    let recipe = SampleData.recipe
    var journal = SampleData.journal
    var draft = BrewDraft()

    var tab: AppTab = .journal
    var showTimer = false
    var showLog = false

    /// Set after a save so the journal can show an Undo toast.
    var lastSaved: JournalEntry?
    var saveError: String?

    // Timer state
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private(set) var isRunning = false
    private(set) var hasStarted = false
    /// Launch-argument override so screenshots land on a known moment.
    private let frozenElapsed: TimeInterval?
    private let pendingStage: String?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), arguments.indices.contains(i + 1) else { return nil }
            return arguments[i + 1]
        }
        frozenElapsed = value(after: "-elapsed").flatMap(Double.init)
        pendingStage = value(after: "-stage")
        if frozenElapsed != nil { hasStarted = true }
    }

    /// Opens the screen named by `-stage` (recipe, timer, log, journal).
    func applyLaunchStage() {
        switch pendingStage {
        case "recipe": tab = .recipes
        case "timer": tab = .recipes; showTimer = true
        case "log": prefillFromRecipe(measuredS: 184); tab = .recipes; showLog = true
        case "journal": tab = .journal
        default: break
        }
    }

    // MARK: Timer

    func elapsed(at date: Date = .now) -> TimeInterval {
        if let frozenElapsed { return frozenElapsed }
        guard let startedAt, isRunning else { return accumulated }
        return accumulated + date.timeIntervalSince(startedAt)
    }

    func stepIndex(at elapsed: TimeInterval) -> Int {
        recipe.steps.lastIndex(where: { Double($0.startS) <= elapsed }) ?? 0
    }

    func nextStep(after index: Int) -> RecipeStep? {
        recipe.steps.indices.contains(index + 1) ? recipe.steps[index + 1] : nil
    }

    var isDone: Bool { elapsed() >= Double(recipe.totalS) }

    func startTimer() {
        hasStarted = true
        startedAt = .now
        isRunning = true
    }

    func pauseTimer() {
        accumulated = elapsed()
        isRunning = false
    }

    func resumeTimer() {
        startedAt = .now
        isRunning = true
    }

    func toggleTimer() {
        if !hasStarted { startTimer() } else if isRunning { pauseTimer() } else { resumeTimer() }
    }

    func resetTimer() {
        startedAt = nil
        accumulated = 0
        isRunning = false
        hasStarted = false
    }

    /// End the brew (early or at the finish) and open the log form prefilled.
    func finishBrew() {
        let measured = Int(elapsed().rounded())
        pauseTimer()
        prefillFromRecipe(measuredS: measured)
        showTimer = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            self.showLog = true
        }
    }

    // MARK: Log

    func prefillFromRecipe(measuredS: Int) {
        draft = BrewDraft(bean: "Kenya Kiambu AA", doseG: recipe.doseG, waterG: recipe.waterG,
                          grind: 22, tempC: recipe.tempC, timeS: measuredS)
    }

    /// Save the draft. Returns false (and sets `saveError`) when invalid; the draft is kept.
    @discardableResult
    func save() -> Bool {
        if let problem = draft.problem {
            saveError = problem
            return false
        }
        saveError = nil
        let entry = JournalEntry(
            id: UUID(), date: .now, bean: draft.bean, method: recipe.method,
            doseG: draft.doseG, waterG: draft.waterG, grind: draft.grind, tempC: draft.tempC,
            timeS: draft.timeS, ratingHalfSteps: draft.ratingHalfSteps,
            verdict: draft.verdict, note: draft.notes)
        journal.insert(entry, at: 0)
        lastSaved = entry
        showLog = false
        tab = .journal
        resetTimer()
        return true
    }

    func undoSave() {
        guard let last = lastSaved else { return }
        journal.removeAll { $0.id == last.id }
        lastSaved = nil
    }

    func dismissToast() { lastSaved = nil }
}
