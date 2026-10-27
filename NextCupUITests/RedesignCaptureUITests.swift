import XCTest

/// Screenshot sheet for the handoff redesign: Brew, recipe setup and the active brew at
/// 0:42, at the target, and finished, in one look, light and dark, plus largest text.
/// Runs only while `docs/design/handoff/.capture` exists, so the normal suite skips it.
/// The look comes from the CAPTURE_STYLE environment variable (default sundayStudio).
final class RedesignCaptureUITests: XCTestCase {
  private static let largest = "UICTContentSizeCategoryAccessibilityXXXL"

  override func setUp() {
    continueAfterFailure = false
  }

  private var folder: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/handoff")
  }

  private var style: String {
    ProcessInfo.processInfo.environment["CAPTURE_STYLE"] ?? "sundayStudio"
  }

  @MainActor
  private func capture(largestText: Bool = false) throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    let variants: [(String, XCUIDevice.Appearance)] =
      largestText ? [("largest-text", .light)] : [("light", .light), ("dark", .dark)]
    let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
    for (variant, appearance) in variants {
      XCUIDevice.shared.appearance = appearance
      let app = XCUIApplication()
      // Six times faster: 0:42 of brew time arrives seven seconds after Start.
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", style,
        "-timerSpeed", "6",
      ]
      if largestText {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.largest]
      }
      app.launch()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
      func shot(_ screen: String) throws {
        let png = app.screenshot().pngRepresentation
        try png.write(
          to: folder.appendingPathComponent("\(style)-\(screen)-\(variant)-\(device).png"))
      }
      try shot("journal")
      app.tabBars.buttons["Beans"].tap()
      sleep(1)
      try shot("beans")
      app.tabBars.buttons["Explore"].tap()
      sleep(1)
      try shot("explore")
      app.tabBars.buttons["Brew"].tap()
      sleep(1)
      try shot("brew")
      app.descendants(matching: .any)["brew.method.Switchable immersion dripper"].firstMatch.tap()
      let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Steep then release'"))
        .firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      row.tap()
      sleep(1)
      try shot("setup")
      app.swipeUp()
      try shot("setup-steps")
      app.buttons["Start brew"].tap()
      XCTAssertTrue(app.descendants(matching: .any)["timer.screen"].waitForExistence(timeout: 5))
      try shot("timer-ready")
      app.buttons["Start"].tap()
      sleep(7)
      try shot("timer-0-42")
      app.buttons["Pause"].tap()
      sleep(1)
      try shot("timer-paused")
      app.buttons["Resume"].tap()
      let finish = app.buttons["Finish brew"]
      XCTAssertTrue(finish.waitForExistence(timeout: 60))
      sleep(2)
      try shot("timer-target")
      finish.tap()
      sleep(1)
      try shot("timer-finished")
      app.terminate()
    }
  }

  @MainActor func testRedesign() throws { try capture() }
  @MainActor func testRedesignLargestText() throws { try capture(largestText: true) }
}
