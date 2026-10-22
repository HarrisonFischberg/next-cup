import Foundation
import Testing

@testable import NextCupKit

@Suite("Brew again")
struct BrewAgainTests {
  private let methodID = UUID()
  private let recipeID = UUID()
  private let beanID = UUID()
  private let sourceID = UUID()

  private func saved() -> BrewDraft {
    BrewDraft(
      id: sourceID, date: Date(timeIntervalSince1970: 1_000), methodID: methodID,
      recipeID: recipeID, doseG: 18, waterG: 288, tempC: 93, totalTimeS: 172,
      grindSetting: "21 clicks", verdict: "sour", ratingHalfSteps: 6, notes: "Thin and sharp.",
      photo: Data([1, 2, 3]),
      targets: BrewTargets(doseG: 15, waterG: 250, tempC: 94, totalTimeS: 180),
      endedEarly: true)
  }

  @Test func keepsWhatMakesItTheSameBrew() {
    let beans = [DraftBean(beanID: beanID, name: "Synthetic Blend", grams: 18)]
    let repeated = BrewDraft.repeating(saved(), sourceID: sourceID, beans: beans)
    #expect(repeated.methodID == methodID)
    #expect(repeated.recipeID == recipeID)
    #expect(repeated.doseG == 18)
    #expect(repeated.waterG == 288)
    #expect(repeated.tempC == 93)
    #expect(repeated.grindSetting == "21 clicks")
    #expect(repeated.beans == beans)
    #expect(repeated.targets == saved().targets)
  }

  @Test func resetsTimingAndTheCupThatWasDrunk() {
    let now = Date(timeIntervalSince1970: 9_999)
    let repeated = BrewDraft.repeating(saved(), sourceID: sourceID, beans: [], now: now)
    #expect(repeated.totalTimeS == nil)
    #expect(repeated.endedEarly == false)
    #expect(repeated.date == now)
    #expect(repeated.verdict == nil)
    #expect(repeated.ratingHalfSteps == 0)
    #expect(repeated.notes.isEmpty)
    #expect(repeated.photo == nil)
  }

  @Test func isANewBrewThatRemembersWhereItCameFrom() {
    let repeated = BrewDraft.repeating(saved(), sourceID: sourceID, beans: [])
    #expect(repeated.id != sourceID)
    #expect(repeated.sourceKey == BrewDraft.repeatKey(for: sourceID))
    #expect(repeated.canSave)
  }

  @Test func repeatDraftSurvivesRelaunchAndOldDraftsStillLoad() throws {
    let repeated = BrewDraft.repeating(
      saved(), sourceID: sourceID,
      beans: [DraftBean(beanID: nil, name: "Gone Bean", grams: 18)])
    let data = try JSONEncoder().encode(repeated)
    #expect(try JSONDecoder().decode(BrewDraft.self, from: data) == repeated)

    // A draft written before beans existed has no "beans" key.
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "beans")
    let old = try JSONSerialization.data(withJSONObject: object)
    #expect(try JSONDecoder().decode(BrewDraft.self, from: old).beans == nil)
  }

  @Test func repeatsKeepTheirOwnDraftFile() {
    let one = DraftStore.repeating(sourceID).fileURL
    let two = DraftStore.repeating(UUID()).fileURL
    #expect(one != two)
    #expect(one != DraftStore.standard().fileURL)
  }
}
