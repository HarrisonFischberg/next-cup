import NextCupKit
import SwiftData
import SwiftUI

@main
struct NextCupApp: App {
  @State private var startup = AppBootstrap.start()

  init() {
    // UI tests start from a known tab; relaunches in the same test omit this.
    if ProcessInfo.processInfo.arguments.contains("-resetNavigationState") {
      UserDefaults.standard.removeObject(forKey: AppTab.storageKey)
      JournalStorage.reset()
    }
    // UI tests start without a draft left by an earlier test; relaunches omit this.
    if ProcessInfo.processInfo.arguments.contains("-resetDraft") {
      _ = DraftStore.standard().clear()
    }
  }

  var body: some Scene {
    WindowGroup {
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
