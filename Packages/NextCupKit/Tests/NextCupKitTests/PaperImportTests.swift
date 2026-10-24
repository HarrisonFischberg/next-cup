import Foundation
import Testing

@testable import NextCupKit

@Suite("Paper import")
struct PaperImportTests {
  private func lines(_ texts: [String], confidence: Double = 0.95) -> [PaperLine] {
    texts.map { PaperLine(text: $0, confidence: confidence) }
  }

  @Test func labelledLinesFillTheDraft() {
    let draft = PaperImport.parse(
      lines([
        "Method: Hario V60", "Beans: Finca Alta", "Dose 18 g", "Water: 288g", "Temp 94 C",
        "Time: 2:45", "Grind - 24 clicks", "Rating 4.5/5", "Notes: panela, bright",
      ]))
    #expect(draft.method == "Hario V60")
    #expect(draft.bean == "Finca Alta")
    #expect(draft.doseG == 18)
    #expect(draft.waterG == 288)
    #expect(draft.tempC == 94)
    #expect(draft.totalTimeS == 165)
    #expect(draft.grind == "24 clicks")
    #expect(draft.ratingHalfSteps == 9)
    #expect(draft.notes == "panela, bright")
    #expect(draft.needsCheckCount == 0)
  }

  @Test func unitsAndSpellingsConvertToCanonical() {
    let draft = PaperImport.parse(
      lines(["Dose: 0.5 oz", "Water 10,5 oz", "Temperature 200 F", "Time 2 min 30", "Stars ★★★★"]))
    #expect(abs((draft.doseG ?? 0) - 14.17) < 0.01)
    #expect(abs((draft.waterG ?? 0) - 297.67) < 0.01)
    #expect(abs((draft.tempC ?? 0) - 93.33) < 0.01)
    #expect(draft.totalTimeS == 150)
    #expect(draft.ratingHalfSteps == 8)
  }

  @Test func timeAndRatingForms() {
    func seconds(_ text: String) -> Int? { PaperImport.parse(lines(["Time: \(text)"])).totalTimeS }
    #expect(seconds("150") == 150)
    #expect(seconds("150 s") == 150)
    #expect(seconds("2.5 min") == 150)
    #expect(seconds("0") == nil)
    #expect(seconds("9999") == nil)
    func grade(_ text: String) -> Int? {
      PaperImport.parse(lines(["Rating: \(text)"])).ratingHalfSteps
    }
    #expect(grade("8/10") == 8)
    #expect(grade("4") == 8)
    #expect(grade("9") == nil)
  }

  @Test func coffeeIsADoseWhenNumericAndABeanWhenNot() {
    let dose = PaperImport.parse(lines(["Coffee: 20 g"]))
    #expect(dose.doseG == 20)
    #expect(dose.bean.isEmpty)
    let bean = PaperImport.parse(lines(["Coffee: Ethiopia Guji"]))
    #expect(bean.bean == "Ethiopia Guji")
    #expect(bean.doseG == nil)
  }

  @Test func implausibleValuesAreNotMapped() {
    let draft = PaperImport.parse(
      lines(["Dose: 4000 g", "Temp: 300 C", "Water temp 94", "Time: soon"]))
    #expect(draft.doseG == nil)
    #expect(draft.tempC == nil)
    #expect(draft.waterG == nil)
    #expect(draft.totalTimeS == nil)
    // Nothing is thrown away: the lines that did not map are kept as notes.
    #expect(draft.notes.contains("Dose: 4000 g"))
    #expect(draft.notes.contains("Water temp 94"))
  }

  @Test func unlabelledLinesBecomeNotesAndLabelledNotesComeFirst() {
    let draft = PaperImport.parse(lines(["Notes: sweet", "second cup was flat", "Dose 15g"]))
    #expect(draft.notes == "sweet\nsecond cup was flat")
    #expect(draft.doseG == 15)
  }

  @Test func lowConfidenceFieldsAreFlagged() {
    let draft = PaperImport.parse([
      PaperLine(text: "Dose 18 g", confidence: 0.95),
      PaperLine(text: "Water 3OO g", confidence: 0.9),
      PaperLine(text: "Time: 2:45", confidence: 0.4),
      PaperLine(text: "Grind 24", confidence: 0.59),
    ])
    #expect(draft.needsCheck(.time))
    #expect(draft.needsCheck(.grind))
    #expect(!draft.needsCheck(.dose))
    // "3OO" is not a number: not mapped, kept in the notes at the line's confidence.
    #expect(draft.waterG == nil)
    #expect(draft.notes == "Water 3OO g")
    #expect(!draft.needsCheck(.notes))
    #expect(!draft.needsCheck(.method), "a field that was not read is blank, not flagged")
  }

  @Test func aNotesLineReadUnsurelyIsFlagged() {
    let draft = PaperImport.parse([PaperLine(text: "kinda fruity?", confidence: 0.3)])
    #expect(draft.needsCheck(.notes))
    #expect(draft.notes == "kinda fruity?")
  }

  @Test func blankPageIsEmpty() {
    #expect(PaperImport.parse([]).isEmpty)
    #expect(PaperImport.parse(lines(["  ", ""])).isEmpty)
  }

  // MARK: AI answers

  private let answer = """
    {"method":"V60","bean":"Finca Alta","doseGrams":18,"waterGrams":288,"temperatureCelsius":94,\
    "timeSeconds":165,"grind":"24","ratingOutOfFive":4.5,"notes":"panela","uncertain":"grind, time"}
    """

  @Test func aiAnswerMapsThroughTheSameRulesWithItsOwnDoubts() throws {
    let draft = try #require(PaperImport.draft(fromAI: Data(answer.utf8)))
    #expect(draft.method == "V60")
    #expect(draft.doseG == 18)
    #expect(draft.tempC == 94)
    #expect(draft.totalTimeS == 165)
    #expect(draft.ratingHalfSteps == 9)
    #expect(draft.needsCheck(.grind))
    #expect(draft.needsCheck(.time))
    #expect(!draft.needsCheck(.dose))
  }

  @Test func aiZerosAreBlankAndAbsurdValuesDropped() throws {
    let json = answer.replacingOccurrences(of: #""doseGrams":18"#, with: #""doseGrams":0"#)
      .replacingOccurrences(of: #""temperatureCelsius":94"#, with: #""temperatureCelsius":900"#)
    let draft = try #require(PaperImport.draft(fromAI: Data(json.utf8)))
    #expect(draft.doseG == nil)
    #expect(draft.tempC == nil)
    #expect(draft.waterG == 288)
  }

  @Test func aiAnswersOutsideTheSchemaAreDiscarded() {
    for bad in [
      #"{"method":"V60"}"#, "a page of coffee",
      answer.replacingOccurrences(of: "165", with: "\"soon\""),
    ] {
      #expect(PaperImport.draft(fromAI: Data(bad.utf8)) == nil)
    }
  }

  @Test func payloadCarriesThePhotoAndSchema() {
    let payload = PaperImport.payload(photo: Data([1, 2]))
    #expect(payload.imageJPEG == Data([1, 2]))
    #expect(payload.schema == PaperImport.schema)
  }
}
