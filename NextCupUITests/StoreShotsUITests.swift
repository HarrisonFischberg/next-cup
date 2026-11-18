import XCTest

// Throwaway: App Store screenshots, not committed.
final class StoreShotsUITests: XCTestCase {
  private let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("build/store-shots")

  private func launch(_ appearance: XCUIDevice.Appearance, speed: Int = 1) -> XCUIApplication {
    XCUIDevice.shared.appearance = appearance
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-demoBrews", "-demoBeans",
      "-appStyle", "sundayStudio", "-timerSpeed", "\(speed)",
    ]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    sleep(2)
    return app
  }

  private func shot(_ name: String) throws {
    sleep(1)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let shot = XCUIScreen.main.screenshot()
    let w = Int(shot.image.size.width * shot.image.scale)
    try shot.pngRepresentation.write(to: out.appendingPathComponent("\(name)-\(w).png"))
  }

  private func openCone(_ app: XCUIApplication) {
    app.tabBars.buttons["Brew"].tap()
    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    app.buttons["Start brew"].tap()
    XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
  }

  @MainActor func test1Methods() throws {
    let app = launch(.light)
    app.tabBars.buttons["Brew"].tap()
    try shot("1-methods")
  }

  @MainActor func test2Timer() throws {
    let app = launch(.dark, speed: 3)
    openCone(app)
    app.buttons["Start"].tap()
    Thread.sleep(forTimeInterval: 5.0 / 3)
    try shot("2-timer")
  }

  @MainActor func test3Taste() throws {
    let app = launch(.light, speed: 60)
    openCone(app)
    app.buttons["Start"].tap()
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 30))
    finish.tap()
    app.buttons["Rate while sippin’"].tap()
    let balanced = app.descendants(matching: .any)["brewform.verdict.balanced"].firstMatch
    XCTAssertTrue(balanced.waitForExistence(timeout: 5))
    for _ in 0..<8 where !balanced.isHittable { app.swipeUp(velocity: .slow) }
    balanced.tap()
    let rating = app.descendants(matching: .any)["Rating"].firstMatch
    for _ in 0..<5 where !rating.isHittable { app.swipeUp(velocity: .slow) }
    let start = rating.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.62))
    start.press(
      forDuration: 0.2,
      thenDragTo: rating.coordinate(withNormalizedOffset: CGVector(dx: 0.76, dy: 0.62)))
    try shot("3-taste")
  }

  @MainActor func test4Journal() throws {
    _ = launch(.dark)
    try shot("4-journal")
  }

  @MainActor func test5Beans() throws {
    let app = launch(.light)
    app.tabBars.buttons["Beans"].tap()
    try shot("5-beans")
  }

  @MainActor func test6Finished() throws {
    let app = launch(.dark, speed: 60)
    openCone(app)
    app.buttons["Start"].tap()
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 30))
    finish.tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["timer.finished"].waitForExistence(timeout: 5))
    try shot("6-finished")
  }

  override func tearDown() { XCUIDevice.shared.appearance = .light }
}
