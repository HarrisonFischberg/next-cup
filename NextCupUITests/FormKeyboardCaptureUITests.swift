import XCTest

/// The New brew form while typing Notes, then after Done. Runs only while
/// `docs/design/form-keyboard/.capture` exists; files are named with CAPTURE_PREFIX
/// (old_ or new_).
final class FormKeyboardCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureNotesKeyboard() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/form-keyboard")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    func shot(_ name: String) throws {
      sleep(1)
      try XCUIApplication().screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)brew-form-\(name).png"))
    }
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-deepLink", "nextcup://brew/new",
    ]
    app.launch()
    let notes = app.descendants(matching: .any)["brewform.notes"].firstMatch
    XCTAssertTrue(notes.waitForExistence(timeout: 10))
    var swipes = 0
    while !notes.isHittable && swipes < 12 {
      app.swipeUp()
      swipes += 1
    }
    notes.tap()
    notes.typeText("Lovely and sweet")
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    try shot("typing-notes")
    app.toolbars.buttons["Done"].firstMatch.tap()
    try shot("after-done")
  }
}
