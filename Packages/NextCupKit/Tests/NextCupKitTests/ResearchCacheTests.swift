import Foundation
import Testing

@testable import NextCupKit

@Suite("ResearchCache")
struct ResearchCacheTests {
  private final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_000_000)
  }

  private func file() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("ResearchCacheTests-\(UUID().uuidString)/research.json")
  }

  private func research(_ notes: String) -> WebResearch {
    WebResearch(
      notes: notes,
      sources: [WebSource(title: "V60", url: URL(string: "https://beanbench.coffee/v60")!)])
  }

  @Test func anAnswerIsKeptForThirtyDays() {
    let clock = Clock()
    let cache = ResearchCache(file: file(), now: { clock.now })
    let key = ResearchCache.key("Brewer: V60", version: "v1")
    #expect(cache.research(for: key) == nil)
    cache.save(research("Use 1:16."), for: key)
    #expect(cache.research(for: key) == research("Use 1:16."))
    clock.now += ResearchCache.lifetime - 1
    #expect(cache.research(for: key) != nil)
    clock.now += 2
    #expect(cache.research(for: key) == nil, "a month on, the web is asked again")
  }

  @Test func theKeyHidesTheQuestionAndFollowsThePrompt() {
    let key = ResearchCache.key("Brewer: V60\nWhat they want: my secret", version: "v1")
    #expect(key.count == 64 && !key.contains("secret"))
    #expect(key == ResearchCache.key("Brewer: V60\nWhat they want: my secret", version: "v1"))
    #expect(key != ResearchCache.key("Brewer: V60\nWhat they want: my secret", version: "v2"))
    #expect(key != ResearchCache.key("Brewer: Chemex", version: "v1"))
  }

  @Test func onlyTheNewestAnswersAreKept() {
    let clock = Clock()
    let cache = ResearchCache(file: file(), now: { clock.now })
    for index in 0...ResearchCache.limit {
      clock.now += 1
      cache.save(research("\(index)"), for: "key-\(index)")
    }
    #expect(cache.research(for: "key-0") == nil)
    #expect(cache.research(for: "key-1")?.notes == "1")
    #expect(cache.research(for: "key-\(ResearchCache.limit)") != nil)
  }

  @Test func aBrokenFileOnlyMeansSearchingAgain() throws {
    let url = file()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)
    let cache = ResearchCache(file: url)
    #expect(cache.research(for: "k") == nil)
    cache.save(research("Fresh."), for: "k")
    #expect(cache.research(for: "k")?.notes == "Fresh.")
  }
}
