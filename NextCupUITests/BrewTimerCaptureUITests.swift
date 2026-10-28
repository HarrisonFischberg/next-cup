import XCTest

/// Screenshots of the active brew in Sunday Studio dark with music on: a cone pour-over
/// (ready, pouring, hands off, get ready, finished) and a switchable steep (valve closed,
/// steeping, valve open, draining). Runs only while `docs/design/brew-timer/.capture`
/// exists; files are named with the CAPTURE_PREFIX environment variable (old_ or new_).
final class BrewTimerCaptureUITests: XCTestCase {
  private var folder: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-timer")
  }

  /// Opens `recipe` of `method` at three times speed and calls `shoot` with a function
  /// that waits for a brew time and a function that saves a named screenshot.
  @MainActor
  private func capture(
    method: String, recipe: String,
    shoot: (_ at: (Double) -> Void, _ shot: (String) throws -> Void, XCUIApplication) throws ->
      Void
  ) throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    XCUIDevice.shared.appearance = .dark
    defer { XCUIDevice.shared.appearance = .light }
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-brewMusic", "-timerSpeed", "3",
    ]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    app.descendants(matching: .any)["brew.method.\(method)"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", recipe))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    app.buttons["Start brew"].tap()
    XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
    var started = Date()
    try shoot(
      { brewS in
        if brewS == 0 {
          app.buttons["Start"].tap()
          started = Date()
        } else {
          Thread.sleep(until: started.addingTimeInterval(brewS / 3))
        }
      },
      { name in
        try app.screenshot().pngRepresentation.write(
          to: self.folder.appendingPathComponent("\(prefix)\(name).png"))
      }, app)
  }

  @MainActor
  func testCaptureActiveBrew() throws {
    try capture(method: "Cone dripper", recipe: "Balanced cone") { at, shot, app in
      try shot("timer-ready")
      at(0)
      at(5)
      try shot("timer-pouring")
      at(24)
      try shot("timer-hands-off")
      at(41.5)
      try shot("timer-get-ready")
      let finish = app.buttons["Finish brew"]
      XCTAssertTrue(finish.waitForExistence(timeout: 70))
      finish.tap()
      sleep(1)
      try shot("timer-finished")
    }
  }

  @MainActor
  func testCaptureSwitchableValve() throws {
    try capture(method: "Switchable immersion dripper", recipe: "Steep then release") {
      at, shot, _ in
      at(0)
      at(2)
      try shot("timer-switch-close-and-pour")
      at(60)
      try shot("timer-switch-steeping")
      at(121.5)
      try shot("timer-switch-open-valve")
      at(150)
      try shot("timer-switch-draining")
    }
  }
}
