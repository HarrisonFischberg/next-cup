import XCTest

/// Journal › Unsaved Brews after Rate after this cup, then the opened draft. Runs only
/// while `docs/design/unsaved-amount/.capture` exists; files are named with CAPTURE_PREFIX.
final class UnsavedAmountCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureUnsavedBrew() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/unsaved-amount")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    func shot(_ name: String) throws {
      sleep(1)
      try XCUIApplication().screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)unsaved-\(name).png"))
    }
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-timerSpeed", "60",
      "-demoBrews", "-appStyle", "sundayStudio",
    ]
    XCUIDevice.shared.appearance = .dark
    defer { XCUIDevice.shared.appearance = .light }
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
    let later = app.buttons["Rate after this cup"]
    XCTAssertTrue(later.waitForExistence(timeout: 5))
    later.tap()
    let unsaved = app.descendants(matching: .any)["journal.unsaved.row"].firstMatch
    XCTAssertTrue(unsaved.waitForExistence(timeout: 5))
    if !unsaved.isHittable { app.swipeUp() }
    try shot("row")
    unsaved.tap()
    try shot("form")
  }
}
