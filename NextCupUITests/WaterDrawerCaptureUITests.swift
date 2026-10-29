import XCTest

/// Closes and reopens the Water Profile drawer on Edit brew, slowly enough for a screen
/// recording to catch mid-animation frames. Runs only while
/// `docs/screenshots/water-profile-drawer/.capture` exists.
final class WaterDrawerCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureWaterDrawerToggle() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/screenshots/water-profile-drawer")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBrews", "-appStyle",
      "sundayStudio",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Kenya Rukira")).firstMatch
      .tap()
    XCTAssertTrue(element("brewform.edit").waitForExistence(timeout: 5))
    let ask = element("brewform.ai")
    for _ in 0..<12 where !ask.isHittable {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
    }
    // Leave the drawer and the button below it in view.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
      .press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
    sleep(2)
    let header = app.buttons["Water Profile"].firstMatch
    for _ in 0..<2 {
      header.tap()  // close
      sleep(2)
      header.tap()  // open
      sleep(2)
    }
  }
}
