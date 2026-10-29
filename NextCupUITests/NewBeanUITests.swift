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

  /// Brew setup: "Add new beans" in the Beans picker opens the same bean screen as the Beans
  /// tab +; Save comes back with the new bean picked, Cancel keeps the earlier pick.
  /// Screenshots go to docs/design/add-bean/ (CAPTURE_PREFIX old_ or new_) while its
  /// `.capture` file exists.
  @MainActor
  func testAddNewBeansFromTheBrewSetupPicker() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/add-bean")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-demoBeans",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    func shot(_ name: String) throws {
      guard capture else { return }
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)\(name).png"))
    }

    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    let card = element("style.1")
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()
    let beans = element("recipe.beans")
    XCTAssertTrue(beans.waitForExistence(timeout: 5))
    let picked = beans.value as? String
    beans.tap()
    try shot("beans-picker")

    let add = app.buttons["Add new beans"].firstMatch
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.tap()
    XCTAssertTrue(element("beans.editor.cancel").waitForExistence(timeout: 5))
    try shot("add-bean-sheet")
    element("beans.editor.cancel").tap()
    XCTAssertTrue(beans.waitForExistence(timeout: 5))
    XCTAssertEqual(beans.value as? String, picked, "Cancel changed the beans")

    beans.tap()
    app.buttons["Add new beans"].firstMatch.tap()
    let name = element("beans.editor.name")
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Friend's Kenya")
    element("beans.editor.save").tap()
    XCTAssertTrue(beans.waitForExistence(timeout: 5))
    XCTAssertEqual(beans.value as? String, "Friend's Kenya")
    try shot("new-bean-picked")
  }
}
