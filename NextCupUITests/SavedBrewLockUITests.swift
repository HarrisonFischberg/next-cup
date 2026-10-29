import XCTest

/// A saved brew opens locked: no tap or swipe changes it until Edit. Cancel puts the
/// saved values back; Save keeps the change. Screenshots are written while
/// `docs/design/saved-brew-lock/.capture` exists, named with CAPTURE_PREFIX (default new_).
@MainActor
final class SavedBrewLockUITests: XCTestCase {
  private var app: XCUIApplication!

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func wheel(_ id: String) -> XCUIElement {
    let wheel = app.pickerWheels[id]
    return wheel.exists ? wheel : app.pickers[id].pickerWheels.firstMatch
  }

  private func dose() -> String {
    element("brewform.dose").staticTexts.allElementsBoundByIndex.dropFirst().map { $0.label }
      .joined(separator: " ")
  }

  /// Drags in the left gutter, so the drag never lands on the wheel.
  private func scrollTo(_ target: XCUIElement) {
    for _ in 0..<12 where !(target.exists && target.isHittable) {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
    }
  }

  private func launch() {
    app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
    ]
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
  }

  /// Logs a 15 g brew with grind 12 and opens it from the Journal.
  private func logAndOpenBrew() {
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element("destination.brew.new").waitForExistence(timeout: 5))
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    let grind = wheel("brewform.grind")
    scrollTo(grind)
    grind.adjust(toPickerWheelValue: "12")
    app.buttons["Save brew"].tap()
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    scrollTo(row)
    row.tap()
    XCTAssertTrue(element("brewform.edit").waitForExistence(timeout: 5))
  }

  @MainActor
  func testASavedBrewIsLockedUntilEdit() {
    launch()
    logAndOpenBrew()

    // Locked: the values show, but nothing takes a tap or a swipe, and there is no Save.
    XCTAssertTrue(element("brewform.locked").exists)
    XCTAssertTrue(app.navigationBars["Saved brew"].exists)
    XCTAssertTrue(dose().hasPrefix("15"), dose())
    XCTAssertFalse(app.buttons["Increase Dose"].isEnabled)
    XCTAssertFalse(app.buttons["Save brew"].exists)
    let grind = wheel("brewform.grind")
    scrollTo(grind)
    XCTAssertEqual(grind.value as? String, "12")
    grind.swipeUp()
    XCTAssertEqual(grind.value as? String, "12", "a swipe on a locked wheel changes nothing")

    // Edit unlocks; Cancel puts the saved values back and locks again.
    element("brewform.unlock").tap()
    XCTAssertTrue(app.navigationBars["Edit brew"].waitForExistence(timeout: 5))
    grind.adjust(toPickerWheelValue: "14")
    XCTAssertEqual(grind.value as? String, "14")
    element("brewform.cancel").tap()
    XCTAssertTrue(element("brewform.locked").waitForExistence(timeout: 5))
    XCTAssertEqual(grind.value as? String, "12", "Cancel discards the change")

    // Edit and Save keep the change; the brew reopens locked with it.
    element("brewform.unlock").tap()
    grind.adjust(toPickerWheelValue: "14")
    app.buttons["Save brew"].tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Grind 14'")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "the Journal shows the saved change")
    row.tap()
    XCTAssertTrue(element("brewform.locked").waitForExistence(timeout: 5))
    scrollTo(grind)
    XCTAssertEqual(grind.value as? String, "14")
  }

  /// Writes the saved brew screen, light and dark: as it opens, and after Edit.
  @MainActor
  func testCaptureSavedBrewScreenshots() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/saved-brew-lock")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    defer { XCUIDevice.shared.appearance = .light }
    for (name, appearance) in [("light", XCUIDevice.Appearance.light), ("dark", .dark)] {
      XCUIDevice.shared.appearance = appearance
      launch()
      logAndOpenBrew()
      sleep(1)
      // Before the lock there is no Edit button: the old screen is the only shot.
      let locked = element("brewform.unlock").exists
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent(
          "\(prefix)saved-brew\(locked ? "-locked" : "")-\(name).png"))
      if locked {
        element("brewform.unlock").tap()
        sleep(1)
        try app.screenshot().pngRepresentation.write(
          to: folder.appendingPathComponent("\(prefix)saved-brew-editing-\(name).png"))
      }
      app.terminate()
    }
  }
}
