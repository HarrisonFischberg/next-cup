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

/// Autosaves the open brew form as one JSON file in Application Support
/// (blueprint §3a). Writes are atomic and return a result, so the form can show
/// a failure and keep the draft in memory.
public struct DraftStore: Sendable {
  public typealias Writer = @Sendable (Data, URL) throws -> Void

  public let fileURL: URL
  private let write: Writer

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

  public static let atomicWrite: Writer = { data, url in
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  public func save(_ draft: BrewDraft) -> Result<Void, DraftError> {
    do {
      try write(try JSONEncoder().encode(draft), fileURL)
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
      return .success(())
    } catch {
      return .failure(.removeFailed(error.localizedDescription))
    }
  }
}
