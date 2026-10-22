import Foundation

/// The five tabs of the shell (blueprint §4). The raw value is what is persisted
/// under `storageKey`, so it must never change once shipped.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
  case journal
  case recipes
  case beans
  case explore
  case settings

  static let storageKey = "selectedTab"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .journal: "Journal"
    case .recipes: "Recipes"
    case .beans: "Beans"
    case .explore: "Explore"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .journal: "book.closed"
    case .recipes: "list.bullet.rectangle"
    case .beans: "leaf"
    case .explore: "safari"
    case .settings: "gearshape"
    }
  }
}
