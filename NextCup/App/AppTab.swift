import Foundation

/// The four tabs of the shell. Settings opens from the Journal's gear, so a
/// stored `settings` value from an older build falls back to Journal. The raw value is what is persisted
/// under `storageKey`, so it must never change once shipped.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
  case journal
  case recipes
  case beans
  case explore

  static let storageKey = "selectedTab"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .journal: "Journal"
    case .recipes: "Recipes"
    case .beans: "Beans"
    case .explore: "Explore"
    }
  }

  var symbol: String {
    switch self {
    case .journal: "book.closed"
    case .recipes: "list.bullet.rectangle"
    case .beans: "leaf"
    case .explore: "safari"
    }
  }
}
