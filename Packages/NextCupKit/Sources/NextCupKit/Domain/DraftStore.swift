import Foundation

public enum DraftError: Error, Equatable, Sendable {
  case writeFailed(String)
  case removeFailed(String)
}

/// What `DraftStore.load` found.
public enum DraftLoad: Equatable, Sendable {
  case none
  case draft(BrewDraft)
  /// The file could not be read as a draft. It was removed so the form opens
  /// blank, and the caller says so instead of crashing.
  case discardedCorrupt
}

/// A draft file found in the drafts folder, for the Journal's Unsaved brews.
public struct SavedDraft: Identifiable, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case newBrew
    /// Unsaved changes to the saved brew with this id.
    case editing(UUID)
    /// A Brew again of the saved brew with this id.
    case repeating(UUID)
  }

  public let kind: Kind
  public let draft: BrewDraft
  /// When the draft was last written.
  public let changedAt: Date
  public let store: DraftStore

  public var id: URL { store.fileURL }

  public static func == (lhs: SavedDraft, rhs: SavedDraft) -> Bool {
    lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.draft == rhs.draft
      && lhs.changedAt == rhs.changedAt
  }
}

/// Autosaves the open brew form as one JSON file in Application Support
/// (blueprint §3a). Writes are atomic and return a result, so the form can show
/// a failure and keep the draft in memory.
public struct DraftStore: Sendable {
  public typealias Writer = @Sendable (Data, URL) throws -> Void

  public let fileURL: URL
  private let write: Writer

  /// Posted after a draft file is written or removed, so lists of drafts refresh.
  public static let didChange = Notification.Name("NextCup.DraftStore.didChange")

  public init(fileURL: URL, write: @escaping Writer = DraftStore.atomicWrite) {
    self.fileURL = fileURL
    self.write = write
  }

  /// The draft file in the app's Application Support folder.
  public static func standard() -> DraftStore {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return DraftStore(
      fileURL: base.appendingPathComponent("Drafts", isDirectory: true)
        .appendingPathComponent("brew-draft.json"))
  }

  /// The draft file for a repeat of the saved brew `sourceID`, kept apart from
  /// the new-brew draft so starting a repeat never overwrites unsaved typing.
  public static func repeating(_ sourceID: UUID) -> DraftStore {
    let standard = DraftStore.standard().fileURL
    return DraftStore(
      fileURL: standard.deletingLastPathComponent()
        .appendingPathComponent("brew-again-\(sourceID.uuidString).json"))
  }

  /// A saved brew's edit draft, kept apart from the new-brew draft.
  public static func editing(_ id: UUID) -> DraftStore {
    let standard = DraftStore.standard().fileURL
    return DraftStore(
      fileURL: standard.deletingLastPathComponent()
        .appendingPathComponent("brew-edit-\(id.uuidString).json"))
  }

  /// Every readable draft in `directory` (the standard drafts folder by default),
  /// most recently changed first. Files that are not drafts are skipped.
  public static func all(in directory: URL? = nil) -> [SavedDraft] {
    let folder = directory ?? DraftStore.standard().fileURL.deletingLastPathComponent()
    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    let standardName = DraftStore.standard().fileURL.lastPathComponent
    return files.compactMap { url -> SavedDraft? in
      let name = url.deletingPathExtension().lastPathComponent
      let kind: SavedDraft.Kind
      if url.lastPathComponent == standardName {
        kind = .newBrew
      } else if name.hasPrefix("brew-edit-"), let id = UUID(uuidString: String(name.dropFirst(10))) {
        kind = .editing(id)
      } else if name.hasPrefix("brew-again-"), let id = UUID(uuidString: String(name.dropFirst(11))) {
        kind = .repeating(id)
      } else {
        return nil
      }
      let store = DraftStore(fileURL: url)
      guard case .draft(let draft) = store.load() else { return nil }
      let changed =
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? draft.date
      return SavedDraft(kind: kind, draft: draft, changedAt: changed, store: store)
    }
    .sorted { $0.changedAt > $1.changedAt }
  }

  public static let atomicWrite: Writer = { data, url in
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Not .completeFileProtection: a draft saved as the phone locks must not be lost.
    try data.write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  public func save(_ draft: BrewDraft) -> Result<Void, DraftError> {
    do {
      try write(try JSONEncoder().encode(draft), fileURL)
      NotificationCenter.default.post(name: Self.didChange, object: nil)
      return .success(())
    } catch {
      return .failure(.writeFailed(error.localizedDescription))
    }
  }

  public func load() -> DraftLoad {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return .none }
    guard let data = try? Data(contentsOf: fileURL),
      let draft = try? JSONDecoder().decode(BrewDraft.self, from: data)
    else {
      try? FileManager.default.removeItem(at: fileURL)
      return .discardedCorrupt
    }
    return .draft(draft)
  }

  public func clear() -> Result<Void, DraftError> {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return .success(()) }
    do {
      try FileManager.default.removeItem(at: fileURL)
      NotificationCenter.default.post(name: Self.didChange, object: nil)
      return .success(())
    } catch {
      return .failure(.removeFailed(error.localizedDescription))
    }
  }
}
