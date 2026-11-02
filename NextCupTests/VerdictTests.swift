import Testing

@testable import NextCup

@Suite("How it tasted")
struct VerdictTests {
  @Test func tastesAddUpBalancedIncluded() {
    var raw = Verdict.toggled(.sour, in: nil)
    raw = Verdict.toggled(.weak, in: raw)
    #expect(Verdict.picked(raw) == [.sour, .weak])
    raw = Verdict.toggled(.balanced, in: raw)
    #expect(Verdict.picked(raw) == [.sour, .weak, .balanced])
    raw = Verdict.toggled(.bitter, in: raw)
    #expect(Verdict.picked(raw) == [.sour, .weak, .balanced, .bitter])
    raw = Verdict.toggled(.balanced, in: raw)
    #expect(Verdict.picked(raw) == [.sour, .weak, .bitter])
    #expect(Verdict.toggled(.sour, in: "sour") == nil)
  }

  @Test func aSingleTasteSavedBeforeReadsTheSame() {
    #expect(Verdict.picked("strong") == [.strong])
    #expect(Verdict.joined([.strong]) == "strong")
    #expect(Verdict.picked(nil).isEmpty)
  }

  @Test func aBrewKeepsEveryTasteFirstOneFirst() {
    let brew = Brew()
    brew.verdict = .sour
    brew.alsoTasted = ["weak"]
    #expect(brew.verdicts == [.sour, .weak])
  }
}
