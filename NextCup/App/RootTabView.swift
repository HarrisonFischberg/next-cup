import NextCupKit
import SwiftData
import SwiftUI

/// The tab shell. The selected tab persists in `UserDefaults` (not
/// `@SceneStorage`, which iOS discards when the user force-quits) and a
/// `nextcup://` link switches to its tab and pushes its placeholder screen.
struct RootTabView: View {
  @AppStorage(AppTab.storageKey) private var storedTab = AppTab.journal.rawValue
  @State private var router = AppRouter()
  @AppStorage(OnboardingView.doneKey) private var onboarded = false
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  /// Set once onboarding finishes; until then the first-run check decides, so a fresh
  /// install opens straight on Step 1 with no frame of the tabs behind it.
  @State private var onboardingFinished = false

  private var selection: Binding<AppTab> {
    Binding(
      get: { AppTab(rawValue: storedTab) ?? .journal },
      set: { storedTab = $0.rawValue })
  }

  private var showsOnboarding: Bool {
    !onboardingFinished && Self.needsOnboarding(onboarded: onboarded, context: context)
  }

  var body: some View {
    Group {
      if showsOnboarding {
        OnboardingView { tab in
          storedTab = tab.rawValue
          onboardingFinished = true
          // One brew type goes straight to its styles; several land on the Brew page to pick.
          if tab == .recipes {
            let shown = (try? context.fetch(FetchDescriptor<BrewMethod>()))?.filter {
              !$0.isHidden
            }
            if let shown, shown.count == 1, let only = shown.first {
              router.open(.method(only.id))
            }
          }
        }
        .transition(.opacity)
      } else {
        tabs
      }
    }
    .onOpenURL { handle($0) }
    // Picks up a Next Cup that iOS stopped in the background or that had no connection.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { NextCupAuto.shared.resume(store: Store(context: context)) }
    }
    .onAppear {
      // Someone upgrading with brews already logged counts as set up, so the check stops.
      if !onboarded, !showsOnboarding, !AppBootstrap.usesInMemoryStore { onboarded = true }
      // A new look rebuilds the whole tree; reopen Settings where the change was made.
      guard UserDefaults.standard.bool(forKey: FlavorPicker.returnKey) else { return }
      handle(DeepLink.settings.url)
    }
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
        // Screenshots: `-openRecipe <built-in key>` opens that recipe's Start brew page.
        if let index = arguments.firstIndex(of: "-openRecipe"), index + 1 < arguments.count,
          let recipe = try? context.fetch(FetchDescriptor<Recipe>()).first(where: {
            $0.builtInKey == arguments[index + 1]
          })
        {
          handle(DeepLink.recipe(recipe.id).url)
        }
        // Screenshots: `-openFirstBrew` opens a saved brew, as the Journal does.
        if arguments.contains("-openFirstBrew"),
          let brew = try? context.fetch(FetchDescriptor<Brew>()).first
        {
          handle(DeepLink.brew(brew.id).url)
        }
      }
    #endif
  }

  private var tabs: some View {
    TabView(selection: selection) {
      ForEach(AppTab.allCases) { tab in
        Tab(tab.title, systemImage: tab.symbol, value: tab) {
          TabRoot(tab: tab, router: router)
        }
      }
    }
    .environment(router)
    .tint(DS.ink)
    // The ink tint is white in dark looks, so an on switch would vanish; switches use the accent.
    .toggleStyle(SwitchToggleStyle(tint: DS.accent))
  }

  /// First run only: someone upgrading with brews already logged never sees it.
  /// UI tests skip it unless they ask for it.
  private static func needsOnboarding(onboarded: Bool, context: ModelContext) -> Bool {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-showOnboarding") { return true }
    guard !onboarded, !AppBootstrap.usesInMemoryStore else { return false }
    return ((try? context.fetchCount(FetchDescriptor<Brew>())) ?? 0) == 0
  }

  private func handle(_ url: URL) {
    guard let link = DeepLink(url: url) else { return }
    // The Live Activity or Siri reopening the brew already on screen: keep that screen, so
    // its music, bean and grinder carry on instead of a fresh timer replacing it.
    if case .timer(let id, _) = link, id == TimerView.showing { return }
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
    case .explore: stack(path: $router.explorePath)
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
    case .journal:
      JournalListView(router: router).navigationDestination(
        for: DeepLink.self, destination: destination)
    case .recipes:
      RecipeLibraryView().navigationDestination(for: DeepLink.self, destination: destination)
    case .beans:
      BeanLibraryView().navigationDestination(for: DeepLink.self, destination: destination)
    case .explore:
      ExploreView().navigationDestination(for: DeepLink.self, destination: destination)
    }
  }

  @ViewBuilder
  private func destination(for link: DeepLink) -> some View {
    switch link {
    case .recipe(let id): RecipeDetailView(link: link, recipeID: id)
    case .method(let id): MethodStylesView(link: link, methodID: id)
    case .newBrew:
      // The marker sits behind the form: an identifier on the form itself would
      // replace the identifiers of the elements inside it.
      BrewFormView(seed: nil).background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    case .brew(let id): BrewDestination(link: link, brewID: id)
    case .brewAgain(let id): BrewDestination(link: link, brewID: id, repeats: true)
    case .bean(let id): BeanDestination(link: link, beanID: id)
    case .timer(let id, let doseG): TimerDestination(link: link, recipeID: id, doseG: doseG)
    case .settings: SettingsRootView()
    case .taste(let id): TasteDestination(link: link, brewID: id)
    case .unsaved(let name): UnsavedDestination(link: link, fileName: name)
    }
  }
}

/// The taste screen for a saved brew; a brew that is gone says so.
private struct TasteDestination: View {
  let link: DeepLink
  let brewID: UUID
  @Environment(\.modelContext) private var context

  var body: some View {
    if let brew = try? Store(context: context).find(Brew.self, id: brewID) {
      TasteView(brew: brew).background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    } else {
      ScrollView {
        EmptyState(
          title: "Brew not found",
          message: "This brew is no longer in your journal. It may have been deleted.")
      }
      .background(DS.bg)
      .navigationTitle(link.screenName)
      .accessibilityIdentifier(link.identifier)
    }
  }
}

/// Reopens an unsaved brew from the Journal with what was typed. One that was
/// saved or discarded meanwhile, or whose saved brew is gone, says so.
private struct UnsavedDestination: View {
  let link: DeepLink
  let fileName: String
  @Environment(\.modelContext) private var context
  /// Read once, so the form keeps its file while it rewrites it.
  @State private var entry: SavedDraft?

  init(link: DeepLink, fileName: String) {
    self.link = link
    self.fileName = fileName
    _entry = State(
      initialValue: DraftStore.all().first {
        $0.store.fileURL.deletingPathExtension().lastPathComponent == fileName
      })
  }

  var body: some View {
    if let entry, let resumed = form(entry) {
      resumed.background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    } else {
      ScrollView {
        EmptyState(
          title: "Unsaved brew not found",
          message: "It was saved or discarded, or its brew was deleted.")
      }
      .background(DS.bg)
      .navigationTitle(link.screenName)
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier(link.identifier)
    }
  }

  private func form(_ entry: SavedDraft) -> BrewFormView? {
    let store = Store(context: context)
    switch entry.kind {
    case .newBrew:
      return BrewFormView(seed: nil, resuming: entry.store)
    case .editing(let id):
      guard let brew = try? store.find(Brew.self, id: id) else { return nil }
      return BrewFormView(seed: nil, editing: brew, resuming: entry.store)
    case .repeating(let id):
      guard let source = try? store.find(Brew.self, id: id) else { return nil }
      return BrewFormView(seed: nil, repeating: source, resuming: entry.store)
    }
  }
}

/// Opens a saved brew for editing, or a new brew that repeats it. A link to a
/// brew that no longer exists lands on a screen that says so, never on a blank
/// form.
private struct BrewDestination: View {
  let link: DeepLink
  let brewID: UUID
  var repeats = false
  @Environment(\.modelContext) private var context

  var body: some View {
    if let brew = try? Store(context: context).find(Brew.self, id: brewID) {
      BrewFormView(
        seed: nil, editing: repeats ? nil : brew, repeating: repeats ? brew : nil
      ).background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    } else {
      ScrollView {
        EmptyState(
          title: "Brew not found",
          message: "This brew is no longer in your journal. It may have been deleted.")
      }
      .background(DS.bg)
      .navigationTitle(link.screenName)
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier(link.identifier)
    }
  }
}
