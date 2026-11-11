import NextCupKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum BackupStatus {
  static let errorKey = "backup.lastError"

  /// Writes today's backup if there is none yet. A failure is remembered and
  /// shown in Settings instead of being dropped. Rows are read on the main thread;
  /// encoding them, every photo included, runs off it so launch never freezes.
  @MainActor static func runDaily(_ container: ModelContainer, defaults: UserDefaults = .standard) {
    let backups = BackupStore.standard()
    guard !backups.hasBackup() else { return }
    let archive: DataArchive
    do {
      archive = try DataExporter(store: Store(context: container.mainContext)).archive()
    } catch {
      defaults.set(error.localizedDescription, forKey: errorKey)
      return
    }
    Task {
      let failure = await Task.detached(priority: .utility) { () -> String? in
        do {
          try backups.backUp { try DataExporter.encode(archive) }
          return nil
        } catch {
          return error.localizedDescription
        }
      }.value
      if let failure {
        defaults.set(failure, forKey: errorKey)
      } else {
        defaults.removeObject(forKey: errorKey)
      }
    }
  }
}

/// Settings → Your data: export, merge import, backups and delete all.
struct DataSettingsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(BackupStatus.errorKey) private var backupError = ""
  @State private var shared: SharedFiles?
  @State private var showImporter = false
  @State private var plan: ImportPlan?
  @State private var message: String?
  @State private var errorMessage: String?
  @State private var backups: [BackupStore.Backup] = []
  @State private var erasedSnapshot: DataArchive?
  @State private var undoTimer: Task<Void, Never>?
  /// Export and import show their real stages: they are where trust matters most.
  @State private var stages: [String]?
  @State private var stage = 0

  private static let undoSeconds = 8

  private var store: Store { Store(context: context) }

  var body: some View {
    List {
      if let errorMessage {
        StateBanner(kind: .error, message: errorMessage, actionTitle: "Dismiss") {
          self.errorMessage = nil
        }
        .accessibilityIdentifier("data.error")
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
      }
      if let message {
        Text(message).font(.footnote).foregroundStyle(DS.ink)
          .accessibilityIdentifier("data.message")
          .listRowBackground(DS.paper)
      }
      if let stages {
        StagedProgress(stages: stages, current: stage)
          .listRowBackground(DS.paper)
      }
      exportSection
      importSection
      backupSection
      deleteSection
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .safeAreaInset(edge: .bottom, spacing: 0) { toast }
    .navigationTitle("Your data")
    .navigationBarTitleDisplayMode(.inline)
    .task { backups = BackupStore.standard().list() }
    .background {
      Color.clear.sheet(item: $shared, onDismiss: removeExport) { ActivityView(items: $0.urls) }
    }
    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url): open(url)
      case .failure(let error): errorMessage = error.localizedDescription
      }
    }
    .sheet(item: Binding(get: { plan.map(PlanBox.init) }, set: { if $0 == nil { plan = nil } })) {
      box in
      ImportPreviewView(plan: box.plan) { overwrite in
        let result = DataImporter(store: store).apply(box.plan, overwrite: overwrite)
        switch result {
        case .success(let summary):
          message = "Imported \(summary.added) new and replaced \(summary.replaced)."
          errorMessage = nil
          prepare()
        case .failure(.saveFailed(let reason)):
          errorMessage = "Nothing was imported. \(reason)"
        }
        plan = nil
      } cancel: {
        plan = nil
      }
    }
  }

  // MARK: Sections

  private var exportSection: some View {
    Section {
      Button {
        export { [$0.json] }
      } label: {
        row("Export everything (JSON)", "Lossless; can be imported again")
      }
      .listRowBackground(DS.paper).accessibilityIdentifier("data.export.json")
      Button {
        export { $0.csv }
      } label: {
        row("Export for a spreadsheet (CSV)", "Brews and beans")
      }
      .listRowBackground(DS.paper).accessibilityIdentifier("data.export.csv")
    } header: {
      Text("Export")
    } footer: {
      Text(
        "Photos are included in the JSON file only. "
          + "The file is deleted when you close the share sheet.")
    }
  }

  private var importSection: some View {
    Section {
      Button {
        showImporter = true
      } label: {
        row("Import a Next Cup file", "You review every change before it is saved")
      }
      .listRowBackground(DS.paper).accessibilityIdentifier("data.import")
    } header: {
      Text("Import")
    }
  }

  private var backupSection: some View {
    Section {
      if !backupError.isEmpty {
        Text("The last automatic backup failed: \(backupError)").font(.footnote)
          .foregroundStyle(DS.ink).listRowBackground(DS.paper)
          .accessibilityIdentifier("data.backup.error")
      }
      if backups.isEmpty {
        Text("No backups yet. One is made on the first launch of each day.")
          .font(.footnote).foregroundStyle(DS.ink2).listRowBackground(DS.paper)
          .accessibilityIdentifier("data.backup.empty")
      }
      ForEach(backups) { backup in
        Button {
          open(backup.url)
        } label: {
          row(backup.name.replacingOccurrences(of: "backup-", with: ""), "Review and restore")
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("data.backup.\(backup.name)")
      }
    } header: {
      Text("Automatic backups")
    } footer: {
      Text("The newest 7 daily backups are kept on this device.")
    }
  }

  private var deleteSection: some View {
    Section {
      Button(role: .destructive) {
        eraseAll()
      } label: {
        row("Delete all data", "Journal, beans, recipes, drafts, backups and AI keys")
      }
      .listRowBackground(DS.paper).accessibilityIdentifier("data.deleteAll")
    } header: {
      Text("Delete")
    } footer: {
      Text("You can undo for a few seconds. Backups and keys cannot be restored.")
    }
  }

  private func row(_ title: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(DS.Font.headline).foregroundStyle(DS.ink)
      Text(detail).font(.footnote).foregroundStyle(DS.ink2)
    }
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
  }

  // MARK: Actions

  private func prepare() {
    backups = BackupStore.standard().list()
  }

  /// The files exist only between the tap and the closing of the share sheet.
  private func export(_ pick: @escaping (DataExporter.Files) -> [URL]) {
    guard stages == nil else { return }
    Task {
      var start = Date()
      let brews =
        (try? context.fetchCount(FetchDescriptor<Brew>())) ?? 0
      let beans = (try? context.fetchCount(FetchDescriptor<Bean>())) ?? 0
      stages = [
        "Gathering \(brews) \(brews == 1 ? "brew" : "brews") and \(beans) \(beans == 1 ? "bean" : "beans")",
        "Writing the file", "Ready to share",
      ]
      stage = 0
      await StagedProgress.hold(since: start)
      stage = 1
      start = Date()
      do {
        let files = try DataExporter(store: store).write(
          into: FileManager.default.temporaryDirectory)
        await StagedProgress.hold(since: start)
        stage = 2
        shared = SharedFiles(urls: pick(files))
        errorMessage = nil
      } catch {
        errorMessage = "The export could not be prepared. \(error.localizedDescription)"
      }
      stages = nil
    }
  }

  private func removeExport() {
    try? FileManager.default.removeItem(
      at: FileManager.default.temporaryDirectory.appendingPathComponent("NextCupExport"))
  }

  private func open(_ url: URL) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      stages = ["Checking the file", "Comparing with your journal", "Ready to review"]
      stage = 0
      let archive = try DataImporter.decode(Data(contentsOf: url))
      stage = 1
      let checked = try DataImporter(store: store).plan(for: archive)
      stage = 2
      Task {
        // Long enough to read the stages; the review sheet then shows the counts.
        try? await Task.sleep(for: .milliseconds(600))
        stages = nil
        plan = checked
      }
      errorMessage = nil
    } catch {
      stages = nil
      errorMessage = error.localizedDescription
    }
  }

  // MARK: Delete all with Undo

  @ViewBuilder private var toast: some View {
    if erasedSnapshot != nil {
      SteelToast(message: "All data deleted", actionTitle: "Undo", action: undoErase)
        .padding(.horizontal, DS.Space.lg).padding(.bottom, DS.Space.sm)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("data.toast")
    }
  }

  private func eraseAll() {
    guard let content = try? BuiltInContent(bundle: .main) else {
      errorMessage = "The built-in recipes could not be loaded, so nothing was deleted."
      return
    }
    let eraser = DataEraser(
      store: store, defaults: .standard,
      defaultsDomain: Bundle.main.bundleIdentifier ?? "NextCup",
      draftsDirectory: DraftDirectory.url, backups: .standard(),
      externalData: DataEraser.externalDataDirectory(of: context))
    switch eraser.eraseAll(reseeding: content) {
    case .success(let snapshot):
      Feedback.success()
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { erasedSnapshot = snapshot }
      message = nil
      prepare()
      undoTimer?.cancel()
      undoTimer = Task {
        try? await Task.sleep(for: .seconds(Self.undoSeconds))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { erasedSnapshot = nil }
      }
    case .failure(.saveFailed(let reason)):
      errorMessage = "Nothing was deleted. \(reason)"
    }
  }

  private func undoErase() {
    undoTimer?.cancel()
    guard let snapshot = erasedSnapshot else { return }
    let importer = DataImporter(store: store)
    do {
      let restore = try importer.plan(for: snapshot)
      switch importer.apply(restore, overwrite: Set(restore.conflicts.map(\.id))) {
      case .success: message = "Your data is back. Backups and keys were not restored."
      case .failure(.saveFailed(let reason)): errorMessage = "Undo failed. \(reason)"
      }
    } catch {
      errorMessage = error.localizedDescription
    }
    Feedback.tap()
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { erasedSnapshot = nil }
    prepare()
  }
}

private struct PlanBox: Identifiable {
  let id = UUID()
  let plan: ImportPlan
}

private struct SharedFiles: Identifiable {
  let id = UUID()
  let urls: [URL]
}

/// The system share sheet. `ShareLink` needs its files to exist before the tap.
private struct ActivityView: UIViewControllerRepresentable {
  let items: [URL]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

enum DraftDirectory {
  /// The folder the brew form keeps its drafts in.
  static var url: URL {
    DraftStore.standard().fileURL.deletingLastPathComponent()
  }
}

/// Shows what an import would do. Conflicts keep the local version unless the
/// user turns on "Use imported version" for that row.
private struct ImportPreviewView: View {
  let plan: ImportPlan
  let apply: (Set<UUID>) -> Void
  let cancel: () -> Void
  @State private var overwrite: Set<UUID> = []
  @State private var isApplying = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          summary("New", plan.newCount)
          summary("Already here", plan.sameCount)
          summary("Differ from what you have", plan.conflicts.count)
        } header: {
          Text("This file contains")
        }
        if !plan.conflicts.isEmpty {
          Section {
            ForEach(plan.conflicts) { item in
              Toggle(
                isOn: Binding(
                  get: { overwrite.contains(item.id) },
                  set: { if $0 { overwrite.insert(item.id) } else { overwrite.remove(item.id) } })
              ) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title).font(DS.Font.headline).foregroundStyle(DS.ink)
                  Text(item.label).font(.footnote).foregroundStyle(DS.ink2)
                }
              }
              .frame(minHeight: DS.Size.control)
              .listRowBackground(DS.paper)
              .accessibilityIdentifier("import.conflict.\(item.id.uuidString)")
            }
          } header: {
            Text("Use imported version")
          } footer: {
            Text("Left off, your current version is kept.")
          }
        }
        Section {
          SteelButton(title: "Import", isLoading: isApplying) {
            isApplying = true
            apply(overwrite)
          }
          .accessibilityIdentifier("import.apply")
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(DS.bg)
      .navigationTitle("Import")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
      }
    }
    .accessibilityIdentifier("import.preview")
  }

  private func summary(_ title: String, _ count: Int) -> some View {
    HStack {
      Text(title).foregroundStyle(DS.ink)
      Spacer()
      Text("\(count)").font(DS.Font.data).foregroundStyle(DS.ink)
    }
    .listRowBackground(DS.paper)
    .accessibilityElement(children: .combine)
  }
}
