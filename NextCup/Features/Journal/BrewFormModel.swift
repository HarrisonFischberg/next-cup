import Foundation
import NextCupKit
import Observation
import SwiftData
import UIKit

/// A notice above the form: what happened to the draft, never silent.
struct FormNotice: Equatable {
  enum Kind { case info, error }
  let kind: Kind
  let message: String
}

/// State and rules for the brew form (S02). The draft is autosaved outside the
/// store; a brew is written only on Save, and the draft is cleared only after
/// that write is confirmed (blueprint §7).
@Observable @MainActor
final class BrewFormModel {
  /// Starting values when a field is first touched with nothing set.
  static let defaultDoseG = 15.0
  static let defaultWaterG = 250.0
  static let defaultTempC = 94.0
  static let defaultTimeS = 180
  static let lastMethodKey = "brew.lastMethodID"

  var draft: BrewDraft
  private(set) var notice: FormNotice?
  private(set) var saveError: String?
  private(set) var isSaving = false
  private(set) var savedBrewID: UUID?
  private(set) var photoError: String?

  let seed: BrewFormSeed?
  /// The saved brew being edited, or `nil` for a new brew.
  let editingID: UUID?
  private let store: Store
  private let draftStore: DraftStore
  private let defaults: UserDefaults
  private let simulatesSaveFailure: Bool
  private var autosave: Task<Void, Never>?

  var isEditing: Bool { editingID != nil }

  /// Opens the form: restores a saved draft when one belongs here, otherwise
  /// starts from the saved brew being edited, the timer's seed or a blank brew.
  /// An edit keeps its own draft file, so it never touches a new brew's draft.
  init(
    seed: BrewFormSeed?, editing brew: Brew? = nil, store: Store,
    draftStore: DraftStore = .standard(), defaults: UserDefaults = .standard,
    simulatesSaveFailure: Bool = false
  ) {
    self.seed = seed
    self.editingID = brew?.id
    self.store = store
    self.draftStore = draftStore
    self.defaults = defaults
    self.simulatesSaveFailure = simulatesSaveFailure

    func belongs(_ saved: BrewDraft) -> Bool {
      if let brew { return saved.id == brew.id }
      return seed == nil || saved.sourceKey == seed?.sessionKey
    }
    switch draftStore.load() {
    case .draft(let saved) where belongs(saved):
      draft = saved
      notice = FormNotice(kind: .info, message: "Restored your unsaved brew.")
    case .discardedCorrupt:
      draft = Self.fresh(seed: seed, editing: brew, store: store, defaults: defaults)
      notice = FormNotice(
        kind: .info, message: "A damaged draft could not be read and was discarded.")
    default:
      draft = Self.fresh(seed: seed, editing: brew, store: store, defaults: defaults)
    }
    // A form opened from a timer run is saved at once, so the time reached
    // survives a crash before the first edit.
    if seed != nil { flushDraft() }
  }

  private static func fresh(
    seed: BrewFormSeed?, editing brew: Brew?, store: Store, defaults: UserDefaults
  ) -> BrewDraft {
    if let brew {
      return BrewDraft(
        id: brew.id, date: brew.date, methodID: brew.method?.id, recipeID: brew.recipe?.id,
        doseG: brew.doseG, waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS,
        grindSetting: brew.grindSetting ?? "", verdict: brew.verdict?.rawValue,
        ratingHalfSteps: brew.ratingHalfSteps ?? 0, notes: brew.notes, photo: brew.photo,
        targets: brew.targetsJSON.flatMap { try? JSONDecoder().decode(BrewTargets.self, from: $0) })
    }
    if let seed {
      let method = (try? store.find(Recipe.self, id: seed.recipeID))?.method
      return BrewDraft(
        sourceKey: seed.sessionKey, methodID: method?.id, recipeID: seed.recipeID,
        doseG: seed.doseG, waterG: seed.waterG, tempC: seed.tempC, totalTimeS: seed.totalTimeS,
        targets: seed.targets, endedEarly: seed.endedEarly)
    }
    let remembered = defaults.string(forKey: lastMethodKey).flatMap(UUID.init(uuidString:))
    let visible = (try? store.context.fetch(FetchDescriptor<BrewMethod>())) ?? []
    let fallback = visible.filter { !$0.isHidden }.min { $0.sortOrder < $1.sortOrder }
    let method = visible.first { $0.id == remembered && !$0.isHidden } ?? fallback
    return BrewDraft(methodID: method?.id)
  }

  // MARK: Derived

  var ratioLabel: String? {
    BrewMath.ratioLabel(BrewMath.ratio(doseG: draft.doseG, waterG: draft.waterG))
  }

  var canSave: Bool { draft.canSave && !isSaving && savedBrewID == nil }

  // MARK: Editing

  /// Moves a weight by `direction` steps of `step` in the user's unit, so a tap
  /// always changes what is shown. Nothing set yet starts from `start`.
  func stepWeight(
    _ keyPath: WritableKeyPath<BrewDraft, Double?>, direction: Int, units: UnitPreferences,
    gramStep: Double, ounceStep: Double, start: Double
  ) {
    guard let current = draft[keyPath: keyPath] else {
      draft[keyPath: keyPath] = start
      return
    }
    let step = units.weight == .grams ? gramStep : ounceStep
    let shown = units.displayWeight(grams: current)
    let next = max(step, ((shown + Double(direction) * step) / step).rounded() * step)
    draft[keyPath: keyPath] = units.grams(fromDisplayWeight: next)
  }

  func stepTemperature(direction: Int, units: UnitPreferences) {
    guard let current = draft.tempC else {
      draft.tempC = Self.defaultTempC
      return
    }
    let shown = units.displayTemperature(celsius: current).rounded() + Double(direction)
    draft.tempC = units.celsius(fromDisplayTemperature: shown)
  }

  func stepTime(direction: Int) {
    guard let current = draft.totalTimeS else {
      draft.totalTimeS = Self.defaultTimeS
      return
    }
    draft.totalTimeS = max(0, current + direction * 5)
  }

  /// Re-encodes the picked photo without location or camera metadata before it
  /// is kept anywhere. A file that is not an image changes nothing.
  func attachPhoto(_ data: Data) async {
    photoError = nil
    let cleaned = await Task.detached(priority: .userInitiated) {
      PhotoSanitizer.sanitized(data)
    }.value
    guard let cleaned else {
      photoError = "That file could not be read as a photo. Nothing was attached."
      return
    }
    draft.photo = cleaned
  }

  func removePhoto() {
    draft.photo = nil
  }

  // MARK: Autosave

  /// Called on every edit. Writes shortly after typing pauses.
  func draftChanged() {
    guard savedBrewID == nil else { return }
    autosave?.cancel()
    autosave = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      self?.flushDraft()
    }
  }

  /// Writes the draft now (backgrounding, leaving the screen). A failure is
  /// shown and the draft stays in memory.
  func flushDraft() {
    autosave?.cancel()
    guard savedBrewID == nil else { return }
    switch draftStore.save(draft) {
    case .success:
      if notice?.kind == .error { notice = nil }
    case .failure:
      notice = FormNotice(
        kind: .error,
        message: "This draft could not be autosaved. What you typed is still here.")
    }
  }

  func dismissNotice() { notice = nil }

  // MARK: Save

  /// Writes the brew. Returns `true` only once the store confirms the write;
  /// on failure the draft is kept and the error is shown (X5).
  @discardableResult
  func save() -> Bool {
    guard canSave else { return false }
    isSaving = true
    saveError = nil
    autosave?.cancel()
    defer { isSaving = false }

    do {
      try store.upsert(Brew.self, id: draft.id, make: { Brew(id: draft.id) }, update: apply)
    } catch {
      return failSave(error.localizedDescription)
    }
    let outcome: Result<Void, StoreError> =
      simulatesSaveFailure ? .failure(.saveFailed("The disk is not writable.")) : store.save()
    if case .failure(.saveFailed(let message)) = outcome {
      return failSave(message)
    }

    if let methodID = draft.methodID {
      defaults.set(methodID.uuidString, forKey: Self.lastMethodKey)
    }
    savedBrewID = draft.id
    if case .failure = draftStore.clear() {
      notice = FormNotice(
        kind: .info, message: "Saved. An old draft file could not be removed.")
    }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    return true
  }

  private func failSave(_ message: String) -> Bool {
    store.context.rollback()
    saveError = "Not saved. \(message) Your brew is kept as a draft. Try again."
    flushDraft()
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    return false
  }

  private func apply(to brew: Brew) {
    brew.date = draft.date
    brew.method = draft.methodID.flatMap { try? store.find(BrewMethod.self, id: $0) }
    brew.recipe = draft.recipeID.flatMap { try? store.find(Recipe.self, id: $0) }
    brew.doseG = draft.doseG
    brew.waterG = draft.waterG
    brew.tempC = draft.tempC
    brew.totalTimeS = draft.totalTimeS
    let grind = draft.grindSetting.trimmingCharacters(in: .whitespacesAndNewlines)
    brew.grindSetting = grind.isEmpty ? nil : grind
    brew.verdict = draft.verdict.flatMap(Verdict.init(rawValue:))
    brew.ratingHalfSteps = draft.ratingHalfSteps == 0 ? nil : draft.ratingHalfSteps
    brew.notes = draft.notes
    brew.photo = draft.photo
    brew.targetsJSON = draft.targets.flatMap { try? JSONEncoder().encode($0) }
    brew.isDraft = false
  }
}
