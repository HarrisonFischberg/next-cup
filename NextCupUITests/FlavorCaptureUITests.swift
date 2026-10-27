import XCTest

/// Screenshot sheet for T038: journal, brew form, timer and beans in each flavor, light and
/// dark, plus largest text for three flavors. Runs only while `docs/design/flavors/.capture`
/// exists, so the normal suite skips it.
final class FlavorCaptureUITests: XCTestCase {
  private static let largest = "UICTContentSizeCategoryAccessibilityXXXL"

  override func setUp() {
    continueAfterFailure = false
  }

  private var folder: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/flavors")
  }

  @MainActor
  private func capture(_ style: String, largestText: Bool = false, extra: [String] = [])
    throws
  {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    let variants: [(String, XCUIDevice.Appearance)] =
      largestText ? [("largest-text", .light)] : [("light", .light), ("dark", .dark)]
    for (variant, appearance) in variants {
      XCUIDevice.shared.appearance = appearance
      func launch(_ more: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // more first, so a timer's own -timerSpeed wins
        app.launchArguments = more + ["-inMemoryStore", "-demoBrews", "-resetNavigationState"]
        app.launchArguments += ["-resetDraft"]
        app.launchArguments += extra
        app.launchArguments += ["-appStyle", style, "-timerSpeed", "1"]
        if largestText {
          app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.largest]
        }
        app.launch()
        return app
      }
      func shot(_ app: XCUIApplication, _ screen: String) throws {
        let png = app.screenshot().pngRepresentation
        try png.write(to: folder.appendingPathComponent("\(style)-\(screen)-\(variant).png"))
      }

      var app = launch(["-showOnboarding"])
      XCTAssertTrue(app.descendants(matching: .any)["onboarding"].waitForExistence(timeout: 10))
      try shot(app, "onboarding")
      app.terminate()

      app = launch()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
      try shot(app, "journal")

      app.buttons["Log a brew"].firstMatch.tap()
      _ = app.buttons["Increase Dose"].waitForExistence(timeout: 5)
      app.buttons["Increase Dose"].tap()
      try shot(app, "brewform")
      app.navigationBars.buttons.element(boundBy: 0).tap()
      app.tabBars.buttons["Brew"].tap()
      XCTAssertTrue(
        app.descendants(matching: .any)["brew.method.Cone dripper"].waitForExistence(timeout: 5))
      try shot(app, "brew")
      app.terminate()

      // Brew types open their styles; each timer is shot partway through its key step.
      let timers: [(String, String, String, Int, UInt32)] = [
        ("timer", "Cone dripper", "Balanced cone", 1, 5),
        ("timer-press", "Press pot", "Classic press", 10, 25),
        ("timer-espresso", "Espresso", "Espresso starting point", 1, 10),
      ]
      for (screen, method, recipe, speed, wait) in timers {
        app = launch(["-timerSpeed", "\(speed)"])
        XCTAssertTrue(app.tabBars.buttons["Brew"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Brew"].tap()
        app.descendants(matching: .any)["brew.method.\(method)"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", recipe))
          .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["Start brew"].tap()
        XCTAssertTrue(
          app.descendants(matching: .any)["timer.screen"].waitForExistence(timeout: 5))
        app.buttons["Start"].tap()
        sleep(wait)
        try shot(app, screen)
        app.terminate()
      }
    }
  }

  @MainActor func testDaily() throws {
    try capture("daily")
  }
  @MainActor func testSteelKraft() throws { try capture("steelKraft") }
  @MainActor func testNightMint() throws { try capture("nightMint") }
  @MainActor func testEspressoBlack() throws { try capture("espressoBlack") }
  @MainActor func testCafePage() throws { try capture("cafePage") }

  @MainActor func testLargestTextSteelKraft() throws {
    try capture("steelKraft", largestText: true)
  }
  @MainActor func testLargestTextCafePage() throws { try capture("cafePage", largestText: true) }
  @MainActor func testLargestTextNightMint() throws {
    try capture("nightMint", largestText: true)
  }
}
