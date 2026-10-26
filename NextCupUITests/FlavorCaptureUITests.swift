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
      let app = XCUIApplication()
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
      app.launchArguments += extra  // first, so its -timerSpeed wins
      app.launchArguments += ["-appStyle", style, "-timerSpeed", "1"]
      if largestText {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.largest]
      }
      app.launch()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
      func shot(_ screen: String) throws {
        let png = app.screenshot().pngRepresentation
        try png.write(to: folder.appendingPathComponent("\(style)-\(screen)-\(variant).png"))
      }
      try shot("journal")

      app.buttons["Log a brew"].firstMatch.tap()
      _ = app.buttons["Increase Dose"].waitForExistence(timeout: 5)
      app.buttons["Increase Dose"].tap()
      try shot("brewform")
      app.navigationBars.buttons.element(boundBy: 0).tap()

      app.tabBars.buttons["Recipes"].tap()
      let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
        .firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      row.tap()
      app.buttons["Start brew"].tap()
      XCTAssertTrue(app.descendants(matching: .any)["timer.screen"].waitForExistence(timeout: 5))
      app.buttons["Start"].tap()
      sleep(2)
      try shot("timer")

      app.terminate()
    }
  }

  @MainActor func testBloom() throws {
    try capture("bloom", extra: ["-demoBrews", "-timerSpeed", "40"])
  }
  @MainActor func testSteelKraft() throws { try capture("steelKraft") }
  @MainActor func testCharcoalCrema() throws { try capture("charcoalCrema") }
  @MainActor func testQuietCeramic() throws { try capture("quietCeramic") }
  @MainActor func testTerracotta() throws { try capture("terracotta") }
  @MainActor func testLateNightCafe() throws { try capture("lateNightCafe") }
  @MainActor func testNightMint() throws { try capture("nightMint") }
  @MainActor func testEspressoBlack() throws { try capture("espressoBlack") }
  @MainActor func testCafePage() throws { try capture("cafePage") }
  @MainActor func testRoasterPoster() throws { try capture("roasterPoster") }
  @MainActor func testMakeItYours() throws { try capture("makeItYours") }

  // The ten Liquid Glass looks, with demo brews so the ring journal has a last cup.
  @MainActor func testGlassCremaGlass() throws { try glass("cremaGlass") }
  @MainActor func testGlassPourOver() throws { try glass("pourOver") }
  @MainActor func testGlassMatchaGlass() throws { try glass("matchaGlass") }
  @MainActor func testGlassMidnightRoast() throws { try glass("midnightRoast") }
  @MainActor func testGlassNordicMorning() throws { try glass("nordicMorning") }
  @MainActor func testGlassClayGlass() throws { try glass("clayGlass") }
  @MainActor func testGlassAuroraRoast() throws { try glass("auroraRoast") }
  @MainActor func testGlassBentoBar() throws { try glass("bentoBar") }
  @MainActor func testGlassColdBrew() throws { try glass("coldBrew") }
  @MainActor func testGlassEditorialCafe() throws { try glass("editorialCafe") }
  @MainActor private func glass(_ style: String) throws {
    try capture(style, extra: ["-demoBrews", "-timerSpeed", "40"])
  }

  @MainActor func testLargestTextSteelKraft() throws {
    try capture("steelKraft", largestText: true)
  }
  @MainActor func testLargestTextCafePage() throws { try capture("cafePage", largestText: true) }
  @MainActor func testLargestTextRoasterPoster() throws {
    try capture("roasterPoster", largestText: true)
  }
}
