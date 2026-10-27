import Foundation
import SwiftData

enum StoreError: Error, Equatable {
  case saveFailed(String)
}

/// The data layer over a `ModelContext`. It owns the rule the schema cannot
/// carry (CloudKit forbids unique attributes): at most one row per `id`.
@MainActor
struct Store {
  let context: ModelContext

  /// Returns the row with this `id`, if any.
  func find<T: Identified>(_ type: T.Type, id: UUID) throws -> T? {
    try context.fetch(FetchDescriptor<T>()).first { $0.id == id }
  }

  /// Brews are the one table that keeps growing, so this lookup asks the store for
  /// the one row instead of loading every brew.
  func find(_ type: Brew.Type, id: UUID) throws -> Brew? {
    var descriptor = FetchDescriptor<Brew>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  /// Updates the row with this `id`, or inserts a new one. `update` runs in both
  /// cases and `updatedAt` is stamped, so importing the same data twice is a no-op
  /// on row count.
  @discardableResult
  func upsert<T: Identified>(
    _ type: T.Type, id: UUID, make: () -> T, update: (T) -> Void
  ) throws -> T {
    let model: T
    if let existing = try find(type, id: id) {
      model = existing
    } else {
      model = make()
      model.id = id
      context.insert(model)
    }
    update(model)
    model.updatedAt = Date()
    return model
  }

  /// Saves pending changes. A failure is returned, never swallowed, so callers
  /// keep the draft and show the error (X5).
  func save() -> Result<Void, StoreError> {
    do {
      try context.save()
      return .success(())
    } catch {
      return .failure(.saveFailed(error.localizedDescription))
    }
  }
}
