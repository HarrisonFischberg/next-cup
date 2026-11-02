import XCTest

/// Start brew: each style on a brewer is its own numbered card that opens its setup,
/// where "How much coffee?" sets the dose, and the timer names the song playing.
/// Screenshots are written while `docs/design/brew-setup/.capture` exists.
final class BrewSetupUITests: XCTestCase {
  @MainActor
  func testANumberedStyleCardOpensItsSetupAndAnAmountSetsTheDose() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-setup")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    func shot(_ name: String) throws {
      guard capture else { return }
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("new_\(name).png"))
    }

    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    let second = element("style.2")
    XCTAssertTrue(second.waitForExistence(timeout: 5))
    XCTAssertTrue(element("style.1").exists)
    try shot("style-cards")

    // The whole second card opens that style's setup.
    second.tap()
    let dose = element("stepper.dose.value")
    XCTAssertTrue(dose.waitForExistence(timeout: 5))
    try shot("style-2-setup")

    // An ounce more coffee than the recipe makes sets a bigger dose than the recipe's.
    let recipeDose = dose.value as? String ?? ""
    app.buttons["oz"].tap()
    app.buttons["recipe.yield.increase"].tap()
    let tuning = element("recipe.yield.tuning")
    XCTAssertTrue(tuning.waitForExistence(timeout: 5))
    XCTAssertNotEqual(dose.value as? String, recipeDose, "the amount did not change the dose")
    app.swipeUp()
    try shot("setup-amount")
  }

  /// While music plays the timer names the song, and next, previous and pause work.
  @MainActor
  func testTheTimerNamesTheSongWithPreviousPauseAndNext() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-setup")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-brewMusic",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    let card = element("style.1")
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()
    let brew = app.buttons["Start brew"]
    XCTAssertTrue(brew.waitForExistence(timeout: 5))
    brew.tap()
    let start = app.buttons["Start"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()

    let title = element("timer.music.title")
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    let first = title.label
    if capture {
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("new_timer-now-playing.png"))
    }
    element("timer.music.next").tap()
    XCTAssertNotEqual(title.label, first, "next plays another song")
    element("timer.music.previous").tap()
    XCTAssertEqual(title.label, first, "previous goes back")
    let pause = element("timer.music.pause")
    XCTAssertEqual(pause.label, "Pause music")
    pause.tap()
    XCTAssertEqual(pause.label, "Play music")
  }

  /// How it tasted takes several faults and Balanced clears them. A screenshot shows the
  /// rating hint staying once a rating is set.
  @MainActor
  func testHowItTastedTakesSeveralPicksAndTheRatingHintStays() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-form")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    app.tabBars.buttons["Journal"].tap()
    let log = app.buttons["Log a brew"].firstMatch
    XCTAssertTrue(log.waitForExistence(timeout: 10))
    log.tap()
    let sour = element("brewform.verdict.sour")
    XCTAssertTrue(sour.waitForExistence(timeout: 5))
    var swipes = 0
    while !sour.isHittable && swipes < 12 {
      app.swipeUp()
      swipes += 1
    }
    sour.tap()
    element("brewform.verdict.weak").tap()
    XCTAssertTrue(sour.isSelected)
    XCTAssertTrue(element("brewform.verdict.weak").isSelected)

    // The hint is hidden from VoiceOver (the rating reads its own value), so the
    // screenshot shows it staying.
    let rating = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == 'Rating'")
    ).firstMatch
    // Drag the slider's thumb from 0 to the right; the thumb sits just past the minus.
    let origin = rating.coordinate(withNormalizedOffset: .zero)
    let slider = rating.frame
    origin.withOffset(CGVector(dx: 66, dy: slider.height - 40))
      .press(
        forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 220, dy: slider.height - 40)))
    XCTAssertNotEqual(rating.value as? String, "Not rated")
    if capture {
      app.swipeUp()
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("new_tasted-and-rating.png"))
    }

    element("brewform.verdict.balanced").tap()
    XCTAssertTrue(element("brewform.verdict.balanced").isSelected)
    XCTAssertTrue(sour.isSelected, "Balanced goes with the other tastes")
  }

  /// The Journal lists older brews under their own Past Brews header.
  @MainActor
  func testTheJournalShowsPastBrewsUnderTheirOwnHeader() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-form")
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-demoBrews", "-resetNavigationState", "-resetDraft", "-appStyle",
      "sundayStudio",
    ]
    app.launch()
    app.tabBars.buttons["Journal"].tap()
    let past = app.descendants(matching: .any)["journal.past"].firstMatch
    XCTAssertTrue(past.waitForExistence(timeout: 10))
    if FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path) {
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("new_journal-past-brews.png"))
    }
  }
}
