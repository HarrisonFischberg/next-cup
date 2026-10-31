import XCTest

/// Settings > Appearance with every look and Settings > AI, then the Journal and Brew tabs in every look.
/// Runs only while `docs/design/looks/.capture` exists.
final class LooksCaptureUITests: XCTestCase {
  static let styles = [
    "sundayStudio", "morningEdition", "steelBlue", "daily", "cafePage", "roasterPoster",
  ]

  @MainActor
  func testCaptureEveryLook() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/looks")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    XCUIDevice.shared.appearance = .light
    for (index, style) in Self.styles.enumerated() {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBrews",
        "-demoOnlyMethod", "switchable-dripper", "-appStyle", style,
      ]
      app.launch()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
      func shot(_ name: String) throws {
        sleep(1)
        try app.screenshot().pngRepresentation.write(
          to: folder.appendingPathComponent("new_\(name).png"))
      }
      sleep(2)  // the launch animation settles
      let number = String(format: "%02d", index + 1)
      try shot("\(number)-\(style)-journal")
      app.tabBars.buttons["Brew"].tap()
      try shot("\(number)-\(style)-brew")
      if index == 0 {
        app.tabBars.buttons["Journal"].tap()
        app.descendants(matching: .any)["journal.settings"].firstMatch.tap()
        let looks = app.descendants(matching: .any)["settings.flavor.sundayStudio"].firstMatch
        for _ in 0..<8 where !(looks.exists && looks.isHittable) { app.swipeUp() }
        try shot("all-looks")
        app.swipeUp()
        try shot("all-looks-scrolled")
        let ai = app.descendants(matching: .any)["settings.ai"].firstMatch
        for _ in 0..<8 where !(ai.exists && ai.isHittable) { app.swipeUp() }
        ai.tap()
        try shot("ai-settings")
      }
      app.terminate()
    }
  }
}
