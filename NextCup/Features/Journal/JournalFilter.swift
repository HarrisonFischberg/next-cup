import Foundation
import NextCupKit

enum JournalSort: String, CaseIterable, Identifiable {
  case newest, oldest, topGrade

  var id: String { rawValue }

  var title: String {
    switch self {
    case .newest: "Newest first"
    case .oldest: "Oldest first"
    case .topGrade: "Highest rating"
    }
  }
}

/// What the journal list shows: search text, an optional method and bean, and an
/// order. Pure over `Brew` rows so the rules test without a view.
struct JournalFilter: Equatable {
  var search = ""
  var methodID: UUID?
  var beanName: String?
  var sort = JournalSort.newest

  private var term: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// True when something narrows the list, so "no results" can offer a way out.
  var isNarrowing: Bool { methodID != nil || beanName != nil || !term.isEmpty }

  func apply(to brews: [Brew]) -> [Brew] {
    let kept = brews.filter(matches)
    switch sort {
    case .newest: return kept.sorted { $0.date > $1.date }
    case .oldest: return kept.sorted { $0.date < $1.date }
    case .topGrade:
      return kept.sorted {
        let (a, b) = ($0.ratingTenths ?? 0, $1.ratingTenths ?? 0)
        return a == b ? $0.date > $1.date : a > b
      }
    }
  }

  private func matches(_ brew: Brew) -> Bool {
    if let methodID, brew.method?.id != methodID { return false }
    if let beanName, !brew.beanNames.contains(beanName) { return false }
    guard !term.isEmpty else { return true }
    var fields: [String?] = [
      brew.notes, brew.method?.name, brew.recipe?.name, brew.grindSetting, brew.verdict?.rawValue,
    ]
    fields += brew.beanNames
    return fields.contains { $0?.localizedStandardContains(term) == true }
  }
}

extension Brew {
  /// Bean names as they were when the brew was logged.
  var beanNames: [String] {
    (beans ?? []).map(\.beanNameSnapshot).filter { !$0.isEmpty }
  }
}

extension DraftStore {
  /// A saved brew's edit draft, kept apart from the new-brew draft.
  static func editing(_ id: UUID) -> DraftStore {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return DraftStore(
      fileURL: base.appendingPathComponent("Drafts", isDirectory: true)
        .appendingPathComponent("brew-edit-\(id.uuidString).json"))
  }
}
