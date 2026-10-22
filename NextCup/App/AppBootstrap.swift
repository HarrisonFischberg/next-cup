import Foundation
import SwiftData

/// Opens the store and seeds the bundled methods and recipes at launch.
@MainActor
enum AppBootstrap {
  /// `-inMemoryStore` gives UI tests a fresh store that never touches real data.
  static var usesInMemoryStore: Bool {
    ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
  }

  /// A failure to open or seed is returned, never swallowed, so the app can
  /// say so and offer a retry.
  static func start(
    inMemory: Bool = usesInMemoryStore, defaults: UserDefaults? = nil,
    bundle: Bundle = .main
  ) -> Result<ModelContainer, StartupError> {
    do {
      let container = try NextCupContainer.make(inMemory: inMemory)
      let content = try BuiltInContent(bundle: bundle)
      // The offered-keys ledger must not outlive an in-memory store, or a second
      // test launch would find the ledger full and seed nothing.
      let ledger =
        defaults
        ?? (inMemory
          ? UserDefaults(suiteName: "nextcup.inmemory.\(UUID().uuidString)") ?? .standard
          : .standard)
      let seeder = BuiltInSeeder(store: Store(context: container.mainContext), defaults: ledger)
      if case .failure(let error) = seeder.seed(content) {
        return .failure(.init(message: describe(error)))
      }
      return .success(container)
    } catch {
      return .failure(.init(message: error.localizedDescription))
    }
  }

  private static func describe(_ error: StoreError) -> String {
    switch error {
    case .saveFailed(let message): message
    }
  }
}

struct StartupError: Error, Equatable {
  let message: String
}
