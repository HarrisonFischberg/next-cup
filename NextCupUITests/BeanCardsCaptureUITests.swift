import XCTest

/// The Beans list in each offered look. Runs only while `docs/design/bean-cards/.capture`
/// exists; files are named with CAPTURE_PREFIX (old_ or new_) and CAPTURE_VARIANT (light or
/// dark, set on the simulator with `simctl ui appearance` before the run).
final class BeanCardsCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBeanCards() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/bean-cards")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let environment = ProcessInfo.processInfo.environment
    let prefix = environment["CAPTURE_PREFIX"] ?? "new_"
    let variant = environment["CAPTURE_VARIANT"] ?? "light"
    let styles = [
      "sundayStudio", "morningEdition", "steelBlue", "daily", "cafePage", "roasterPoster",
    ]
    for style in styles {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBeans", "-appStyle", style,
      ]
      app.launch()
      app.tabBars.buttons["Beans"].tap()
      XCTAssertTrue(app.descendants(matching: .any)["beans.list"].waitForExistence(timeout: 10))
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)beans-\(style)-\(variant).png"))
      app.terminate()
    }
  }
}
