import Foundation
import Observation

/// Navigation paths for the tabs that deep links can reach. The selected tab is
/// not held here: it lives in `@AppStorage` in `RootTabView` so it restores
/// after relaunch.
@MainActor
@Observable
final class AppRouter {
  var journalPath: [DeepLink] = []
  var recipesPath: [DeepLink] = []
  var beansPath: [DeepLink] = []
  var explorePath: [DeepLink] = []

  /// Replaces the destination tab's stack with the linked screen, so opening the
  /// same link twice never stacks duplicates.
  func open(_ link: DeepLink) {
    switch link.tab {
    case .journal: journalPath = [link]
    case .recipes: recipesPath = [link]
    case .beans: beansPath = [link]
    case .explore: break
    }
  }

  /// After a brew is saved: every tab back to its root, with the Journal on screen.
  func showJournal() {
    (journalPath, recipesPath, beansPath, explorePath) = ([], [], [], [])
    UserDefaults.standard.set(AppTab.journal.rawValue, forKey: AppTab.storageKey)
  }
}
