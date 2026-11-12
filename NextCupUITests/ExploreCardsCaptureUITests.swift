import XCTest

/// Explore's deck, a kept bean's drawer, Skip with its Undo, and the end of the page. Runs only while
/// `docs/design/explore-cards/.capture` exists; files are named with the
/// CAPTURE_PREFIX environment variable (old_ or new_).
final class ExploreCardsCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureExploreCards() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/explore-cards")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    // Light only: XCUIDevice appearance does not switch these simulators to dark.
    for variant in ["light"] {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBrews", "-demoBeans",
        "-demoOnlyMethod", "switchable-dripper", "-appStyle", "sundayStudio",
      ]
      app.launch()
      app.tabBars.buttons["Explore"].tap()
      XCTAssertTrue(app.descendants(matching: .any)["explore.list"].waitForExistence(timeout: 10))
      func shot(_ name: String) throws {
        sleep(1)
        try app.screenshot().pngRepresentation.write(
          to: folder.appendingPathComponent("\(prefix)explore-\(name)-\(variant).png"))
      }
      try shot("deck")
      app.buttons["explore.keep"].tap()
      try shot("kept-open")
      app.buttons["explore.skip"].tap()
      try shot("skipped-undo")
      app.buttons["explore.keep"].tap()
      app.swipeUp()
      try shot("drawers")
      for _ in 0..<6 { app.swipeUp() }
      try shot("bottom")
      app.terminate()
    }
  }
}
