import XCTest

/// Brew advice on a bean: pick up to three tastes, get a recipe for each, save or compost
/// each one, then the Brew tab shows the saved ones to try. `-fakeBeanBrewAI` stands in for
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

  func testThreeTastesGiveARecipeEachToSaveOrCompost() throws {
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
    row.tap()
    element("bean.advice").tap()

    let ask = element("beanbrew.ask")
    XCTAssertTrue(ask.waitForExistence(timeout: 5))
    XCTAssertFalse(ask.isEnabled, "needs a taste")
    for taste in ["Chocolatey and full-bodied", "Bright and fruity", "Sweet and balanced"] {
      app.buttons[taste].tap()
    }
    XCTAssertFalse(app.buttons["Strong and bold"].isEnabled, "three at most")
    XCTAssertTrue(ask.isEnabled)
    shoot("ask")
    ask.tap()

    XCTAssertTrue(element("beanbrew.done").waitForExistence(timeout: 15))
    for rank in 1...3 { XCTAssertTrue(element("beanbrew.pick.\(rank)").exists) }
    shoot("result")
    func tap(_ id: String) {
      let button = element(id)
      for _ in 0..<4 where !button.isHittable { app.swipeUp() }
      button.tap()
    }
    tap("beanbrew.save.1")
    XCTAssertTrue(element("beanbrew.saved.1").waitForExistence(timeout: 5))
    tap("beanbrew.compost.2")
    tap("beanbrew.undo.2")
    tap("beanbrew.compost.2")
    shoot("decided")
    tap("beanbrew.save.3")

    // Every recipe decided: back to the Brew tab with the saved ones to try.
    let kicker = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] 'recipes for southern weather'")
    ).firstMatch
    XCTAssertTrue(kicker.waitForExistence(timeout: 8))
    let gone = expectation(
      for: NSPredicate(format: "exists == false"), evaluatedWith: element("beanbrew.sheet"))
    wait(for: [gone], timeout: 5)
    shoot("next-cup")
  }

  /// A new bean with no brews offers its three brews on its own page.
  func testNewBeanPageOffersThreeBrews() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-fakeBeanBrewAI",
    ]
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element("beans.aiAdd").waitForExistence(timeout: 5))
    shoot("beans-callout")
    app.buttons["Add a bean"].firstMatch.tap()
    XCTAssertTrue(element("beans.editor.aiFlow").waitForExistence(timeout: 5))
    shoot("add")
    // The flow starts with a card for its first step, not the scanner.
    element("beans.editor.aiFlow").tap()
    XCTAssertTrue(element("beans.flow.prompt").waitForExistence(timeout: 5))
    shoot("flow")
    element("beans.flow.stop").tap()
    let name = element("beans.editor.name")
    name.tap()
    name.typeText("Shelf Find")
    element("beans.editor.save").tap()
    app.buttons["beans.row.Shelf Find"].tap()
    let card = element("bean.adviceCard")
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    shoot("bean-card")
    card.tap()
    XCTAssertTrue(element("beanbrew.ask").waitForExistence(timeout: 5))
  }
}
