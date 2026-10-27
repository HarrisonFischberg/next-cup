import XCTest

/// Logging a brew with a bean that isn't saved yet: "New bean…" in the bean menu opens the
/// full bean screen, and Save returns to the brew form with the new bean chosen.
final class NewBeanUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  @MainActor
  func testANewBeanCanBeTypedInFromTheBrewForm() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    app.buttons["Log a brew"].firstMatch.tap()
    let addBean = app.descendants(matching: .any)["brewform.beans.add"].firstMatch
    XCTAssertTrue(addBean.waitForExistence(timeout: 5))
    var tries = 0
    while !addBean.isHittable && tries < 6 {
      app.swipeUp()
      tries += 1
    }
    addBean.tap()
    app.buttons["New bean…"].firstMatch.tap()
    // The full bean screen opens over the brew form; Save brings the bean back chosen.
    let name = app.descendants(matching: .any)["beans.editor.name"].firstMatch
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Friend's Kenya")
    app.descendants(matching: .any)["beans.editor.save"].firstMatch.tap()
    let chosen = app.descendants(matching: .any)["brewform.beans"].firstMatch
    XCTAssertTrue(chosen.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Friend's Kenya"].firstMatch.exists)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    try app.screenshot().pngRepresentation.write(
      to: URL(fileURLWithPath: "/tmp/new/new_brewform_new_bean.png"))
  }
}
