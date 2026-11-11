import XCTest

/// Brew steps design options on Start brew (`-stepsLook 0...3`). Screenshots are written while
/// `docs/design/brew-steps/.capture` exists; look 0 (the current strip) is saved as old_.
final class BrewStepsCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBrewStepsLooks() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-steps")
    guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path)
    else { throw XCTSkip("capture only") }
    let suffix = ProcessInfo.processInfo.environment["CAPTURE_SUFFIX"] ?? ""
    for look in 0...3 {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
        "-stepsLook", "\(look)",
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
      let name = look == 0 ? "old_brew-steps" : "new_brew-steps-option-\(look)"
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(name)\(suffix).png"))
      app.terminate()
    }
  }
}
