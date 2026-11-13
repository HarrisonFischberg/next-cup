import Foundation
import Network
import NextCupKit
import Observation
import SwiftData

extension AIProvider {
  /// The cloud provider behind this choice; nil for Apple's on-device model.
  var kind: AIProviderKind? { AIProviderKind(rawValue: rawValue) }
}

/// Sends the `AIRequest`s the user queued with a tap (blueprint §3a). Offline
/// requests stay `queued` and visible; each one can be cancelled. Nothing is
/// ever enqueued without a call to `enqueue`, so no AI traffic starts by itself.
@MainActor @Observable
final class AIQueue {
  private(set) var isOnline = true
  /// Called after a request finishes with schema-valid output.
  var onDone: ((AIRequest) -> Void)?
  private let context: ModelContext
  private let client: AIClient
  private var monitor: NWPathMonitor?
  private var tasks: [UUID: Task<Void, Never>] = [:]
  /// Only requests this queue enqueued are ever sent by it, so a tap on one screen
  /// cannot release a request left over from another.
  private var owned: Set<UUID> = []

  init(context: ModelContext, client: AIClient) {
    self.context = context
    self.client = client
  }

  /// The production queue: URLSession, Keychain keys, stored disclosure choice.
  static func live(context: ModelContext) -> AIQueue {
    let keychain = KeychainStore()
    let client = AIClient(
      transport: URLSessionTransport(),
      key: { provider in
        AIProvider(rawValue: provider.rawValue).flatMap { (try? keychain.key(for: $0)) ?? nil }
      },
      disclosureAccepted: { kind in
        AIProvider(rawValue: kind.rawValue)
          .map { AIPreferences().hasAcceptedDisclosure(for: $0) } ?? false
      })
    let queue = AIQueue(context: context, client: client)
    queue.onDone = { AISuggestions.ingest($0, in: context) }
    return queue
  }

  func startMonitoring() {
    monitor?.cancel()
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor in self?.setOnline(online) }
    }
    monitor.start(queue: .global(qos: .utility))
    self.monitor = monitor
  }

  func setOnline(_ online: Bool) {
    isOnline = online
    if online { processQueued() }
  }

  @discardableResult
  func enqueue(
    _ payload: AIRequestPayload, feature: AIFeature, provider: AIProvider, modelID: String,
    brew: Brew? = nil
  ) throws -> AIRequest {
    let request = AIRequest()
    request.feature = feature
    request.provider = provider
    request.modelID = modelID
    request.payloadJSON = try JSONEncoder().encode(payload)
    request.attachment = payload.imageJPEG
    request.brew = brew
    context.insert(request)
    try context.save()
    owned.insert(request.id)
    processQueued()
    return request
  }

  func processQueued() {
    guard isOnline else { return }
    let queued = ((try? context.fetch(FetchDescriptor<AIRequest>())) ?? [])
      .filter { $0.status == .queued && owned.contains($0.id) }
      .sorted { $0.createdAt < $1.createdAt }
    queued.forEach(run)
  }

  func cancel(_ request: AIRequest) {
    tasks[request.id]?.cancel()
    tasks[request.id] = nil
    guard request.status == .queued || request.status == .sending else { return }
    request.status = .cancelled
    request.errorMessage = nil
    purge(request)
    save(request)
  }

  /// Cancels everything this queue still holds and stops watching the network;
  /// called when its screen goes away.
  func cancelAll() {
    monitor?.cancel()
    monitor = nil
    for request in ((try? context.fetch(FetchDescriptor<AIRequest>())) ?? [])
    where owned.contains(request.id) { cancel(request) }
  }

  /// Cancels requests left `queued` or `sending` by an earlier launch, so they are
  /// never sent later and their photo and payload are not kept. Requests that ended
  /// with no result kept (failed, cancelled, or the answer discarded) are deleted, so
  /// the table does not grow by a row per AI ask.
  static func expireStale(in context: ModelContext) {
    for request in (try? context.fetch(FetchDescriptor<AIRequest>())) ?? [] {
      switch request.status {
      case .queued, .sending:
        request.status = .cancelled
        request.attachment = nil
        request.payloadJSON = Data()
        request.updatedAt = Date()
      case .done, .failed, .cancelled:
        if request.resultJSON == nil { context.delete(request) }
      }
    }
    try? context.save()
  }

  /// Lets tests wait for in-flight sends.
  func waitForIdle() async {
    for task in Array(tasks.values) { await task.value }
  }

  // MARK: Private

  private func run(_ request: AIRequest) {
    guard tasks[request.id] == nil else { return }
    guard var payload = try? JSONDecoder().decode(AIRequestPayload.self, from: request.payloadJSON)
    else { return finish(request, .failure(.invalidResponse)) }
    payload.imageJPEG = request.attachment
    request.status = .sending
    request.attempts += 1
    request.errorMessage = nil
    save(request)
    let provider = request.provider.kind
    let model = request.modelID
    let effort = AIPreferences().effort
    tasks[request.id] = Task { [client] in
      do {
        let result =
          if let provider {
            try await client.send(payload, provider: provider, model: model, effort: effort)
          } else {
            try await AppleIntelligence.send(payload)
          }
        finish(request, .success(result))
      } catch {
        finish(request, .failure(error as? AIError ?? .cancelled))
      }
    }
  }

  private func finish(_ request: AIRequest, _ outcome: Result<AIResult, AIError>) {
    tasks[request.id] = nil
    guard request.status != .cancelled else { return }
    switch outcome {
    case .success(let result):
      request.status = .done
      request.resultJSON = result.json
      purge(request)
    case .failure(.offline):
      request.status = .queued
      request.errorMessage = AIError.offline.errorDescription
    case .failure(.cancelled):
      request.status = .cancelled
      purge(request)
    case .failure(let error):
      request.status = .failed
      request.errorMessage = error.errorDescription
      purge(request)
    }
    save(request)
    if request.status == .done { onDone?(request) }
  }

  /// A request that has ended keeps neither the photo nor the text that was sent.
  private func purge(_ request: AIRequest) {
    request.attachment = nil
    request.payloadJSON = Data()
  }

  private func save(_ request: AIRequest) {
    request.updatedAt = Date()
    try? context.save()
  }
}

extension AIRequest {
  /// Drops the answer once the screen has used it. Photo answers (a bag label, a
  /// transcribed journal page) have no brew to hang on and no purpose afterwards.
  func discardResult() {
    resultJSON = nil
    try? modelContext?.save()
  }
}
