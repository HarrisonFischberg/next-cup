import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// Keeps tomorrow's recipe ready: saving a tasted or rated brew asks the same AI as "Ask AI for
/// Next Cup" and writes the answer straight to the method's Next Cup on the Brew tab. It runs
/// only with AI set up, with the provider's notice accepted and with the Settings → AI switch on.
/// The Brew tab shows how it is going. The brew waits in `pendingKey` until it is answered, so a
/// run iOS stops in the background picks up on the next return to the app.
@MainActor
@Observable
final class NextCupAuto {
  static let enabledKey = "ai.nextCup.auto"
  static let pendingKey = "ai.nextCup.pendingBrew"

  enum Status: Equatable {
    case idle, working
    case failed(String)
    case needsNotice(AIProvider)
  }

  private(set) var status = Status.idle
  private(set) var job: Task<Void, Never>?
  private var run: UUID?
  private var lastBrew: UUID?

  private let defaults: UserDefaults
  private let notice: @MainActor () -> AIProvider?
  private let available: @MainActor () -> Bool
  private let ask: @MainActor (Brew, Store) async throws -> NextCupAI.Outcome

  init(
    defaults: UserDefaults = .standard,
    notice: @escaping @MainActor () -> AIProvider? = { DirectAI.pendingDisclosure },
    // UI tests run in memory and must not reach the real AI.
    available: @escaping @MainActor () -> Bool = {
      !AppBootstrap.usesInMemoryStore && RecipeReviewAI.isAvailable
    },
    ask: (@MainActor (Brew, Store) async throws -> NextCupAI.Outcome)? = nil
  ) {
    self.defaults = defaults
    self.notice = notice
    self.available = available
    self.ask = ask ?? { try await NextCupAI.ask(about: $0, store: $1, sameCategoryOnly: true) }
  }

  static let shared = make()

  private static func make() -> NextCupAuto {
    #if DEBUG
      if NextCupAI.fakesAnswer {
        return NextCupAuto(
          notice: { nil }, available: { true },
          ask: { brew, store in
            let answer = NextCupAI.fakeAnswer(for: NextCupAI.base(for: brew, store: store))
            return try await NextCupAI.ask(
              about: brew, store: store, sameCategoryOnly: true, research: { _ in nil },
              send: { _ in
                try await Task.sleep(for: .seconds(1))
                return (answer, "Test answer")
              })
          })
      }
    #endif
    return NextCupAuto()
  }

  private var isEnabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }

  /// A reviewed brew that is the method's newest. Editing or back-filling an older cup must not
  /// replace a recipe made from a later one.
  static func applies(to brew: Brew, among brews: [Brew]) -> Bool {
    guard brew.isReviewed, let method = brew.method?.id else { return false }
    return !brews.contains { $0.id != brew.id && $0.method?.id == method && $0.date > brew.date }
  }

  /// The brew was saved with a new taste, rating or notes.
  /// shortcut: a second save during a run replaces the first, even for another method; queue
  /// them per method if people brew two methods within the same minute.
  func brewReviewed(_ id: UUID, store: Store) {
    guard isEnabled else { return }
    stop()
    lastBrew = id
    defaults.set(id.uuidString, forKey: Self.pendingKey)
    resume(store: store)
  }

  /// Starts the waiting brew, if any and if it may still go.
  func resume(store: Store) {
    guard job == nil,
      let id = defaults.string(forKey: Self.pendingKey).flatMap(UUID.init(uuidString:))
    else { return }
    let brews = (try? store.context.fetch(FetchDescriptor<Brew>())) ?? []
    guard isEnabled, let brew = brews.first(where: { $0.id == id }),
      Self.applies(to: brew, among: brews)
    else { return finish(.idle) }
    // Route would quietly fall to Apple's model here, but the user picked a provider: ask first.
    if let provider = notice() {
      status = .needsNotice(provider)
      return
    }
    guard available() else { return finish(.idle) }
    start(brew, store: store)
  }

  func retry(store: Store) {
    if let lastBrew { defaults.set(lastBrew.uuidString, forKey: Self.pendingKey) }
    stop()
    resume(store: store)
  }

  /// Stops the run and forgets the brew: the switch went off, the notice was declined, or the
  /// data is being erased.
  func cancel() {
    stop()
    finish(.idle)
  }

  private func stop() {
    job?.cancel()
    job = nil
    run = nil
  }

  private func finish(_ next: Status) {
    defaults.removeObject(forKey: Self.pendingKey)
    status = next
  }

  private func start(_ brew: Brew, store: Store) {
    status = .working
    let token = UUID()
    run = token
    let id = brew.id
    // Most people lock the phone right after saving, so ask iOS for the time it allows.
    let background = UIApplication.shared.beginBackgroundTask(withName: "Next Cup") { [weak self] in
      self?.job?.cancel()
    }
    job = Task {
      defer { UIApplication.shared.endBackgroundTask(background) }
      do {
        let outcome = try await ask(brew, store)
        try Task.checkCancellation()
        guard run == token, (try? store.find(Brew.self, id: id)) != nil else {
          throw CancellationError()
        }
        if case .failure(let failure) = NextCupAI.save(outcome.draft, store: store) {
          throw failure
        }
        job = nil
        finish(.idle)
      } catch {
        guard run == token else { return }
        job = nil
        failed(error)
      }
    }
  }

  private func failed(_ error: Error) {
    // iOS ended the background time: the brew stays waiting for the return to the app.
    if Task.isCancelled {
      status = .idle
    } else if error is CancellationError {
      finish(.idle)
    } else if case AIError.offline = error {
      // Cost nothing and may work later, so it stays waiting too.
      status = .failed(NextCupAIView.message(for: error))
    } else {
      finish(.failed(NextCupAIView.message(for: error)))
    }
  }
}
