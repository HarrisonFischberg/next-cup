import Testing

@testable import NextCup

@Suite("How it tasted")
struct VerdictTests {
  @Test func faultsAddUpAndBalancedStandsAlone() {
    var raw = Verdict.toggled(.sour, in: nil)
    raw = Verdict.toggled(.weak, in: raw)
    #expect(Verdict.picked(raw) == [.sour, .weak])
    raw = Verdict.toggled(.balanced, in: raw)
    #expect(Verdict.picked(raw) == [.balanced])
    raw = Verdict.toggled(.bitter, in: raw)
    #expect(Verdict.picked(raw) == [.bitter])
    #expect(Verdict.toggled(.bitter, in: raw) == nil)
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
