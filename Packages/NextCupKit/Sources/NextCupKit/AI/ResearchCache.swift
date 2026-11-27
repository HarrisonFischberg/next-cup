import CryptoKit
import Foundation

/// What a web search found, kept on the device so the same question is not searched (and
/// billed to the user's key) again while the answer is fresh. One small JSON file; an entry
/// is dropped after `lifetime`, and the oldest go first past `limit`. Questions are stored
/// only as a hash. A file that cannot be read or written just means searching again.
public struct ResearchCache: Sendable {
  public static let lifetime: TimeInterval = 30 * 24 * 3_600
  public static let limit = 40

  struct Entry: Codable {
    var saved: Date
    var research: WebResearch
  }

  let file: URL
  let now: @Sendable () -> Date

  public init(file: URL, now: @escaping @Sendable () -> Date = { Date() }) {
    self.file = file
    self.now = now
  }

  /// `version` changes the key, so answers to an older research prompt are not reused.
  public static func key(_ question: String, version: String) -> String {
    SHA256.hash(data: Data((version + "\n" + question).utf8))
      .map { String(format: "%02x", $0) }.joined()
  }

  private func entries() -> [String: Entry] {
    guard let data = try? Data(contentsOf: file),
      let all = try? JSONDecoder().decode([String: Entry].self, from: data)
    else { return [:] }
    return all.filter { now().timeIntervalSince($0.value.saved) < Self.lifetime }
  }

  public func research(for key: String) -> WebResearch? { entries()[key]?.research }

  public func save(_ research: WebResearch, for key: String) {
    var all = entries()
    all[key] = Entry(saved: now(), research: research)
    for old in all.sorted(by: { $0.value.saved > $1.value.saved }).dropFirst(Self.limit) {
      all[old.key] = nil
    }
    guard let data = try? JSONEncoder().encode(all) else { return }
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file, options: [.atomic, .completeFileProtection])
  }
}
