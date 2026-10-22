import Foundation
import SwiftData
import Testing

@testable import NextCup

@Suite struct NextCupTests {
  @Test @MainActor func shellBuilds() {
    _ = RootTabView().body
  }

  @Test @MainActor func bootstrapOpensAndSeedsTheStore() throws {
    let suite = "NextCupTests.bootstrap"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let container = try AppBootstrap.start(inMemory: true, defaults: defaults).get()
    let methods = try container.mainContext.fetch(FetchDescriptor<BrewMethod>())
    let recipes = try container.mainContext.fetch(FetchDescriptor<Recipe>())
    #expect(!methods.isEmpty)
    #expect(!recipes.isEmpty)
  }
}
