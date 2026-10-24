import Foundation
import SwiftData

enum MethodsError: Error, Equatable {
  case emptyName
  case duplicateName
  case saveFailed(String)

  var message: String {
    switch self {
    case .emptyName: "Give the method a name."
    case .duplicateName: "Another method already has that name."
    case .saveFailed(let reason): "The change could not be saved: \(reason)"
    }
  }
}

/// Add, rename, reorder and hide brew methods (S09). A method is never deleted:
/// hiding keeps every brew that used it, and the brew form still shows a hidden
/// method on a brew that already has it. A failed write is rolled back and
/// returned, so the list never shows a change that was not kept.
@MainActor
struct MethodsService {
  let store: Store

  private var context: ModelContext { store.context }

  func all() -> [BrewMethod] {
    let fetched = (try? context.fetch(FetchDescriptor<BrewMethod>())) ?? []
    return fetched.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
  }

  func add(
    name: String, style: BrewStyle, chosen: Set<BrewParameter>
  ) -> Result<BrewMethod, MethodsError> {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let problem = validate(trimmed, excluding: nil) { return .failure(problem) }
    let method = BrewMethod(name: trimmed, style: style)
    method.trackedParameters = MethodParameters.merged(existing: [], chosen: chosen)
    method.sortOrder = (all().map(\.sortOrder).max() ?? -1) + 1
    context.insert(method)
    return commit { method }
  }

  func update(
    _ method: BrewMethod, name: String, chosen: Set<BrewParameter>
  ) -> Result<Void, MethodsError> {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let problem = validate(trimmed, excluding: method.id) { return .failure(problem) }
    method.name = trimmed
    method.trackedParameters = MethodParameters.merged(
      existing: method.trackedParameters, chosen: chosen)
    method.updatedAt = Date()
    return commit { () }
  }

  func setHidden(_ method: BrewMethod, _ hidden: Bool) -> Result<Void, MethodsError> {
    method.isHidden = hidden
    method.updatedAt = Date()
    return commit { () }
  }

  /// Moves methods the way `onMove` reports it, then renumbers every method so
  /// `sortOrder` stays 0, 1, 2, ... with no gaps or ties.
  func move(from source: IndexSet, to destination: Int) -> Result<Void, MethodsError> {
    var ordered = all()
    ordered.move(fromOffsets: source, toOffset: destination)
    return renumber(ordered)
  }

  /// The non-gesture way to reorder: one place up (`-1`) or down (`1`).
  func step(_ method: BrewMethod, by offset: Int) -> Result<Void, MethodsError> {
    var ordered = all()
    guard let index = ordered.firstIndex(where: { $0.id == method.id }) else { return .success(()) }
    let target = index + offset
    guard ordered.indices.contains(target) else { return .success(()) }
    ordered.swapAt(index, target)
    return renumber(ordered)
  }

  // MARK: Private

  private func renumber(_ ordered: [BrewMethod]) -> Result<Void, MethodsError> {
    let now = Date()
    for (index, method) in ordered.enumerated() where method.sortOrder != index {
      method.sortOrder = index
      method.updatedAt = now
    }
    return commit { () }
  }

  private func validate(_ name: String, excluding id: UUID?) -> MethodsError? {
    if name.isEmpty { return .emptyName }
    let taken = all().contains {
      $0.id != id
        && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
    return taken ? .duplicateName : nil
  }

  private func commit<T>(_ value: () -> T) -> Result<T, MethodsError> {
    switch store.save() {
    case .success:
      return .success(value())
    case .failure(.saveFailed(let reason)):
      context.rollback()
      return .failure(.saveFailed(reason))
    }
  }
}
