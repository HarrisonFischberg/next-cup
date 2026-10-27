import Foundation
import NextCupKit
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
      if !inMemory, case .failure(let error) = RatingMigration.run(container.mainContext) {
        return .failure(.init(message: describe(error)))
      }
      #if DEBUG
        // Screenshots only: a few sample brews in the throwaway in-memory store.
        if inMemory, ProcessInfo.processInfo.arguments.contains("-demoBrews") {
          DemoBrews.insert(into: container.mainContext)
        }
      #endif
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

/// Ratings moved from half points out of 5 to tenths out of 10: 4 of 5 (8) becomes 8.0 of 10
/// (80). Runs once, before anything can save a rating on the new scale, then remembers it ran.
@MainActor
enum RatingMigration {
  static let doneKey = "rating.tenthsMigrated"

  static func run(
    _ context: ModelContext, defaults: UserDefaults = .standard,
    drafts: DraftStore = .standard()
  ) -> Result<Void, StoreError> {
    guard !defaults.bool(forKey: doneKey) else { return .success(()) }
    for brew in (try? context.fetch(FetchDescriptor<Brew>())) ?? [] {
      brew.ratingTenths = brew.ratingTenths.map { $0 * 10 }
    }
    for bean in (try? context.fetch(FetchDescriptor<Bean>())) ?? [] {
      bean.ratingTenths = bean.ratingTenths.map { $0 * 10 }
    }
    if case .failure(let error) = Store(context: context).save() { return .failure(error) }
    if case .draft(var draft) = drafts.load() {
      draft.ratingTenths *= 10
      _ = drafts.save(draft)
    }
    defaults.set(true, forKey: doneKey)
    return .success(())
  }
}

struct StartupError: Error, Equatable {
  let message: String
}

#if DEBUG
  enum DemoBrews {
    static func insert(into context: ModelContext) {
      let methods = (try? context.fetch(FetchDescriptor<BrewMethod>())) ?? []
      let samples: [(String, Int, Double, Double, Int, Int, Verdict)] = [
        ("Geometry", 0, 15, 250, 185, 88, .balanced),
        ("Kenya Rukira", 1, 18, 300, 240, 79, .sour),
        ("Monarch", 1, 18, 290, 200, 68, .bitter),
        ("Geometry", 3, 15, 250, 200, 81, .balanced),
        ("Southern Weather", 4, 20, 320, 210, 72, .weak),
      ]
      for (name, daysAgo, dose, water, time, grade, verdict) in samples {
        let brew = Brew(
          date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
            .addingTimeInterval(-3600))
        brew.doseG = dose
        brew.waterG = water
        brew.totalTimeS = time
        brew.ratingTenths = grade
        brew.verdict = verdict
        brew.method = methods.first
        let part = BrewBean(grams: dose, beanNameSnapshot: name)
        brew.beans = [part]
        context.insert(brew)
      }
      try? context.save()
    }
  }
#endif
