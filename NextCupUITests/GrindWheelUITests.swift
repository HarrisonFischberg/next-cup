import XCTest

/// The grind setting is a wheel in the grinder's own notation, on the brew form and on
/// Brew setup. Screenshots are written while `docs/design/grind-wheel/.capture` exists,
/// named with TEST_RUNNER_CAPTURE_PREFIX (default new_).
final class GrindWheelUITests: XCTestCase {
  @MainActor
  func testTheGrindIsAWheelOnTheBrewFormAndBrewSetup() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/grind-wheel")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    func wheel(_ id: String) -> XCUIElement {
      let wheel = app.pickerWheels[id]
      return wheel.exists ? wheel : app.pickers[id].pickerWheels.firstMatch
    }
    func shot(_ name: String) throws {
      guard capture else { return }
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)\(name).png"))
    }
    func scrollTo(_ target: XCUIElement) {
      for _ in 0..<8 where !(target.exists && target.isHittable) { app.swipeUp() }
    }

    // Brew form: choose a Comandante, then turn its wheel to 24 clicks.
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element("destination.brew.new").waitForExistence(timeout: 5))
    let details = element("brewform.details")
    scrollTo(details)
    details.tap()
    let grinder = app.buttons["Grinder"].firstMatch  // a Menu exposes its label, not its id
    scrollTo(grinder)
    grinder.tap()
    app.buttons["Popular grinders"].tap()
    app.buttons["Comandante C40 MK4"].tap()
    let grind = element("brewform.grind")
    for _ in 0..<8 where !(grind.exists && grind.isHittable) { app.swipeDown() }
    if app.textFields["brewform.grind"].exists {
      grind.tap()
      grind.typeText("24\n")
    } else {
      wheel("brewform.grind").adjust(toPickerWheelValue: "24")
      XCTAssertEqual(wheel("brewform.grind").value as? String, "24")
    }
    try shot("brew-form-grind")

    // Brew setup: saving makes the Comandante the setup's grinder; its wheel rests on
    // the guide's starting point.
    for _ in 0..<8 where !app.buttons["Increase Dose"].isHittable { app.swipeDown() }
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 5))
    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    element("style.1").tap()
    let setup = element("recipe.grindSetting")
    XCTAssertTrue(setup.waitForExistence(timeout: 5))
    scrollTo(setup)
    if !app.textFields["recipe.grindSetting"].exists {
      XCTAssertEqual(wheel("recipe.grindSetting").value as? String, "20")
    }
    try shot("brew-setup-grind")
  }
}
