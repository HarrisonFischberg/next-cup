import NextCupKit
import SwiftData
import SwiftUI

@main
struct NextCupApp: App {
  @State private var startup = AppBootstrap.start()
  @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue
  @AppStorage(AppStyle.storageKey) private var style = AppStyle.bloom.rawValue
  @AppStorage(MakeItYours.accentKey) private var accent = ""
  @AppStorage(MakeItYours.cornersKey) private var corners = ""
  @AppStorage(MakeItYours.densityKey) private var density = ""
  @AppStorage(MakeItYours.fontKey) private var font = ""

  init() {
    AppStyle.adoptBloomOnce()
    // UI tests start from a known tab; relaunches in the same test omit this.
    if ProcessInfo.processInfo.arguments.contains("-resetNavigationState") {
      UserDefaults.standard.removeObject(forKey: AppTab.storageKey)
      JournalStorage.reset()
      UserDefaults.standard.removeObject(forKey: GettingStartedCard.dismissedKey)
      UserDefaults.standard.removeObject(forKey: FlavorPicker.returnKey)
    }
    // UI tests start without a draft left by an earlier test; relaunches omit this.
    if ProcessInfo.processInfo.arguments.contains("-resetDraft") {
      _ = DraftStore.standard().clear()
    }
  }

  var body: some Scene {
    WindowGroup {
      Group {
        switch startup {
        case .success(let container):
          RootTabView()
            .modelContainer(container)
            .task {
              AIQueue.expireStale(in: container.mainContext)
              if !AppBootstrap.usesInMemoryStore { BackupStatus.runDaily(container) }
            }
        case .failure(let error):
          StartupFailureView(error: error) { startup = AppBootstrap.start() }
        }
      }
      .preferredColorScheme((AppearanceMode(rawValue: appearance) ?? .system).colorScheme)
      .environment(\.flavor, AppStyle.current.flavor)
      .fontDesign(AppStyle.current.flavor.bodyDesign)
      // DS tokens are read, not observed, so a new flavor or Make It Yours choice rebuilds the tree.
      .id([style, accent, corners, density, font].joined(separator: "|"))
    }
  }
}

/// Shown when the store cannot open. Nothing is deleted; the user can retry.
struct StartupFailureView: View {
  let error: StartupError
  let retry: () -> Void

  var body: some View {
    VStack {
      EmptyState(
        title: "Can't open your journal",
        message: "Your data has not been changed. \(error.message)",
        actionTitle: "Try again", action: retry)
      Spacer()
    }
    .background(DS.bg)
    .accessibilityIdentifier("startup.failure")
  }
}
