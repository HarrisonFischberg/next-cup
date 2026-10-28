import XCTest

/// Screenshots of the active brew in Sunday Studio dark with music on: ready, pouring,
/// hands off, get ready and finished. Runs only while `docs/design/brew-timer/.capture`
/// exists; files are named with the CAPTURE_PREFIX environment variable (old_ or new_).
final class BrewTimerCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureActiveBrew() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-timer")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    XCUIDevice.shared.appearance = .dark
    defer { XCUIDevice.shared.appearance = .light }
    let app = XCUIApplication()
    // Three times faster: the bloom pour, hands off and the get-ready moment arrive in
    // a few seconds each.
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-brewMusic", "-timerSpeed", "3",
    ]
    app.launch()
    func shot(_ name: String) throws {
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)timer-\(name).png"))
    }
    XCTAssertTrue(
      app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    app.buttons["Start brew"].tap()
    XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
    try shot("ready")
    app.buttons["Start"].tap()
    let started = Date()
    func at(_ brewS: Double) { Thread.sleep(until: started.addingTimeInterval(brewS / 3)) }
    at(5)
    try shot("pouring")
    at(24)
    try shot("hands-off")
    at(41.5)
    try shot("get-ready")
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 70))
    finish.tap()
    sleep(1)
    try shot("finished")
  }
}
