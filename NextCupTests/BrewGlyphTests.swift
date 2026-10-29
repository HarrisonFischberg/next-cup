import SwiftUI
import Testing

@testable import NextCup

struct BrewGlyphTests {
  @Test func everyBuiltInMethodHasItsOwnDrawing() throws {
    let url = try #require(Bundle.main.url(forResource: "methods", withExtension: "json"))
    struct File: Decodable {
      struct Method: Decodable { let key: String }
      let methods: [Method]
    }
    let keys = try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).methods.map(\.key)
      .filter { $0 != NespressoJokeView.methodKey }  // the joke method keeps the mug on purpose
    let glyphs = keys.map(BrewGlyph.init(methodKey:))
    #expect(!glyphs.contains(.cup))
    #expect(Set(glyphs).count == keys.count)
  }

  @Test func methodsTheOwnerAddsGetTheMug() {
    #expect(BrewGlyph(methodKey: nil) == .cup)
    #expect(BrewGlyph(methodKey: "my-siphon") == .cup)
    #expect(BrewGlyph(methodKey: "moka-pot") == .moka)
  }

  @Test func pathReaderFollowsTheMockupData() {
    let cone = Art.svg("M23 32 H77 L56 63 H44 Z").boundingRect
    #expect(cone == CGRect(x: 23, y: 32, width: 54, height: 31))
    let kettle = Art.svg("M-16 14 H16 Q20 14 19 10").boundingRect
    #expect(kettle.minX == -16 && kettle.maxX <= 20)
  }
}
