import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Bag names and key-first model")
struct BagNamesAndKeyTests {
  private func draft(_ answer: [String: Any]) throws -> BeanFields {
    var full: [String: Any] = [
      "name": "", "roaster": "", "originCountry": "", "region": "", "farm": "", "process": "",
      "varietal": "", "roastLevel": "", "roastDate": "", "bagWeightGrams": 0, "flavorNotes": "",
      "isDecaf": false,
    ]
    full.merge(answer) { $1 }
    let container = try NextCupContainer.make(inMemory: true)
    let request = AIRequest()
    request.feature = .bagRecognition
    request.status = .done
    request.resultJSON = try JSONSerialization.data(withJSONObject: full)
    container.mainContext.insert(request)
    return try BagRecognition.draft(from: request).get()
  }

  /// What Apple's model wrote for real bags: a description, a certification, the brand twice.
  @Test func descriptionsCertificationsAndTheBrandAreNotNames() throws {
    var fields = try draft(["name": "A Medium Roast Coffee", "roaster": "COFFEE®"])
    #expect(fields.name.isEmpty && fields.roasterName.isEmpty)
    fields = try draft(["name": "CUBANO ROAST", "roaster": "USDA"])
    #expect(fields.name == "CUBANO ROAST" && fields.roasterName.isEmpty)
    fields = try draft(["name": "BLUE BOTTLE COFFEE", "roaster": "BLUE BOTTLE"])
    #expect(fields.name.isEmpty && fields.roasterName == "BLUE BOTTLE")
    fields = try draft(["name": "Colombia Organic", "roaster": "Java Planet"])
    #expect(fields.name == "Colombia Organic" && fields.roasterName == "Java Planet")
  }

  @Test func ocrLinesCarryTheirSize() {
    let lines = BagRecognition.sized([
      PaperLine(text: "PURITY", confidence: 1, height: 0.08),
      PaperLine(text: "FLOW", confidence: 1, height: 0.04),
      PaperLine(text: "A Medium Roast Coffee", confidence: 1, height: 0.015),
    ])
    #expect(lines == ["[large] PURITY", "[medium] FLOW", "[small] A Medium Roast Coffee"])
    #expect(BagRecognition.sized([PaperLine(text: "x", confidence: 1)]) == ["x"])
  }

  /// The model copied the roaster into the name: the label's biggest other text stands in.
  @Test func aCopiedNameIsTakenFromTheLabel() {
    func line(_ text: String, _ height: Double) -> PaperLine {
      PaperLine(text: text, confidence: 1, height: height)
    }
    var answer: [String: Any] = ["name": "COFFEE", "roaster": "PURITY"]
    BagRecognition.fixName(
      &answer,
      from: [
        line("PURITY", 0.1), line("COFFEE®", 0.086), line("FLOW", 0.066),
        line("A Medium Roast Coffee", 0.036), line("NET WT. 12 OZ (340 G)", 0.036),
      ])
    #expect(answer["name"] as? String == "FLOW")
    answer = ["name": "Peets", "roaster": "Peets"]
    BagRecognition.fixName(
      &answer,
      from: [
        line("Peets", 0.2), line("ESTABLISHED", 0.044), line("WHOLE BEAN COFFEE", 0.02),
        line("MAJOR DICKASON'S™", 0.044), line("DARK ROAST", 0.022),
      ])
    #expect(answer["name"] as? String == "MAJOR DICKASON'S")
    answer = ["name": "MAYORGA", "roaster": "MAYORGA"]
    BagRecognition.fixName(
      &answer,
      from: [
        line("USDA", 0.01), line("CUBANO", 0.045), line("ROAST", 0.04), line("DARK ROAST", 0.02),
        line("MAYORGA", 0.5),
      ])
    #expect(answer["name"] as? String == "CUBANO ROAST")
    answer = ["name": "COMFORT COFFEE", "roaster": ""]
    BagRecognition.fixName(
      &answer,
      from: [line("COMFORT", 0.1), line("COFFEE", 0.093), line("Peru", 0.037)])
    #expect(answer["roaster"] as? String == "COMFORT COFFEE" && answer["name"] as? String == "Peru")
    answer = ["name": "BULLET PROOF", "roaster": "Expertly Blended in Seattle, WA"]
    BagRecognition.fixName(
      &answer, from: [line("BULLET", 0.09), line("PROOF®", 0.1), line("mentalist", 0.057)])
    #expect(
      answer["roaster"] as? String == "BULLET PROOF" && answer["name"] as? String == "mentalist")
    answer = ["name": "BULLET PROOF", "roaster": "Seattle"]
    BagRecognition.fixName(
      &answer,
      from: [
        line("EXPERTLY BLENDED IN SEATTLE, WA", 0.064), line("BULLET", 0.09),
        line("PROOF®", 0.1), line("mentalist", 0.057),
      ])
    #expect(answer["roaster"] as? String == "BULLET PROOF", "a city in a slogan is not the roaster")
    answer = ["name": "GRAN RISERVA", "roaster": "LAVAZZA"]
    BagRecognition.fixName(&answer, from: [line("LAVAZZA", 0.1), line("FILTRO", 0.04)])
    #expect(answer["name"] as? String == "GRAN RISERVA", "a real name is kept")
  }

  @Test func aNewKeyStartsOnASensibleListedModel() {
    #expect(
      AIPreferences.defaultModel(
        from: ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"], for: .anthropic)
        == "claude-sonnet-5-5")
    #expect(AIPreferences.defaultModel(from: ["claude-x"], for: .anthropic) == "claude-x")
    #expect(
      AIPreferences.defaultModel(
        from: ["gpt-5-mini", "gpt-4.1", "gpt-5.2", "gpt-5-audio", "o3", "gpt-5.10"], for: .openAI)
        == "gpt-5.10")
    #expect(AIPreferences.defaultModel(from: [], for: .anthropic) == nil)
  }
}
