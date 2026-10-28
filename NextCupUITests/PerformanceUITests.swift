import XCTest

/// Before/after numbers for docs/perf: launch, journal search and scroll, and the
/// Explore tab, with 1,000 brews in the in-memory store. App CPU time is the number
/// to compare; wall time includes XCUITest's own overhead. Runs only while
/// `docs/perf/.measure` exists.
final class PerformanceUITests: XCTestCase {
  private static let brews = "1000"

  override func setUpWithError() throws {
    let flag = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/perf/.measure")
    try XCTSkipUnless(FileManager.default.fileExists(atPath: flag.path), "measuring is off")
  }

  private func makeApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-perfBrews", Self.brews,
      "-appStyle", "sundayStudio",
    ]
    return app
  }

  private func launched() -> XCUIApplication {
    let app = makeApp()
    app.launch()
    XCTAssertTrue(app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 30))
    return app
  }

  private var options: XCTMeasureOptions {
    let options = XCTMeasureOptions()
    options.iterationCount = 5
    return options
  }

  @MainActor
  func testLaunchWithAThousandBrews() {
    let app = makeApp()
    measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
      app.launch()
    }
  }

  @MainActor
  func testJournalSearch() {
    let app = launched()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    measure(metrics: [XCTCPUMetric(application: app), XCTClockMetric()], options: options) {
      field.tap()
      field.typeText("juicy")
      XCTAssertTrue(
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'juicy'"))
          .firstMatch.waitForExistence(timeout: 10))
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
    }
  }

  @MainActor
  func testJournalScroll() {
    let app = launched()
    measure(metrics: [XCTCPUMetric(application: app), XCTClockMetric()], options: options) {
      for _ in 0..<4 { app.swipeUp(velocity: .fast) }
      for _ in 0..<4 { app.swipeDown(velocity: .fast) }
    }
  }

  @MainActor
  func testSwitchToExploreAndBack() {
    let app = launched()
    measure(metrics: [XCTCPUMetric(application: app), XCTClockMetric()], options: options) {
      app.tabBars.buttons["Explore"].tap()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.explore"].waitForExistence(timeout: 10))
      app.tabBars.buttons["Journal"].tap()
      XCTAssertTrue(
        app.descendants(matching: .any)["tab.root.journal"].waitForExistence(timeout: 10))
    }
  }
}
