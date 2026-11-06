import XCTest

/// Brew advice on a bean: pick how it should taste, get three ranked brews, and Start brew
/// opens that recipe's Start brew page with the bean chosen. `-fakeBeanBrewAI` stands in for
/// the AI; parsing and saving are real. Screenshots are written while
/// `docs/design/brew-advice/.capture` exists, with CAPTURE_PREFIX (default new_).
@MainActor
final class BeanBrewAdviceUITests: XCTestCase {
  private var app: XCUIApplication!

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func shoot(_ name: String) {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../docs/design/brew-advice").standardized
    guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path)
    else { return }
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    try? app.screenshot().pngRepresentation.write(
      to: folder.appendingPathComponent("\(prefix)brew-advice-\(name).png"))
  }

  func testTasteGoalGivesThreeBrewsAndStartBrewChoosesTheBean() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-demoBrews", "-fakeBeanBrewAI",
    ]
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'beans.row.'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    let beanName = String(row.identifier.dropFirst("beans.row.".count))
    row.tap()
    element("bean.advice").tap()

    let ask = element("beanbrew.ask")
    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    XCTAssertFalse(ask.isEnabled, "needs a goal")
    app.buttons["Chocolatey and full-bodied"].tap()
    XCTAssertTrue(ask.isEnabled)
    shoot("ask")
    ask.tap()

    XCTAssertTrue(element("beanbrew.done").waitForExistence(timeout: 15))
    for rank in 1...3 { XCTAssertTrue(element("beanbrew.pick.\(rank)").exists) }
    shoot("result")
    let start = element("beanbrew.start.1")
    for _ in 0..<4 where !start.isHittable { app.swipeUp() }
    start.tap()

    let beans = element("recipe.beans")
    XCTAssertTrue(beans.waitForExistence(timeout: 5))
    XCTAssertEqual(beans.value as? String, beanName)
    XCTAssertFalse(element("beanbrew.sheet").exists)
    shoot("start-brew")
  }
}
