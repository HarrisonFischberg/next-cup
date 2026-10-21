import Testing

@testable import NextCup

@Suite struct NextCupTests {
  @Test @MainActor func launchViewBuilds() {
    _ = LaunchView().body
  }
}
