import Foundation
import Network
import NextCupKit
import Observation
import SwiftData

extension AIProvider {
  var kind: AIProviderKind {
    switch self {
    case .anthropic: .anthropic
    case .openAI: .openAI
    }
  }
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
  private let monitor = NWPathMonitor()
  private var tasks: [UUID: Task<Void, Never>] = [:]

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
      disclosureAccepted: { AIPreferences().hasAcceptedDisclosure })
    let queue = AIQueue(context: context, client: client)
    queue.onDone = { AISuggestions.ingest($0, in: context) }
    return queue
  }

  func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor in self?.setOnline(online) }
    }
    monitor.start(queue: .global(qos: .utility))
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
    processQueued()
    return request
  }

  func processQueued() {
    guard isOnline else { return }
    let queued = ((try? context.fetch(FetchDescriptor<AIRequest>())) ?? [])
      .filter { $0.status == .queued }
      .sorted { $0.createdAt < $1.createdAt }
    queued.forEach(run)
  }

  func cancel(_ request: AIRequest) {
    tasks[request.id]?.cancel()
    tasks[request.id] = nil
    guard request.status == .queued || request.status == .sending else { return }
    request.status = .cancelled
    request.errorMessage = nil
    save(request)
  }

  /// Puts a failed or cancelled request back in the queue.
  func retry(_ request: AIRequest) {
    guard request.status == .failed || request.status == .cancelled else { return }
    request.status = .queued
    request.errorMessage = nil
    save(request)
    processQueued()
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
    tasks[request.id] = Task { [client] in
      do {
        finish(request, .success(try await client.send(payload, provider: provider, model: model)))
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
    case .failure(.offline):
      request.status = .queued
      request.errorMessage = AIError.offline.errorDescription
    case .failure(.cancelled):
      request.status = .cancelled
    case .failure(let error):
      request.status = .failed
      request.errorMessage = error.errorDescription
    }
    save(request)
    if request.status == .done { onDone?(request) }
  }

  private func save(_ request: AIRequest) {
    request.updatedAt = Date()
    try? context.save()
  }
}
