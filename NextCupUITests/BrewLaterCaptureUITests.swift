import XCTest

/// The Brew finished screen, then the Journal after Rate after this cup. Runs only while
/// `docs/design/brew-later/.capture` exists; files are named with CAPTURE_PREFIX
/// (old_ or new_) and CAPTURE_VARIANT (light or dark, set on the simulator first).
final class BrewLaterCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBrewFinished() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-later")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let env = ProcessInfo.processInfo.environment
    let prefix = env["CAPTURE_PREFIX"] ?? "new_"
    let variant = env["CAPTURE_VARIANT"] ?? "light"
    func shot(_ name: String) throws {
      sleep(1)
      try XCUIApplication().screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)brew-\(name)-\(variant).png"))
    }
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-timerSpeed", "60",
    ]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    app.buttons["Start brew"].tap()
    app.buttons["Start"].tap()
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 30))
    finish.tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["timer.finished"].waitForExistence(timeout: 5))
    try shot("finished")
    let later = app.buttons["Rate after this cup"]
    guard later.exists else { return }
    later.tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["journal.savedLater"].waitForExistence(timeout: 5))
    try shot("later-journal")
  }
}
