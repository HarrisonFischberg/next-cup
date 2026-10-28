import XCTest

/// Screenshots of the gear on each tab, the journal cards and Explore with one brew
/// type shown. Runs only while `docs/design/journal-explore/.capture` exists.
final class JournalExploreCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureJournalAndExplore() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/journal-explore")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    for (variant, appearance) in [("light", XCUIDevice.Appearance.light), ("dark", .dark)] {
      XCUIDevice.shared.appearance = appearance
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBrews",
        "-demoOnlyMethod", "switchable-dripper", "-appStyle", "sundayStudio",
      ]
      app.launch()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
      func shot(_ name: String) throws {
        sleep(1)
        try app.screenshot().pngRepresentation.write(
          to: folder.appendingPathComponent("new_\(name)-\(variant).png"))
      }
      sleep(2)  // the launch animation settles
      try shot("journal")
      for tab in ["Brew", "Beans", "Explore"] {
        app.tabBars.buttons[tab].tap()
        try shot(tab.lowercased())
      }
      app.descendants(matching: .any)["explore.settings"].firstMatch.tap()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.settings"].waitForExistence(timeout: 5))
      try shot("settings-from-explore")
      app.terminate()
    }
  }
}
