import XCTest

/// Start brew and Log a brew: the grind and "How much coffee?" are − / + steppers, so a scroll past them
/// cannot change them; holding the number opens a dial. Screenshots are written while
/// `docs/design/matching-steppers/.capture` exists, named with CAPTURE_PREFIX (default new_)
/// and CAPTURE_SUFFIX (e.g. _dark).
final class StartBrewStepperUITests: XCTestCase {
  @MainActor
  func testTheGrindAndAmountStepAndHoldingOpensTheDial() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/matching-steppers")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let env = ProcessInfo.processInfo.environment
    let prefix = env["CAPTURE_PREFIX"] ?? "new_"
    let suffix = env["CAPTURE_SUFFIX"] ?? ""
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
        to: folder.appendingPathComponent("\(prefix)\(name)\(suffix).png"))
    }
    func scrollTo(_ target: XCUIElement) {
      for _ in 0..<8 where !(target.exists && target.isHittable) { app.swipeUp() }
    }

    // A saved brew with a Comandante makes it the Start brew grinder.
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element("destination.brew.new").waitForExistence(timeout: 5))
    let details = element("brewform.details")
    scrollTo(details)
    details.tap()
    let grinder = app.buttons["Grinder"].firstMatch
    scrollTo(grinder)
    grinder.tap()
    app.buttons["Popular grinders"].tap()
    app.buttons["Comandante C40 MK4"].tap()
    // Log a brew has the same stepper and dial.
    let formGrind = element("brewform.grind")
    for _ in 0..<8 where !(formGrind.exists && formGrind.isHittable) { app.swipeDown() }
    app.step("brewform.grind", to: 20)
    XCTAssertTrue(app.staticTexts["Hold for dial"].exists)
    try shot("log-brew")
    formGrind.press(forDuration: 0.8)
    XCTAssertTrue(element("dial.popup").waitForExistence(timeout: 2))
    try shot("log-brew-hold")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75)).tap()
    XCTAssertFalse(element("dial.popup").waitForExistence(timeout: 1))
    let increaseDose = app.buttons["Increase Dose"]
    for _ in 0..<8 where !(increaseDose.exists && increaseDose.isHittable) { app.swipeDown() }
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 5))
    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    element("style.1").tap()
    let grind = element("recipe.grindSetting")
    XCTAssertTrue(grind.waitForExistence(timeout: 5))
    scrollTo(grind)
    if app.pickerWheels.firstMatch.exists {  // the old wheels: capture only
      app.swipeUp()
      try shot("start-brew")
      return
    }

    // − / + move the grind one stop from the guide's starting point.
    XCTAssertEqual(grind.value as? String, "20 clicks")
    app.buttons["recipe.grindSetting.increase"].tap()
    XCTAssertEqual(grind.value as? String, "21 clicks")
    app.buttons["recipe.grindSetting.decrease"].tap()
    XCTAssertEqual(grind.value as? String, "20 clicks")

    // An amount in oz sets the dose.
    let dose = element("stepper.dose.value")
    let recipeDose = dose.value as? String ?? ""
    app.buttons["oz"].tap()
    let amount = element("recipe.yield")
    let before = amount.value as? String
    app.buttons["recipe.yield.increase"].tap()
    XCTAssertNotEqual(amount.value as? String, before)
    XCTAssertTrue(element("recipe.yield.tuning").waitForExistence(timeout: 5))
    XCTAssertNotEqual(dose.value as? String, recipeDose, "the amount did not change the dose")

    // Grind, amount and dose are the same row: same label, − and + at the same place.
    XCTAssertEqual(app.staticTexts.matching(identifier: "Hold for dial").count, 3)
    let minus = ["recipe.grindSetting", "recipe.yield", "stepper.dose.value"]
      .map { app.buttons["\($0).decrease"].frame.minX }
    XCTAssertEqual(Set(minus).count, 1, "the − buttons do not line up: \(minus)")
    try shot("start-brew")

    // The dose dial works like the others, and Reset puts the recipe's dose back.
    dose.press(forDuration: 0.8)
    XCTAssertTrue(element("dial.popup").waitForExistence(timeout: 2))
    try shot("start-brew-dose-hold")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.15)).tap()
    XCTAssertFalse(element("dial.popup").waitForExistence(timeout: 1))
    element("recipe.dose.reset").tap()
    XCTAssertEqual(dose.value as? String, recipeDose)

    // Holding the number opens the dial; a tap outside closes it.
    grind.press(forDuration: 0.8)
    XCTAssertTrue(element("dial.popup").waitForExistence(timeout: 2))
    try shot("start-brew-hold")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.65)).tap()
    XCTAssertFalse(element("dial.popup").waitForExistence(timeout: 1))

    // Holding and sliding up turns the dial; letting go keeps the stop and closes it.
    let start = grind.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    start.press(
      forDuration: 0.8, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -80)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    XCTAssertEqual(grind.value as? String, "22 clicks")
    XCTAssertFalse(element("dial.popup").exists)

    // A scroll that starts on the number moves the page, not the grind.
    let grindBefore = grind.value as? String
    grind.swipeUp()
    XCTAssertEqual(grind.value as? String, grindBefore)
  }
}
