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
  /// Counts requests for the top of the Brew tab, which the tab's page watches.
  var brewTopRequests = 0
  /// The bean Start brew picks when the recipe page opens, then cleared (Brew advice).
  var startBeanID: UUID?

  /// What Brew again brings to the Start brew page, then cleared.
  var startAgain: BrewAgainStart?

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

  /// The top of the Brew tab, where a new Next Cup's card is pinned.
  func showBrewTop() {
    recipesPath = []
    brewTopRequests += 1
    UserDefaults.standard.set(AppTab.recipes.rawValue, forKey: AppTab.storageKey)
  }

  /// A recipe's Start brew page on the Brew tab, with this bean already chosen.
  func startBrew(recipe: UUID, bean: UUID?) {
    startBeanID = bean
    recipesPath = [.recipe(recipe)]
    UserDefaults.standard.set(AppTab.recipes.rawValue, forKey: AppTab.storageKey)
  }

  /// Brew again: the brew's recipe on its Start brew page with the brew's dose, grind, bean
  /// and grinder. A deleted recipe is saved again first. False for a brew with no recipe to
  /// time (logged by hand), which the caller repeats on the brew form instead.
  func brewAgain(_ brew: Brew, store: Store) -> Bool {
    let recipe = brew.recipe ?? (try? store.restoreRecipe(for: brew).get())
    guard let recipe, !(recipe.steps ?? []).isEmpty else { return false }
    startAgain = BrewAgainStart(brew)
    startBrew(recipe: recipe.id, bean: nil)
    return true
  }

  /// After a brew is saved: every tab back to its root, with the Journal on screen.
  func showJournal(savedLater: String? = nil) {
    self.savedLater = savedLater
    (journalPath, recipesPath, beansPath, explorePath) = ([], [], [], [])
    UserDefaults.standard.set(AppTab.journal.rawValue, forKey: AppTab.storageKey)
  }
}

/// A saved brew's dose, grind, bean and grinder, for the Start brew page to open with.
struct BrewAgainStart: Equatable {
  var beanID: UUID?
  var doseG: Double?
  var grindSetting: String
  var grinderID: UUID?

  init(_ brew: Brew) {
    // Start brew takes one bean: a blend brings its first.
    beanID = brew.beans?.first?.bean?.id
    doseG = brew.doseG
    grindSetting = brew.grindSetting ?? ""
    grinderID = brew.grinder?.id
  }
}
