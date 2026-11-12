import Foundation
import NextCupKit
import Observation
import SwiftData
import UIKit

/// State and rules for importing a journal page (T025). A page is read into a
/// `PaperBrewDraft` that lives only in memory; a `Brew` is written only after the
/// user has checked the draft and confirmed it, and any edit takes the
/// confirmation back (blueprint §3a: nothing is saved until confirmed).
@Observable @MainActor
final class PaperImportModel {
  enum Phase: Equatable { case choose, reading, review }

  private(set) var phase = Phase.choose
  private(set) var photo: Data?
  private(set) var errorMessage: String?
  private(set) var saveError: String?
  private(set) var isSaving = false
  private(set) var aiRequest: AIRequest?
  var date = Date() {
    didSet { confirmed = false }
  }
  var methodID: UUID? {
    didSet { if methodID != oldValue { confirmed = false } }
  }
  var draft = PaperBrewDraft() {
    didSet { if draft != oldValue { confirmed = false } }
  }
  var confirmed = false

  private let store: Store
  private let brewID = UUID()
  private let makeQueue: (ModelContext) -> AIQueue
  private var queue: AIQueue?
  private var reading: Task<Void, Never>?

  init(
    store: Store, makeQueue: @escaping (ModelContext) -> AIQueue = { AIQueue.live(context: $0) }
  ) {
    self.store = store
    self.makeQueue = makeQueue
  }

  var canSave: Bool { phase == .review && confirmed && !isSaving }

  // MARK: Photo

  /// Keeps the page photo with its metadata stripped. A file that is not an image
  /// changes nothing.
  func choose(photoData: Data) async {
    errorMessage = nil
    let cleaned = await Task.detached(priority: .userInitiated) {
      PhotoSanitizer.sanitized(photoData)
    }.value
    guard let cleaned else {
      errorMessage = "That file could not be read as a photo. Nothing was imported."
      return
    }
    photo = cleaned
  }

  // MARK: Reading

  /// Recognizes the text on this iPhone. Nothing leaves the device.
  func readOnDevice() {
    guard let photo, phase == .choose else { return }
    errorMessage = nil
    phase = .reading
    reading = Task {
      do {
        let lines = try await PaperScanner.lines(in: photo)
        guard !Task.isCancelled else { return }
        show(PaperImport.parse(lines))
      } catch {
        guard !Task.isCancelled else { return }
        fail("The page could not be read. \(error.localizedDescription)")
      }
    }
  }

  /// Sends the photo to the user's AI provider with their key. Queued while offline.
  func readWithAI() {
    guard let photo, phase == .choose else { return }
    let preferences = AIPreferences()
    guard let provider = preferences.provider(for: .paperImport),
      let modelID = preferences.modelID(for: .paperImport)
    else {
      errorMessage = "Choose a provider and model for Paper import in Settings → AI first."
      return
    }
    errorMessage = nil
    let queue = self.queue ?? makeQueue(store.context)
    queue.onDone = nil
    if self.queue == nil {
      queue.startMonitoring()
      self.queue = queue
    }
    do {
      aiRequest = try queue.enqueue(
        PaperImport.payload(photo: photo), feature: .paperImport, provider: provider,
        modelID: modelID)
      phase = .reading
    } catch {
      errorMessage = "The request could not be queued. \(error.localizedDescription)"
    }
  }

  /// Follows the AI request: a finished answer opens the review, a failure returns
  /// to the photo with the reason.
  func aiStatusChanged() {
    guard phase == .reading, let request = aiRequest else { return }
    switch request.status {
    case .done:
      guard let result = PaperImport.draft(fromAI: request.resultJSON ?? Data()) else {
        return fail(AIError.invalidResponse.errorDescription ?? "The answer was discarded.")
      }
      request.discardResult()
      aiRequest = nil
      show(result)
    case .failed:
      fail(request.errorMessage ?? "The page could not be read.")
    case .cancelled:
      aiRequest = nil
      phase = .choose
    case .queued, .sending:
      break
    }
  }

  var isWaitingForConnection: Bool { aiRequest?.status == .queued }

  /// The provider chosen for Paper import, once a model is chosen too.
  var aiProvider: AIProvider? {
    let preferences = AIPreferences()
    return preferences.modelID(for: .paperImport) == nil
      ? nil : preferences.provider(for: .paperImport)
  }

  /// The import screen is going away: nothing may stay queued behind it.
  func leave() {
    reading?.cancel()
    queue?.cancelAll()
  }

  func cancelReading() {
    reading?.cancel()
    if let aiRequest { queue?.cancel(aiRequest) }
    aiRequest = nil
    phase = .choose
  }

  private func show(_ read: PaperBrewDraft) {
    guard !read.isEmpty else {
      return fail("No journal text was found on that page. Try a sharper, well-lit photo.")
    }
    draft = read
    methodID = Self.match(read.method, among: methods.map { ($0.id, $0.name) })
    confirmed = false
    phase = .review
  }

  private func fail(_ message: String) {
    aiRequest = nil
    errorMessage = message
    phase = .choose
  }

  /// Back to the photo choice, keeping the photo.
  func startOver() {
    draft = PaperBrewDraft()
    confirmed = false
    saveError = nil
    phase = .choose
  }

  // MARK: Filing

  private var methods: [BrewMethod] {
    ((try? store.context.fetch(FetchDescriptor<BrewMethod>())) ?? []).filter { !$0.isHidden }
  }

  /// The saved name a written name refers to: equal after normalizing, or one
  /// contains the other ("V60" and "Hario V60"). Names under three letters only
  /// match exactly.
  static func match(_ written: String, among names: [(id: UUID, name: String)]) -> UUID? {
    let wanted = Taxonomy.normalize(written)
    guard !wanted.isEmpty else { return nil }
    func close(_ name: String) -> Bool {
      let other = Taxonomy.normalize(name)
      if other == wanted { return true }
      return min(other.count, wanted.count) >= 3
        && (other.contains(wanted) || wanted.contains(other))
    }
    return names.first { Taxonomy.normalize($0.name) == wanted }?.id
      ?? names.first { close($0.name) }?.id
  }

  /// The saved bean the written bean name refers to, if any.
  func matchedBean() -> Bean? {
    let beans = (try? store.context.fetch(FetchDescriptor<Bean>())) ?? []
    return Self.match(draft.bean, among: beans.map { ($0.id, $0.name) }).flatMap { id in
      beans.first { $0.id == id }
    }
  }

  // MARK: Save

  /// Writes the brew. Only a confirmed draft is saved, and a failed write keeps the
  /// draft and says so. Returns `true` once the store confirms the write.
  @discardableResult
  func save() -> Bool {
    guard canSave else { return false }
    isSaving = true
    saveError = nil
    defer { isSaving = false }
    do {
      try store.upsert(Brew.self, id: brewID, make: { Brew(id: brewID) }, update: apply)
    } catch {
      return fail(save: error.localizedDescription)
    }
    if case .failure(.saveFailed(let message)) = store.save() { return fail(save: message) }
    Feedback.success()
    return true
  }

  private func fail(save message: String) -> Bool {
    store.context.rollback()
    saveError = "Not saved. \(message) Your checked page is still here. Try again."
    Feedback.error()
    return false
  }

  private func apply(to brew: Brew) {
    brew.date = date
    brew.method = methodID.flatMap { try? store.find(BrewMethod.self, id: $0) }
    brew.doseG = draft.doseG
    brew.waterG = draft.waterG
    brew.tempC = draft.tempC
    brew.totalTimeS = draft.totalTimeS
    let grind = draft.grind.trimmingCharacters(in: .whitespacesAndNewlines)
    brew.grindSetting = grind.isEmpty ? nil : grind
    brew.ratingTenths = draft.ratingTenths
    brew.notes = draft.notes
    brew.photo = photo
    let name = draft.bean.trimmingCharacters(in: .whitespacesAndNewlines)
    for old in brew.beans ?? [] { store.context.delete(old) }
    brew.beans = []
    if !name.isEmpty {
      let matched = matchedBean()
      let use = BrewBean(grams: draft.doseG ?? 0, beanNameSnapshot: matched?.name ?? name)
      store.context.insert(use)
      use.bean = matched
      brew.beans = [use]
    }
  }
}
