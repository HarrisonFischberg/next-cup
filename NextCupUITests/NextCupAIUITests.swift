import XCTest

/// Ask AI for Next Cup, from the Past Brews long press and the saved brew, ends in a Next Cup
/// recipe on the Brew tab. `-fakeNextCupAI` stands in for the AI; parsing and saving are real.
/// Screenshots are written while `docs/design/ask-ai/.capture` exists, with CAPTURE_PREFIX
/// (default new_) from TEST_RUNNER_CAPTURE_PREFIX.
@MainActor
final class NextCupAIUITests: XCTestCase {
  private var app: XCUIApplication!

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func shoot(_ name: String) {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../docs/design/ask-ai").standardized
    guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path)
    else { return }
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    try? app.screenshot().pngRepresentation.write(
      to: folder.appendingPathComponent("\(prefix)ask-ai-\(name).png"))
  }

  private func launch() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-demoBrews", "-fakeNextCupAI",
    ]
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
  }

  private var firstRow: XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'")).firstMatch
  }

  private var nextCupHeader: XCUIElement { app.staticTexts["RECIPE TO TRY FOR YOUR NEXT CUP"] }

  /// The sheet works, reports, and Save Next Cup lands on the Brew tab with the card on screen,
  /// which opens the recipe with its changes.
  private func finishAndSave() {
    XCTAssertTrue(element("nextcup.done").waitForExistence(timeout: 15))
    XCTAssertTrue(app.staticTexts["Grind 18 to 16"].exists)
    XCTAssertTrue(element("nextcup.basis").label.contains("similar past brew"))
    shoot("result")
    element("nextcup.save").tap()
    XCTAssertTrue(nextCupHeader.waitForExistence(timeout: 5))
    XCTAssertTrue(nextCupHeader.isHittable, "scrolled to the card")
    shoot("brew-tab")
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Next Cup'")).firstMatch.tap()
    let note = element("recipe.nextCupNote")
    XCTAssertTrue(note.waitForExistence(timeout: 5))
    XCTAssertTrue(note.label.contains("AI changes:"), note.label)
    XCTAssertTrue(note.label.contains("Grind 18 to 16"), note.label)
    XCTAssertEqual(element("recipe.grindSetting").exists, true)
    shoot("recipe")
  }

  func testLongPressAsksAIAndTheNextCupIsPinnedOnTheBrewTab() throws {
    launch()
    // Leave the Brew tab scrolled down: saving must still land on the card.
    app.tabBars.buttons["Brew"].tap()
    app.swipeUp()
    app.tabBars.buttons["Journal"].tap()
    XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
    firstRow.press(forDuration: 1.2)
    let ask = app.buttons["Ask AI for Next Cup"].firstMatch
    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    shoot("long-press")
    ask.tap()
    finishAndSave()
  }

  func testSavedBrewAsksAIWithoutTappingEditDiscardKeepsNothingAndSavingAgainReplaces() throws {
    launch()
    XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
    firstRow.tap()
    let ask = element("brewform.askNextCup")
    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    XCTAssertEqual(ask.label, "Ask AI for Next Cup")
    XCTAssertFalse(app.staticTexts["Get one AI tip"].exists)
    XCTAssertTrue(element("brewform.unlock").exists, "still locked")
    shoot("saved-brew")
    ask.tap()
    XCTAssertTrue(element("nextcup.done").waitForExistence(timeout: 15))
    XCTAssertFalse(element("nextcup.replaces").exists, "nothing to replace yet")
    XCTAssertEqual(element("nextcup.close").label, "Discard")
    element("nextcup.close").tap()
    app.tabBars.buttons["Brew"].tap()
    XCTAssertTrue(element("recipes.add").waitForExistence(timeout: 5))
    XCTAssertFalse(nextCupHeader.exists, "discarded, so no card")
    app.tabBars.buttons["Journal"].tap()

    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    ask.tap()
    finishAndSave()
    app.tabBars.buttons["Journal"].tap()

    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    ask.tap()
    XCTAssertTrue(element("nextcup.replaces").waitForExistence(timeout: 15), "second save replaces")
  }
}
