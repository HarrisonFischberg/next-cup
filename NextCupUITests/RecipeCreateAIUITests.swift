import XCTest

/// Create with AI asks for the grinder too: one already in the app, or Other… with its
/// name typed in, so the recipe can say where to start on it.
final class RecipeCreateAIUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  @MainActor
  func testCreateWithAIAsksForTheGrinder() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Brew"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    app.descendants(matching: .any)["recipes.add"].firstMatch.tap()
    app.buttons["Create with AI"].firstMatch.tap()
    let grinder = app.descendants(matching: .any)["recipe.create.grinder"].firstMatch
    XCTAssertTrue(grinder.waitForExistence(timeout: 5))
    grinder.tap()
    app.buttons["Other…"].firstMatch.tap()
    let name = app.descendants(matching: .any)["recipe.create.grinderName"].firstMatch
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Comandante C40 MK4")
    XCTAssertEqual(name.value as? String, "Comandante C40 MK4")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
  }
}
