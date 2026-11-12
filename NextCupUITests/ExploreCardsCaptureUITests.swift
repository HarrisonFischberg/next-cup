import XCTest

/// Explore (roasters and the flavor explorer of your beans) and a brewed bean's page with its
/// brew help. Runs only while `docs/design/explore-cards/.capture` exists; files are named
/// with the CAPTURE_PREFIX environment variable (old_ or new_).
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
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-perfBrews", "24",
      "-appStyle", "sundayStudio",
    ]
    app.launch()
    func shot(_ name: String) throws {
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)explore-\(name).png"))
    }
    app.tabBars.buttons["Explore"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["explore.list"].waitForExistence(timeout: 10))
    try shot("top")
    app.descendants(matching: .any)["explore.flavors"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["flavor.list"].waitForExistence(timeout: 10))
    try shot("flavors")
    app.tabBars.buttons["Beans"].tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("Bean 0 Ethiopia\n")
    app.descendants(matching: .any)["beans.row.Bean 0 Ethiopia"].tap()
    let help = app.descendants(matching: .any)["bean.otherWays"]
    XCTAssertTrue(help.waitForExistence(timeout: 10))
    try shot("bean-page")
    app.swipeUp()
    try shot("bean-page-scrolled")
  }
}
