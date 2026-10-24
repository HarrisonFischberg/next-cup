import SwiftUI

/// The tab shell. The selected tab persists in `UserDefaults` (not
/// `@SceneStorage`, which iOS discards when the user force-quits) and a
/// `nextcup://` link switches to its tab and pushes its placeholder screen.
struct RootTabView: View {
  @AppStorage(AppTab.storageKey) private var storedTab = AppTab.journal.rawValue
  @State private var router = AppRouter()

  private var selection: Binding<AppTab> {
    Binding(
      get: { AppTab(rawValue: storedTab) ?? .journal },
      set: { storedTab = $0.rawValue })
  }

  var body: some View {
    TabView(selection: selection) {
      ForEach(AppTab.allCases) { tab in
        Tab(tab.title, systemImage: tab.symbol, value: tab) {
          TabRoot(tab: tab, router: router)
        }
      }
    }
    .tint(DS.ink)
    .onOpenURL { handle($0) }
    #if DEBUG
      .task {
        // UI tests cannot send a URL to the app, so they pass one as an argument.
        // It goes through the same `handle` path as `onOpenURL`.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-deepLink"), index + 1 < arguments.count,
          let url = URL(string: arguments[index + 1])
        {
          handle(url)
        }
      }
    #endif
  }

  private func handle(_ url: URL) {
    guard let link = DeepLink(url: url) else { return }
    storedTab = link.tab.rawValue
    router.open(link)
  }
}

/// One tab's navigation stack. The tabs that deep links reach bind a path.
private struct TabRoot: View {
  let tab: AppTab
  @Bindable var router: AppRouter

  var body: some View {
    switch tab {
    case .journal: stack(path: $router.journalPath)
    case .recipes: stack(path: $router.recipesPath)
    case .beans: stack(path: $router.beansPath)
    case .explore, .settings: stack(path: nil)
    }
  }

  @ViewBuilder
  private func stack(path: Binding<[DeepLink]>?) -> some View {
    if let path {
      NavigationStack(path: path) { content }
    } else {
      NavigationStack { content }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch tab {
    case .recipes:
      RecipeLibraryView().navigationDestination(for: DeepLink.self, destination: destination)
    default:
      TabPlaceholder(tab: tab, router: router).navigationDestination(
        for: DeepLink.self, destination: destination)
    }
  }

  @ViewBuilder
  private func destination(for link: DeepLink) -> some View {
    switch link {
    case .recipe(let id): RecipeDetailView(link: link, recipeID: id)
    case .newBrew:
      // The marker sits behind the form: an identifier on the form itself would
      // replace the identifiers of the elements inside it.
      BrewFormView(seed: nil).background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    default: DestinationPlaceholder(link: link)
    }
  }
}

/// Stands in for each tab's screen until its task builds it.
private struct TabPlaceholder: View {
  let tab: AppTab
  let router: AppRouter

  var body: some View {
    ScrollView {
      EmptyState(
        title: tab.title, message: message,
        actionTitle: tab == .journal ? "Log a brew" : nil,
        action: tab == .journal ? { router.open(.newBrew) } : nil)
    }
    .background(DS.bg)
    .navigationTitle(tab.title)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("tab.root.\(tab.rawValue)")
  }

  private var message: String {
    switch tab {
    case .journal: "Your brews will be listed here."
    case .recipes: "Recipes you can follow and scale will be listed here."
    case .beans: "Your bags and roasters will be listed here."
    case .explore: "Recommendations and the flavor explorer will be here."
    case .settings: "Units, data and privacy controls will be here."
    }
  }
}

/// Stands in for a linked screen until its task builds it.
private struct DestinationPlaceholder: View {
  let link: DeepLink

  var body: some View {
    ScrollView {
      EmptyState(title: link.screenName, message: "This screen is not built yet.")
    }
    .background(DS.bg)
    .navigationTitle(link.screenName)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier(link.identifier)
  }
}
