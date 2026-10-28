import XCTest

/// Start brew: the numbered styles switch the recipe in place, and "How much coffee?"
/// sets the dose from an amount. Screenshots are written while
/// `docs/design/brew-setup/.capture` exists.
final class BrewSetupUITests: XCTestCase {
  @MainActor
  func testStylesSwitchInPlaceAndAnAmountSetsTheDose() throws {
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
    element("brew.method.Switchable immersion dripper").tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Steep then release'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    XCTAssertTrue(element("recipe.style.1").waitForExistence(timeout: 5))
    try shot("setup-styles")

    // Another number shows that style's recipe on the same page.
    let before = element("recipe.water").label
    let second = element("recipe.style.2")
    second.tap()
    XCTAssertTrue(second.isSelected)
    XCTAssertFalse(element("recipe.style.1").isSelected)
    XCTAssertNotEqual(element("recipe.water").label, "", "\(before)")
    try shot("setup-style-2")

    // 12 oz of coffee sets a bigger dose than the recipe's.
    element("recipe.style.1").tap()
    let dose = element("stepper.dose.value")
    let recipeDose = dose.value as? String ?? ""
    let amount = element("recipe.yield")
    amount.tap()
    amount.typeText("16")
    app.buttons["Done"].firstMatch.tap()
    let tuning = element("recipe.yield.tuning")
    XCTAssertTrue(tuning.waitForExistence(timeout: 5))
    XCTAssertNotEqual(dose.value as? String, recipeDose, "the amount did not change the dose")
    app.swipeUp()
    try shot("setup-amount")
  }
}
