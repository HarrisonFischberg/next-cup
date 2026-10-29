import Foundation
import NextCupKit
import Observation
import SwiftData
import UIKit

/// A notice above the form: what happened to the draft, never silent.
struct FormNotice: Equatable {
  /// `info` offers Dismiss.
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
  static let defaultTds = 1.35
  static let lastMethodKey = "brew.lastMethodID"
  static let lastGrinderKey = "brew.lastGrinderID"

  var draft: BrewDraft
  private(set) var notice: FormNotice?
  private(set) var saveError: String?
  private(set) var isSaving = false
  private(set) var savedBrewID: UUID?
  private(set) var photoError: String?
  /// The suggestion the user has answered on this form, so its card stays visible
  /// with Undo after it leaves the waiting list.
  private(set) var handledSuggestionID: UUID?
  private(set) var suggestionError: String?
  /// What the rules made of the brew just saved: the suggestion, or why none.
  private(set) var madeSuggestion: Suggestion?
  private(set) var dialInNote: String?
  /// Set when this brew's grade beats every earlier graded brew of one of its beans.
  private(set) var newBest: (bean: String, tenths: Int, previous: Int)?
  private var followedSuggestionID: UUID?
  /// The draft value and suggested value before an answer, kept for Undo.
  private var undoDraftValue: String?
  private var undoToValue: String?
  /// What the form opens with before any resume. A form left exactly like it
  /// keeps no draft.
  private var baseline: BrewDraft

  let seed: BrewFormSeed?
  /// The saved brew being edited, or `nil` for a new brew.
  let editingID: UUID?
  /// The saved brew this form repeats ("Brew again"), or `nil`.
  let repeatingID: UUID?
  private let store: Store
  private let draftStore: DraftStore
  private let defaults: UserDefaults
  private let simulatesSaveFailure: Bool
  private var autosave: Task<Void, Never>?

  var isEditing: Bool { editingID != nil }

  /// Opens the form from the saved brew being edited, the timer's seed or a
  /// blank brew. Unsaved brews are reopened only from the Journal (`resuming`),
  /// and a timer run's form picks its own draft back up; either way without a
  /// banner. Each opening writes its own draft file, so it never overwrites
  /// another unsaved brew.
  init(
    seed: BrewFormSeed?, editing brew: Brew? = nil, repeating source: Brew? = nil, store: Store,
    draftStore: DraftStore = .newBrew(), resuming: Bool = false,
    defaults: UserDefaults = .standard, simulatesSaveFailure: Bool = false
  ) {
    self.seed = seed
    self.editingID = brew?.id
    self.repeatingID = source?.id
    self.store = store
    self.draftStore = draftStore
    self.defaults = defaults
    self.simulatesSaveFailure = simulatesSaveFailure

    func belongs(_ saved: BrewDraft) -> Bool {
      if let brew { return saved.id == brew.id }
      if let source { return saved.sourceKey == BrewDraft.repeatKey(for: source.id) }
      return seed == nil || saved.sourceKey == seed?.sessionKey
    }
    func opening() -> BrewDraft {
      Self.fresh(
        seed: seed, editing: brew, repeating: source, store: store, defaults: defaults)
    }
    let opened = opening()
    baseline = opened
    switch resuming || seed != nil ? draftStore.load() : .none {
    case .draft(let saved) where belongs(saved):
      draft = saved
    case .discardedCorrupt:
      draft = opened
      notice = FormNotice(
        kind: .info, message: "A damaged draft could not be read and was discarded.")
    default:
      draft = opened
    }
    // A form opened from a timer run or a repeat is saved at once, so the values
    // it carries survive a crash before the first edit.
    if seed != nil || source != nil { flushDraft(force: true) }
  }

  /// Whether a saved draft holds nothing the form would not open with anyway.
  /// A new brew's id and time are made fresh on each open, so they don't count.
  private static func sameValues(_ saved: BrewDraft, _ opened: BrewDraft, editing: Bool) -> Bool {
    var saved = saved
    if !editing { (saved.id, saved.date) = (opened.id, opened.date) }
    return saved == opened
  }

  /// Whether a draft file holds anything the form would not open with anyway.
  /// Older builds left untouched drafts behind; those are not worth listing.
  static func hasChanges(
    _ draft: BrewDraft, editing brew: Brew?, repeating source: Brew?, store: Store,
    defaults: UserDefaults = .standard
  ) -> Bool {
    let opened = fresh(
      seed: nil, editing: brew, repeating: source, store: store, defaults: defaults)
    return !sameValues(draft, opened, editing: brew != nil)
  }

  /// Takes what the form holds now as its starting point, so values filled in
  /// for the user (a bean chosen before opening) are not mistaken for typing.
  func treatAsOpened() { baseline = draft }

  /// Drops every change since the form opened (Cancel on a saved brew).
  func revert() {
    draft = baseline
    flushDraft()
  }

  private static func saved(_ brew: Brew) -> BrewDraft {
    BrewDraft(
      id: brew.id, date: brew.date, methodID: brew.method?.id, recipeID: brew.recipe?.id,
      doseG: brew.doseG, waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS,
      grindSetting: brew.grindSetting ?? "", verdict: Verdict.joined(brew.verdicts),
      ratingTenths: brew.ratingTenths ?? 0, notes: brew.notes, photo: brew.photo,
      targets: brew.targetsJSON.flatMap { try? JSONDecoder().decode(BrewTargets.self, from: $0) },
      beans: (brew.beans ?? []).sorted { $0.createdAt < $1.createdAt }.map {
        DraftBean(
          beanID: $0.bean?.id, name: $0.bean?.name ?? $0.beanNameSnapshot, grams: $0.grams)
      },
      grinderID: brew.grinder?.id, tds: brew.tds, waterProfileID: brew.waterProfile?.id)
  }

  private static func fresh(
    seed: BrewFormSeed?, editing brew: Brew?, repeating source: Brew?, store: Store,
    defaults: UserDefaults
  ) -> BrewDraft {
    if let brew { return saved(brew) }
    if let source {
      let beans = (source.beans ?? []).sorted { $0.createdAt < $1.createdAt }.map {
        DraftBean(
          beanID: $0.bean?.id, name: $0.bean?.name ?? $0.beanNameSnapshot, grams: $0.grams)
      }
      return BrewDraft.repeating(saved(source), sourceID: source.id, beans: beans)
    }
    if let seed {
      let method = (try? store.find(Recipe.self, id: seed.recipeID))?.method
      return BrewDraft(
        sourceKey: seed.sessionKey, methodID: method?.id, recipeID: seed.recipeID,
        doseG: seed.doseG, waterG: seed.waterG, tempC: seed.tempC, totalTimeS: seed.totalTimeS,
        grindSetting: seed.grindSetting, targets: seed.targets, endedEarly: seed.endedEarly,
        beans: seed.beanName.map { [DraftBean(beanID: seed.beanID, name: $0, grams: seed.doseG)] },
        grinderID: seed.grinderID)
    }
    let remembered = defaults.string(forKey: lastMethodKey).flatMap(UUID.init(uuidString:))
    let visible = (try? store.context.fetch(FetchDescriptor<BrewMethod>())) ?? []
    let fallback = visible.filter { !$0.isHidden }.min { $0.sortOrder < $1.sortOrder }
    let method = visible.first { $0.id == remembered && !$0.isHidden } ?? fallback
    return BrewDraft(methodID: method?.id, grinderID: rememberedGrinder(store, defaults))
  }

  /// The grinder used last, if it still exists.
  private static func rememberedGrinder(_ store: Store, _ defaults: UserDefaults) -> UUID? {
    guard let id = defaults.string(forKey: lastGrinderKey).flatMap(UUID.init(uuidString:)) else {
      return nil
    }
    return (try? store.find(Grinder.self, id: id)) == nil ? nil : id
  }

  // MARK: Derived

  var ratioLabel: String? {
    BrewMath.ratioLabel(BrewMath.ratio(doseG: draft.doseG, waterG: draft.waterG))
  }

  /// Extraction yield in percent, with the beverage taken as the water poured.
  /// shortcut: ignores water the grounds keep, upgrade when a beverage weight is logged.
  var extractionLabel: String? {
    BrewMath.extractionYield(tds: draft.tds, beverageG: draft.waterG, doseG: draft.doseG)
      .map { String(format: "%.1f%%", $0) }
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

  /// Moves TDS by 0.05 points; stepping below the first step clears it.
  func stepTds(direction: Int) {
    guard let current = draft.tds else {
      draft.tds = Self.defaultTds
      return
    }
    let next = ((current + Double(direction) * 0.05) / 0.05).rounded() * 0.05
    draft.tds = next < 0.05 ? nil : next
  }

  func stepTime(direction: Int) {
    guard let current = draft.totalTimeS else {
      draft.totalTimeS = Self.defaultTimeS
      return
    }
    draft.totalTimeS = max(0, current + direction * 5)
  }

  // MARK: Beans and grinder

  /// Each bean's share of the dose in percent, in the order of `draft.beans`.
  var beanShares: [Double] {
    BlendShares.percentages(parts: (draft.beans ?? []).map(\.grams))
  }

  /// What each bean contributes at the dose now set, in grams.
  var beanGrams: [Double] {
    BlendShares.grams(dose: draft.doseG ?? 0, parts: (draft.beans ?? []).map(\.grams))
  }

  /// Adds a bean to the blend at an even share. A bean already in it is ignored.
  func addBean(_ bean: Bean) {
    var beans = draft.beans ?? []
    guard !beans.contains(where: { $0.beanID == bean.id }) else { return }
    let shares = BlendShares.appending(to: beans.map(\.grams))
    beans.append(DraftBean(beanID: bean.id, name: bean.name, grams: 0))
    for index in beans.indices { beans[index].grams = shares[index] }
    draft.beans = beans
    if beans.count == 1 { recallGrind(for: bean) }
  }

  /// Each bean keeps its own grind: the first bean chosen on a brew with no grind
  /// yet brings back the grinder and setting from its last saved brew.
  private func recallGrind(for bean: Bean) {
    guard draft.grindSetting.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    let last = (bean.brewUses ?? []).compactMap(\.brew)
      .filter { $0.id != draft.id && !($0.grindSetting ?? "").isEmpty }
      .max { $0.date < $1.date }
    guard let last, let grind = last.grindSetting else { return }
    draft.grindSetting = grind
    if let grinder = last.grinder { draft.grinderID = grinder.id }
  }

  func removeBean(at index: Int) {
    guard var beans = draft.beans, beans.indices.contains(index) else { return }
    let shares = BlendShares.removing(at: index, from: beans.map(\.grams))
    beans.remove(at: index)
    for position in beans.indices { beans[position].grams = shares[position] }
    draft.beans = beans
  }

  /// Moves one bean's share by `points` percent; the others give or take the rest.
  func stepShare(at index: Int, by points: Double) {
    guard var beans = draft.beans, beans.indices.contains(index), beans.count > 1 else { return }
    let current = BlendShares.percentages(parts: beans.map(\.grams))
    let next = BlendShares.rebalanced(current, setting: index, to: current[index] + points)
    for position in beans.indices { beans[position].grams = next[position] }
    draft.beans = beans
  }

  func setGrinder(_ id: UUID?) {
    draft.grinderID = id
  }

  func setWaterProfile(_ id: UUID?) {
    draft.waterProfileID = id
  }

  /// Adds a water profile (or finds the one with this name) and chooses it.
  /// Hardness is optional; a value that is not a positive number is refused.
  @discardableResult
  func addWaterProfile(named name: String, hardnessPPM: String = "") -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let typed = hardnessPPM.trimmingCharacters(in: .whitespaces)
    let hardness = Double(typed)
    guard !clean.isEmpty, typed.isEmpty || (hardness ?? 0) > 0 else { return false }
    let existing = (try? store.context.fetch(FetchDescriptor<WaterProfile>())) ?? []
    if let match = existing.first(where: {
      $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }) {
      draft.waterProfileID = match.id
      return true
    }
    let profile = WaterProfile(name: clean)
    profile.ppmHardness = hardness
    store.context.insert(profile)
    if case .failure = store.save() {
      store.context.rollback()
      return false
    }
    draft.waterProfileID = profile.id
    return true
  }

  /// Adds a grinder (or finds the one with this name) and chooses it.
  @discardableResult
  func addGrinder(named name: String) -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return false }
    let existing = (try? store.context.fetch(FetchDescriptor<Grinder>())) ?? []
    if let match = existing.first(where: {
      $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }) {
      draft.grinderID = match.id
      return true
    }
    let grinder = Grinder(name: clean)
    store.context.insert(grinder)
    if case .failure = store.save() {
      store.context.rollback()
      return false
    }
    draft.grinderID = grinder.id
    return true
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

  // MARK: Dial-in suggestion

  /// Applies the suggested change to this brew, or the user's edited value (in
  /// canonical text). The answer is stored first; the form changes only once the
  /// store confirms it.
  func applySuggestion(_ suggestion: Suggestion, editedTo edited: String? = nil) {
    suggestionError = nil
    let parameter = suggestion.field
    let original = suggestion.toValue
    let applied = edited ?? original
    var next = draft
    guard !applied.trimmingCharacters(in: .whitespaces).isEmpty,
      SuggestionApplication.set(applied, for: parameter, in: &next)
    else {
      suggestionError = "That value could not be used. Nothing was changed."
      return
    }
    let previous = SuggestionApplication.value(of: parameter, in: draft)
    suggestion.toValue = applied
    suggestion.state = edited == nil ? .accepted : .edited
    suggestion.updatedAt = Date()
    guard answered(suggestion, restoring: original) else { return }
    undoDraftValue = previous
    undoToValue = original
    followedSuggestionID = suggestion.id
    draft = next
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  func dismissSuggestion(_ suggestion: Suggestion) {
    suggestionError = nil
    let original = suggestion.toValue
    suggestion.state = .dismissed
    suggestion.updatedAt = Date()
    guard answered(suggestion, restoring: original) else { return }
    undoDraftValue = nil
    undoToValue = original
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  /// Takes the answer back: the draft value returns to what it was and the
  /// suggestion waits again.
  func undoSuggestionAnswer(_ suggestion: Suggestion) {
    suggestionError = nil
    let applied = suggestion.state == .accepted || suggestion.state == .edited
    let answer = (suggestion.state, suggestion.toValue)
    suggestion.state = .proposed
    suggestion.toValue = undoToValue ?? suggestion.toValue
    suggestion.updatedAt = Date()
    switch store.save() {
    case .success:
      if applied, let undoDraftValue {
        SuggestionApplication.set(undoDraftValue, for: suggestion.field, in: &draft)
      }
      undoDraftValue = nil
      followedSuggestionID = nil
      handledSuggestionID = nil
    case .failure(.saveFailed(let message)):
      store.context.rollback()
      suggestion.state = answer.0
      suggestion.toValue = answer.1
      suggestionError = "The suggestion was not changed. \(message)"
    }
  }

  /// Stores a suggestion's new state. A failed write is rolled back and shown.
  private func answered(_ suggestion: Suggestion, restoring original: String) -> Bool {
    switch store.save() {
    case .success:
      handledSuggestionID = suggestion.id
      return true
    case .failure(.saveFailed(let message)):
      store.context.rollback()
      suggestion.toValue = original
      suggestionError = "The suggestion was not saved. \(message)"
      return false
    }
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
  /// shown and the draft stays in memory. An untouched form removes its draft
  /// instead, so opening and leaving never lists an unsaved brew.
  func flushDraft(force: Bool = false) {
    autosave?.cancel()
    guard savedBrewID == nil else { return }
    guard force || draft != baseline else {
      _ = draftStore.clear()
      return
    }
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

  /// UI tests run in memory and must not meet the notification permission alert.
  static var remindsToTaste: Bool {
    !AppBootstrap.usesInMemoryStore || ProcessInfo.processInfo.arguments.contains("-tasteReminders")
  }

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
    if let grinderID = draft.grinderID {
      defaults.set(grinderID.uuidString, forKey: Self.lastGrinderKey)
    }
    savedBrewID = draft.id
    if !isEditing, draft.verdict == nil, Self.remindsToTaste {
      TasteReminder.schedule(
        brewID: draft.id, beanName: draft.beans?.first?.name, brewedAt: draft.date)
    }
    makeSuggestion()
    noteNewBest()
    if case .failure = draftStore.clear() {
      notice = FormNotice(
        kind: .info, message: "Saved. An old draft file could not be removed.")
    }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    return true
  }

  /// A new best needs an earlier graded brew of the same bean to beat.
  private func noteNewBest() {
    guard let brew = try? store.find(Brew.self, id: draft.id),
      let grade = brew.ratingTenths, grade > 0
    else { return }
    for use in brew.beans ?? [] {
      guard let bean = use.bean else { continue }
      let earlier = (bean.brewUses ?? []).compactMap(\.brew)
        .filter { $0.id != brew.id }
        .compactMap(\.ratingTenths).filter { $0 > 0 }
      if let previous = earlier.max(), grade > previous {
        newBest = (bean.name, grade, previous)
        return
      }
    }
  }

  /// Asks the dial-in rules what to change next. The brew is already saved, so a
  /// failure here is a note, never a lost brew.
  private func makeSuggestion() {
    guard let brew = try? store.find(Brew.self, id: draft.id) else { return }
    switch SuggestionService(store: store).propose(for: brew) {
    case .success(.change):
      madeSuggestion = (brew.suggestionsMade ?? []).first { $0.source == .rules }
    case .success(.keep(let reason)):
      dialInNote = reason
    case .failure:
      dialInNote = "The brew is saved, but its dial-in suggestion could not be stored."
    }
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
    brew.tds = draft.tds
    brew.waterProfile = draft.waterProfileID.flatMap { try? store.find(WaterProfile.self, id: $0) }
    let grind = draft.grindSetting.trimmingCharacters(in: .whitespacesAndNewlines)
    brew.grindSetting = grind.isEmpty ? nil : grind
    let tastes = Verdict.picked(draft.verdict)
    brew.verdict = tastes.first
    brew.alsoTasted = tastes.count > 1 ? tastes.dropFirst().map(\.rawValue) : nil
    brew.ratingTenths = draft.ratingTenths == 0 ? nil : draft.ratingTenths
    brew.notes = draft.notes
    brew.photo = draft.photo
    brew.targetsJSON = draft.targets.flatMap { try? JSONEncoder().encode($0) }
    brew.grinder = draft.grinderID.flatMap { try? store.find(Grinder.self, id: $0) }
    if let followedSuggestionID {
      brew.suggestionFollowed = try? store.find(Suggestion.self, id: followedSuggestionID)
    }
    if let beans = draft.beans { applyBeans(beans, to: brew) }
  }

  /// Gives the brew its beans, each taking its share of this brew's dose, so a
  /// blend deducts from every bag. The beans the brew had before are removed, or
  /// their grams would still count against those bags. A bean that has since been
  /// deleted keeps its name, so the journal still reads the same.
  private func applyBeans(_ beans: [DraftBean], to brew: Brew) {
    let grams = BlendShares.grams(dose: draft.doseG ?? 0, parts: beans.map(\.grams))
    for old in brew.beans ?? [] { store.context.delete(old) }
    brew.beans = zip(beans, grams).map { entry, share in
      let use = BrewBean(grams: share, beanNameSnapshot: entry.name)
      store.context.insert(use)
      use.bean = entry.beanID.flatMap { try? store.find(Bean.self, id: $0) }
      return use
    }
  }
}
