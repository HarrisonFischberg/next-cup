import Foundation
import NextCupKit
import Observation
import SwiftData

/// State for "Ask AI about this brew" and Explore insights (T033). The sheet shows
/// the exact text that would be sent; nothing is queued until a key, a chosen model,
/// an accepted disclosure and a tap are all in place. A finished answer is stored as
/// a `Suggestion` by `AISuggestions.ingest`, so it reaches the next brew through the
/// same card as the rules.
@Observable @MainActor
final class AIAskModel {
  enum Readiness: Equatable {
    case ready(AIProvider, modelID: String)
    /// No provider or model chosen for this feature in Settings → AI.
    case needsChoice
    case needsKey(AIProvider)
    case needsDisclosure(AIProvider, modelID: String)
  }

  let feature: AIFeature
  /// The text a request would send, built by the same code that builds the request.
  let payload: AIRequestPayload
  private(set) var request: AIRequest?
  private(set) var suggestion: Suggestion?
  private(set) var errorMessage: String?

  private let anchor: Brew
  private let context: ModelContext
  private let preferences: AIPreferences
  private let hasKey: (AIProvider) -> Bool
  private let makeQueue: (ModelContext) -> AIQueue
  private var queue: AIQueue?

  /// `brews` is newest first. Diagnosis uses the first; insights uses up to eight.
  init(
    feature: AIFeature, brews: [Brew], context: ModelContext,
    preferences: AIPreferences = AIPreferences(),
    hasKey: @escaping (AIProvider) -> Bool = { KeychainStore().hasKey(for: $0) },
    makeQueue: @escaping (ModelContext) -> AIQueue = { AIQueue.live(context: $0) }
  ) {
    precondition(!brews.isEmpty && (feature == .diagnosis || feature == .insights))
    self.feature = feature
    self.anchor = brews[0]
    self.payload =
      feature == .diagnosis
      ? AISuggestions.payload(diagnosing: brews[0]) : AISuggestions.payload(insightsFrom: brews)
    self.context = context
    self.preferences = preferences
    self.hasKey = hasKey
    self.makeQueue = makeQueue
  }

  var readiness: Readiness {
    guard let provider = preferences.provider(for: feature),
      let modelID = preferences.modelID(for: feature)
    else { return .needsChoice }
    guard hasKey(provider) else { return .needsKey(provider) }
    guard preferences.hasAcceptedDisclosure(for: provider) else {
      return .needsDisclosure(provider, modelID: modelID)
    }
    return .ready(provider, modelID: modelID)
  }

  var isWorking: Bool { request?.status == .queued || request?.status == .sending }
  var isWaitingForConnection: Bool { request?.status == .queued }

  func acceptDisclosure(for provider: AIProvider) {
    preferences.acceptDisclosure(for: provider)
  }

  /// Queues the request. Does nothing unless `readiness` is `.ready`.
  func send() {
    guard case .ready(let provider, let modelID) = readiness, !isWorking else { return }
    errorMessage = nil
    suggestion = nil
    let queue = self.queue ?? makeQueue(context)
    queue.onDone = { [context] in AISuggestions.ingest($0, in: context) }
    if self.queue == nil {
      queue.startMonitoring()
      self.queue = queue
    }
    do {
      request = try queue.enqueue(
        payload, feature: feature, provider: provider, modelID: modelID, brew: anchor)
    } catch {
      request = nil
      errorMessage = "The request could not be queued. \(error.localizedDescription)"
    }
  }

  /// Follows the request: a finished answer becomes the suggestion card, a failure
  /// keeps its reason so the sheet can offer Try again.
  func statusChanged() {
    guard let request else { return }
    switch request.status {
    case .done:
      suggestion = try? Store(context: context).find(Suggestion.self, id: request.id)
      if suggestion == nil { errorMessage = AIError.invalidResponse.errorDescription }
    case .failed:
      errorMessage = request.errorMessage ?? "The request failed."
    case .cancelled:
      self.request = nil
    case .queued, .sending:
      break
    }
  }

  func cancel() {
    if let request { queue?.cancel(request) }
    request = nil
  }

  /// The sheet is going away: nothing may stay queued behind it.
  func leave() { queue?.cancelAll() }

  func retry() {
    request = nil
    send()
  }

  /// Sets the card aside; `undo` brings it back. Both are saved at once.
  func setDismissed(_ dismissed: Bool) {
    guard let suggestion else { return }
    suggestion.state = dismissed ? .dismissed : .proposed
    suggestion.updatedAt = Date()
    if case .failure = Store(context: context).save() {
      context.rollback()
      errorMessage = "That change was not saved. Try again."
    }
  }
}
