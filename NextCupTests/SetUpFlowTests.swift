import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Set-up and start brew")
struct SetUpFlowTests {
  @Test func appleAIFillsOnlyBlankBeanFields() throws {
    let bean = Bean(name: "Hair Bender")
    bean.process = "washed"
    BeanDetailsAI.apply(
      [
        "originCountry": "Blend", "process": "natural", "roastLevel": "medium",
        "flavorNotes": "citrus, dark chocolate",
      ], to: bean)
    #expect(bean.originCountry == "Blend")
    #expect(bean.process == "washed", "a typed value is kept")
    #expect(bean.roastLevel == .medium)
    #expect(bean.bagFlavorNotes == ["citrus", "dark chocolate"])
  }

  @Test func theStartBrewBeanAndGrindReachTheBrewForm() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let store = Store(context: container.mainContext)
    let bean = Bean(name: "Monarch")
    container.mainContext.insert(bean)
    let seed = BrewFormSeed(
      sessionKey: UUID().uuidString, recipeID: UUID(), recipeName: "Balanced cone",
      methodName: nil, doseG: 15, waterG: 250, tempC: 94, totalTimeS: 180, targetTimeS: 180,
      endedEarly: false, beanID: bean.id, beanName: bean.name, grindSetting: "22")
    let model = BrewFormModel(
      seed: seed, store: store,
      draftStore: DraftStore(
        fileURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("nextcup-setup-\(UUID().uuidString)/brew-draft.json")),
      defaults: UserDefaults(suiteName: "nextcup.setup.\(UUID().uuidString)")!)
    #expect(model.draft.beans?.first?.beanID == bean.id)
    #expect(model.draft.grindSetting == "22")
  }
}
