import Testing

@testable import NextCupKit

@Suite struct NextCupKitTests {
  @Test func versionIsSemantic() {
    let parts = NextCupKit.version.split(separator: ".")
    #expect(parts.count == 3)
    #expect(parts.allSatisfy { Int($0) != nil })
  }
}
