import Foundation
import Testing

@testable import NextCup

@Suite("DeepLink")
struct DeepLinkTests {
  let id = UUID(uuidString: "6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B")!

  @Test func parsesEveryDocumentedLink() {
    #expect(DeepLink(url: URL(string: "nextcup://brew/new")!) == .newBrew)
    #expect(DeepLink(url: URL(string: "nextcup://brew/\(id.uuidString)")!) == .brew(id))
    #expect(DeepLink(url: URL(string: "nextcup://recipe/\(id.uuidString)")!) == .recipe(id))
    #expect(DeepLink(url: URL(string: "nextcup://bean/\(id.uuidString)")!) == .bean(id))
    #expect(DeepLink(url: URL(string: "nextcup://settings")!) == .settings)
  }

  @Test func eachLinkTargetsItsTab() {
    #expect(DeepLink.newBrew.tab == .journal)
    #expect(DeepLink.brew(id).tab == .journal)
    #expect(DeepLink.recipe(id).tab == .recipes)
    #expect(DeepLink.bean(id).tab == .beans)
    #expect(DeepLink.settings.tab == .journal)
  }

  @Test func urlRoundTrips() {
    for link in [DeepLink.newBrew, .brew(id), .recipe(id), .bean(id), .settings] {
      #expect(DeepLink(url: link.url) == link)
    }
  }

  @Test(
    arguments: [
      "https://brew/new", "nextcup://brew", "nextcup://brew/", "nextcup://brew/not-a-uuid",
      "nextcup://recipe/new", "nextcup://roaster/6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B",
      "nextcup://brew/new/extra", "nextcup:///brew/new",
    ])
  func rejectsMalformedLinks(_ text: String) {
    #expect(DeepLink(url: URL(string: text)!) == nil)
  }

  @Test func timerLinkCarriesTheRecipeAndDose() {
    let link = DeepLink.timer(recipeID: id, doseG: 15.5)
    #expect(link.tab == .recipes)
    #expect(DeepLink(url: link.url) == link)
    #expect(
      DeepLink(url: URL(string: "nextcup://timer/\(id.uuidString)?dose=20")!)
        == .timer(recipeID: id, doseG: 20))
  }

  @Test(
    arguments: [
      "nextcup://timer/6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B",
      "nextcup://timer/6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B?dose=0",
      "nextcup://timer/6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B?dose=-3",
      "nextcup://timer/6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B?dose=abc",
      "nextcup://timer/not-a-uuid?dose=15",
    ])
  func rejectsMalformedTimerLinks(_ text: String) {
    #expect(DeepLink(url: URL(string: text)!) == nil)
  }

  @Test func schemeAndKindIgnoreCase() {
    #expect(DeepLink(url: URL(string: "NEXTCUP://Brew/NEW")!) == .newBrew)
  }

  @Test func routerReplacesInsteadOfStacking() async {
    let router = await AppRouter()
    await router.open(.recipe(id))
    await router.open(.recipe(id))
    #expect(await router.recipesPath == [.recipe(id)])
    #expect(await router.journalPath.isEmpty)
  }

  @Test func everyTabHasATitleAndSymbol() {
    #expect(AppTab.allCases.map(\.title) == ["Journal", "Recipes", "Beans", "Explore"])
    #expect(AppTab.allCases.allSatisfy { !$0.symbol.isEmpty })
  }
}
