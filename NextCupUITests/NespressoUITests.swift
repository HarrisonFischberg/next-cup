import XCTest

/// The Nespresso easter egg: its "Brew" style opens the joke, and Back takes it off the
/// Brew page's methods row while it stays in the Methods list. Screenshots are written
/// while `docs/design/nespresso/.capture` exists, prefixed by CAPTURE_PREFIX (new_).
final class NespressoUITests: XCTestCase {
  @MainActor
  func testNespressoJokeHidesItFromTheBrewPageButNotTheMethodsList() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/nespresso")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
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
        to: folder.appendingPathComponent("\(prefix)\(name).png"))
    }
    func scrollToEndOfMethods() {
      for _ in 0..<8 {
        app.scrollViews.containing(.any, identifier: "brew.method.Cone dripper").firstMatch
          .swipeLeft()
      }
    }

    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    XCTAssertTrue(element("brew.method.Cone dripper").waitForExistence(timeout: 5))
    scrollToEndOfMethods()
    try shot("brew-methods")

    let tile = element("brew.method.Nespresso")
    XCTAssertTrue(tile.isHittable)
    tile.tap()
    let style = element("style.1")
    XCTAssertTrue(style.waitForExistence(timeout: 5))
    try shot("nespresso-styles")
    style.tap()
    XCTAssertTrue(element("nespresso.joke").waitForExistence(timeout: 5))
    try shot("nespresso-joke")

    element("nespresso.back").tap()
    XCTAssertTrue(element("brew.method.Cone dripper").waitForExistence(timeout: 5))
    XCTAssertFalse(tile.exists, "Nespresso is still on the Brew page")
    scrollToEndOfMethods()
    try shot("brew-methods-after-joke")

    element("recipes.moreMethods").tap()
    XCTAssertTrue(app.buttons["Nespresso"].waitForExistence(timeout: 5))
    app.swipeUp()
    try shot("methods-list")
  }
}
