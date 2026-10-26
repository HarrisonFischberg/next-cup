import Foundation

/// The four tabs of the shell. Settings opens from the Journal's gear, so a
/// stored `settings` value from an older build falls back to Journal. The raw value is what is persisted
/// under `storageKey`, so it must never change once shipped.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
  /// Shown as "Brew"; the raw value stays "recipes" because it is persisted.
  case recipes
  case journal
  case beans
  case explore

  static let storageKey = "selectedTab"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .journal: "Journal"
    case .recipes: "Brew"
    case .beans: "Beans"
    case .explore: "Explore"
    }
  }

  var symbol: String {
    switch self {
    case .journal: "book.closed"
    case .recipes: "cup.and.saucer"
    case .beans: "leaf"
    case .explore: "safari"
    }
  }
}
