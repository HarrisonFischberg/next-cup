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
