import XCTest

/// The Brew steps card on Start brew. A screenshot is written while
/// `docs/design/brew-steps/.capture` exists, named with CAPTURE_PREFIX (default new_).
final class BrewStepsCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBrewStepsCard() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-steps")
    guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path)
    else { throw XCTSkip("capture only") }
    let env = ProcessInfo.processInfo.environment
    let prefix = env["CAPTURE_PREFIX"] ?? "new_"
    let suffix = env["CAPTURE_SUFFIX"] ?? ""
    do {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      ]
      app.launch()
      XCTAssertTrue(app.tabBars.buttons["Brew"].waitForExistence(timeout: 10))
      app.tabBars.buttons["Brew"].tap()
      let method = app.descendants(matching: .any)["brew.method.Switchable immersion dripper"]
        .firstMatch
      XCTAssertTrue(method.waitForExistence(timeout: 10))
      method.tap()
      app.descendants(matching: .any)["style.1"].firstMatch.tap()
      let edit = app.descendants(matching: .any)["recipe.steps.change"].firstMatch
      XCTAssertTrue(edit.waitForExistence(timeout: 5))
      for _ in 0..<10 where !(edit.isHittable && edit.frame.minY < app.frame.height * 0.45) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
          .press(
            forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)),
            withVelocity: .slow, thenHoldForDuration: 0.2)
      }
      sleep(1)
      let name = "\(prefix)brew-steps"
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(name)\(suffix).png"))
      app.terminate()
    }
  }
}
