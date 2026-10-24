import Foundation
import Testing

@testable import NextCupKit

@Suite("Taxonomy")
struct TaxonomyTests {
  static let json = Data(
    """
    {
      "version": 3,
      "dimensions": {
        "origin": {
          "buckets": [
            { "key": "east-africa", "name": "East Africa" },
            { "key": "central-america", "name": "Central America" }
          ],
          "map": { "Ethiopia": "east-africa", "costa rica": "central-america" }
        },
        "flavor": {
          "buckets": [
            { "key": "citrus", "name": "Citrus" },
            { "key": "berry", "name": "Berry" }
          ],
          "map": { "lemon": "citrus", "lime": "citrus", "blueberry": "berry" }
        }
      }
    }
    """.utf8)

  func taxonomy() throws -> Taxonomy { try Taxonomy(json: Self.json) }

  @Test func mapsBundledValuesDeterministically() throws {
    let taxonomy = try taxonomy()
    let first = taxonomy.map("Ethiopia", in: .origin)
    #expect(first == taxonomy.map("Ethiopia", in: .origin))
    #expect(first.bucket?.key == "east-africa")
    let eastAfrica = Taxonomy.Bucket(key: "east-africa", name: "East Africa")
    #expect(first == .bucket(eastAfrica, source: .bundle))
  }

  @Test func normalizesCaseAccentsAndSpacing() throws {
    let taxonomy = try taxonomy()
    for raw in ["  COSTA   RICA ", "costa-rica", "Costa Rica", "Costá Rica"] {
      #expect(taxonomy.map(raw, in: .origin).bucket?.key == "central-america")
    }
  }

  @Test func unknownValueIsUnmapped() throws {
    let taxonomy = try taxonomy()
    #expect(taxonomy.map("Atlantis", in: .origin) == .unmapped(raw: "atlantis"))
    #expect(taxonomy.map("   ", in: .origin) == .unmapped(raw: ""))
    // A value that exists in another dimension is not mapped here.
    #expect(taxonomy.map("lemon", in: .origin).bucket == nil)
  }

  @Test func userAliasMapsAnUnmappedValue() throws {
    let taxonomy = try taxonomy()
    let aliases = try #require(taxonomy.alias(mapping: "Atlantis", to: "berry", in: .flavor))
    #expect(taxonomy.map("atlantis", in: .flavor, aliases: aliases).bucket?.key == "berry")
    #expect(
      taxonomy.map("atlantis", in: .flavor, aliases: aliases)
        == .bucket(Taxonomy.Bucket(key: "berry", name: "Berry"), source: .userAlias))
  }

  @Test func userAliasOverridesTheBundle() throws {
    let taxonomy = try taxonomy()
    #expect(taxonomy.map("lime", in: .flavor).bucket?.key == "citrus")
    let aliases = try #require(taxonomy.alias(mapping: "Lime", to: "berry", in: .flavor))
    let mapped = taxonomy.map("lime", in: .flavor, aliases: aliases)
    #expect(mapped.bucket?.key == "berry")
    // Other bundled values are untouched.
    #expect(taxonomy.map("lemon", in: .flavor, aliases: aliases).bucket?.key == "citrus")
  }

  @Test func aliasForAnotherDimensionDoesNotApply() throws {
    let taxonomy = try taxonomy()
    let aliases = try #require(taxonomy.alias(mapping: "lime", to: "berry", in: .flavor))
    #expect(taxonomy.map("lime", in: .origin, aliases: aliases).bucket == nil)
  }

  @Test func remappingReplacesTheEarlierAlias() throws {
    let taxonomy = try taxonomy()
    let first = try #require(taxonomy.alias(mapping: "mystery", to: "berry", in: .flavor))
    let second = try #require(
      taxonomy.alias(mapping: "Mystery", to: "citrus", in: .flavor, replacing: first))
    #expect(second.count == 1)
    #expect(taxonomy.map("mystery", in: .flavor, aliases: second).bucket?.key == "citrus")
  }

  @Test func aliasToAMissingBucketOrEmptyValueIsRejected() throws {
    let taxonomy = try taxonomy()
    #expect(taxonomy.alias(mapping: "x", to: "nope", in: .flavor) == nil)
    #expect(taxonomy.alias(mapping: "  ", to: "berry", in: .flavor) == nil)
  }

  @Test func staleAliasWithMissingBucketFallsBackToTheBundle() throws {
    let taxonomy = try taxonomy()
    let stale = [Taxonomy.Alias(dimension: .flavor, rawValue: "lime", bucketKey: "removed")]
    #expect(taxonomy.map("lime", in: .flavor, aliases: stale).bucket?.key == "citrus")
  }

  @Test func bucketsForAListAreDistinctAndOrdered() throws {
    let taxonomy = try taxonomy()
    let buckets = taxonomy.buckets(
      for: ["blueberry", "lemon", "lime", "unknown"], in: .flavor)
    #expect(buckets.map(\.key) == ["berry", "citrus"])
  }

  @Test func unmappedListIsDistinctNormalizedAndOffersTheUserAlias() throws {
    let taxonomy = try taxonomy()
    let raws = ["Grape-Soda", "grape soda", "lime", "", "Dragon  Fruit"]
    #expect(
      taxonomy.unmapped(in: raws, dimension: .flavor) == ["grape soda", "dragon fruit"])
    let aliases = try #require(taxonomy.alias(mapping: "grape soda", to: "berry", in: .flavor))
    #expect(
      taxonomy.unmapped(in: raws, dimension: .flavor, aliases: aliases) == ["dragon fruit"])
  }

  @Test func rejectsABadBundle() {
    let badBucket = Data(
      """
      {"version":1,"dimensions":{"origin":{"buckets":[{"key":"a","name":"A"}],"map":{"x":"b"}}}}
      """.utf8)
    #expect(throws: Taxonomy.LoadError.unknownBucket(dimension: "origin", key: "b")) {
      try Taxonomy(json: badBucket)
    }
    let badDimension = Data(
      """
      {"version":1,"dimensions":{"mood":{"buckets":[],"map":{}}}}
      """.utf8)
    #expect(throws: Taxonomy.LoadError.unknownDimension("mood")) {
      try Taxonomy(json: badDimension)
    }
  }

  @Test func theShippedBundleLoadsAndEveryBucketIsReachable() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("NextCup/Resources/taxonomy.json")
    let taxonomy = try Taxonomy(json: Data(contentsOf: url))
    #expect(taxonomy.map("Ethiopia", in: .origin).bucket?.key == "east-africa")
    #expect(taxonomy.map("Medium Light", in: .roast).bucket?.key == "light")
    for dimension in Taxonomy.Dimension.allCases {
      #expect(!taxonomy.buckets(in: dimension).isEmpty)
    }
  }

  @Test func exposesVersionAndBuckets() throws {
    let taxonomy = try taxonomy()
    #expect(taxonomy.version == 3)
    #expect(taxonomy.buckets(in: .origin).map(\.key) == ["east-africa", "central-america"])
    #expect(taxonomy.buckets(in: .roast).isEmpty)
  }
}
