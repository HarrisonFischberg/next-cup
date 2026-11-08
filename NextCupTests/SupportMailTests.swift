import Foundation
import Testing

@testable import NextCup

struct SupportMailTests {
  @Test func draftGoesToSupportWithTheNoteFirst() throws {
    let body = SupportMail.body(problem: "  Timer skips a pour & stalls ☕️  ")
    #expect(body.hasPrefix("Timer skips a pour & stalls ☕️\n\n--- Debug logs"))
    #expect(body.contains("Errors logged since the app opened:"))
    let url = try #require(SupportMail.url(body: body))
    let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(parts.scheme == "mailto")
    #expect(parts.path == SupportMail.address)
    #expect(parts.queryItems?.first { $0.name == "body" }?.value == body)
    let subject = parts.queryItems?.first { $0.name == "subject" }?.value
    #expect(subject?.hasSuffix("debug logs") == true)
  }
}
