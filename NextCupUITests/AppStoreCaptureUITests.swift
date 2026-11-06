import XCTest

/// Raw App Store screenshots in Sunday Studio, with demo data and the fake Next Cup AI.
/// Runs only while `docs/app-store/raw/.capture` exists; design/frame_store_shots.py frames
/// the raw shots into store/ios/screenshots.
@MainActor
final class AppStoreCaptureUITests: XCTestCase {
  private var app: XCUIApplication!

  private var folder: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/app-store/raw")
  }

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func shoot(_ name: String) throws {
    sleep(1)
    try app.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
  }

  private func launch(_ extra: [String] = [], dark: Bool = false) throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    continueAfterFailure = false
    XCUIDevice.shared.appearance = dark ? .dark : .light
    app = XCUIApplication()
    app.launchArguments =
      ["-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio"]
      + extra
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
  }

  override func tearDown() {
    XCUIDevice.shared.appearance = .light
    super.tearDown()
  }

  func testAskAIAndTheNextCupOnTheBrewTab() throws {
    try launch(["-demoBrews", "-demoBeans", "-fakeNextCupAI"])
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    try shoot("05-journal")
    row.tap()
    let ask = element("brewform.askNextCup")
    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    ask.tap()
    XCTAssertTrue(element("nextcup.done").waitForExistence(timeout: 15))
    try shoot("02-ask-ai")
    element("nextcup.save").tap()
    XCTAssertTrue(
      app.staticTexts["RECIPE TO TRY FOR YOUR NEXT CUP"].waitForExistence(timeout: 5))
    try shoot("01-next-cup")
  }

  func testStartBrewAndTimer() throws {
    try launch(["-demoBeans", "-brewMusic", "-timerSpeed", "3"], dark: true)
    app.tabBars.buttons["Brew"].tap()
    element("brew.method.Cone dripper").tap()
    let recipe = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(recipe.waitForExistence(timeout: 5))
    recipe.tap()
    XCTAssertTrue(app.buttons["Start brew"].waitForExistence(timeout: 5))
    try shoot("03-start-brew")
    app.buttons["Start brew"].tap()
    XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
    app.buttons["Start"].tap()
    Thread.sleep(forTimeInterval: 5.0 / 3)
    try shoot("04-timer")
  }

  func testTaste() throws {
    try launch()
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element("destination.brew.new").waitForExistence(timeout: 5))
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    app.buttons["Save brew"].tap()
    let taste = element("today.taste")
    XCTAssertTrue(taste.waitForExistence(timeout: 5))
    taste.tap()
    XCTAssertTrue(element("taste.screen").waitForExistence(timeout: 5))
    element("taste.sour").tap()
    try shoot("06-taste")
  }

  func testBeansAndPrivacy() throws {
    try launch(["-demoBeans"])
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element("beans.list").waitForExistence(timeout: 10))
    try shoot("07-beans")
    app.buttons["Settings"].firstMatch.tap()
    let privacy = element("settings.privacy")
    XCTAssertTrue(element("tab.root.settings").waitForExistence(timeout: 10))
    for _ in 0..<6 where !privacy.isHittable { app.swipeUp() }
    privacy.tap()
    XCTAssertTrue(element("settings.privacy.summary").waitForExistence(timeout: 5))
    try shoot("08-privacy")
  }
}
