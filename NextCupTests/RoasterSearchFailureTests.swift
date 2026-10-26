import Foundation
import MapKit
import Testing

@testable import NextCup

@MainActor
@Suite("Roaster search failures")
struct RoasterSearchFailureTests {
  private struct Failing: RoasterSearching {
    let error: Error
    func search(_ area: SearchArea) async throws -> [RoasterPlace] { throw error }
  }

  @Test func onlyANetworkFailureIsCalledAConnectionProblem() {
    #expect(RoasterSearchFailure.isOffline(URLError(.notConnectedToInternet)))
    #expect(!RoasterSearchFailure.isOffline(MKError(.serverFailure)))
    #expect(
      RoasterSearchFailure.message(for: URLError(.notConnectedToInternet)).contains("offline"))
    #expect(!RoasterSearchFailure.message(for: MKError(.serverFailure)).contains("connection"))
    #expect(RoasterSearchFailure.message(for: MKError(.loadingThrottled)).contains("busy"))
    #expect(!RoasterSearchFailure.message(for: MKError(.unknown)).contains("connection"))
  }

  @Test func theMatchSheetSaysWhatWentWrong() async {
    let online = RoasterMatchModel(name: "Onyx", searcher: Failing(error: MKError(.serverFailure)))
    await online.search()
    #expect(!online.isOffline)
    guard case .failed(let message) = online.phase else {
      Issue.record("expected a failure")
      return
    }
    #expect(message.contains("skip"))

    let offline = RoasterMatchModel(
      name: "Onyx", searcher: Failing(error: URLError(.notConnectedToInternet)))
    await offline.search()
    #expect(offline.isOffline)
  }
}
