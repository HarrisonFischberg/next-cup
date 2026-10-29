import Foundation
import Testing

@testable import NextCupKit

@Suite("Barcode lookup")
struct BarcodeLookupTests {
  private func json(_ s: String) -> Data { Data(s.utf8) }

  @Test func onlyEightToFourteenDigitsMakeARequest() {
    #expect(BarcodeLookup.normalized(" 0123456789012 ") == "0123456789012")
    for bad in ["1234567", "123456789012345", "12345678a", "../../x", "１２３４５６７８", ""] {
      #expect(BarcodeLookup.request(for: bad) == nil, "\(bad)")
    }
  }

  @Test func requestNamesTheAppAndAsksForTwoFields() throws {
    let request = try #require(BarcodeLookup.request(for: "3017620422003"))
    #expect(
      request.url?.absoluteString
        == "https://world.openfoodfacts.org/api/v2/product/3017620422003.json?fields=product_name,brands"
    )
    #expect(
      request.value(forHTTPHeaderField: "User-Agent")?.contains("hello@rarecreatures.app") == true)
  }

  @Test func parsesNameAndFirstBrand() {
    let body = json(
      #"{"status":1,"product":{"product_name":" Major Dickason's Blend ","brands":"Peet's Coffee, JDE"}}"#
    )
    #expect(
      BarcodeLookup.parse(body, statusCode: 200)
        == .success(.init(name: "Major Dickason's Blend", brand: "Peet's Coffee")))
  }

  @Test func brandAloneLeavesTheNameBlank() {
    let body = json(#"{"status":1,"product":{"product_name":"","brands":"Lavazza"}}"#)
    #expect(
      BarcodeLookup.parse(body, statusCode: 200)
        == .success(.init(name: "", brand: "Lavazza")))
  }

  @Test func notFoundPaths() {
    #expect(BarcodeLookup.parse(json(#"{"status":0}"#), statusCode: 200) == .failure(.notFound))
    #expect(BarcodeLookup.parse(json("{}"), statusCode: 404) == .failure(.notFound))
    #expect(
      BarcodeLookup.parse(json(#"{"status":1,"product":{}}"#), statusCode: 200)
        == .failure(.notFound))
    #expect(BarcodeLookup.parse(json("<html>"), statusCode: 200) == .failure(.unreadable))
    #expect(BarcodeLookup.parse(json("{}"), statusCode: 503) == .failure(.unreadable))
  }

  @Test func transportErrorIsOfflineAndBadCodeSendsNothing() async {
    struct Down: Error {}
    let offline = await BarcodeLookup.lookUp("12345678") { _ in throw Down() }
    #expect(offline == .failure(.offline))
    let invalid = await BarcodeLookup.lookUp("abc") { _ in
      Issue.record("no request for an invalid code")
      return (Data(), 200)
    }
    #expect(invalid == .failure(.invalidCode))
  }
}
