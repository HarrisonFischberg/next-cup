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

    // 16 oz of coffee sets a bigger dose than the recipe's.
    let recipeDose = dose.value as? String ?? ""
    app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "oz")
    app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "16")
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
}
