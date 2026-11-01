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
  /// The draft a finished brew was just saved to for rating later, for the Journal's toast.
  var savedLater: String?

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

  /// The Brew tab, on this recipe.
  func showRecipe(_ id: UUID) {
    recipesPath = [.recipe(id)]
    UserDefaults.standard.set(AppTab.recipes.rawValue, forKey: AppTab.storageKey)
  }

  /// After a brew is saved: every tab back to its root, with the Journal on screen.
  func showJournal(savedLater: String? = nil) {
    self.savedLater = savedLater
    (journalPath, recipesPath, beansPath, explorePath) = ([], [], [], [])
    UserDefaults.standard.set(AppTab.journal.rawValue, forKey: AppTab.storageKey)
  }
}
