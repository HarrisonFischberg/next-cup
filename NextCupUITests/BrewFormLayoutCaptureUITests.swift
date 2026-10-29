import XCTest

/// The blank brew form from top to bottom. Runs only while
/// `docs/design/brew-form-layout/.capture` exists; files are named with CAPTURE_PREFIX
/// (old_ or new_).
final class BrewFormLayoutCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBrewFormLayout() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-form-layout")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-deepLink", "nextcup://brew/new",
    ]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any)["destination.brew.new"].waitForExistence(timeout: 10))
    sleep(1)
    for page in 1...3 {
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)brew-form-\(page).png"))
      app.swipeUp(velocity: .slow)
      sleep(1)
    }
  }
}
