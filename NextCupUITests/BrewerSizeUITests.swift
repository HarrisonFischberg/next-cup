import XCTest

/// The brewer size question, Settings > Brewer sizes and the "Fits your …" line. Screenshots
/// are written while `docs/design/brewer-size/.capture` exists, with CAPTURE_PREFIX (default
/// new_).
@MainActor
final class BrewerSizeUITests: XCTestCase {
  private var app: XCUIApplication!

  private func element(_ id: String) -> XCUIElement {
    app.descendants(matching: .any)[id].firstMatch
  }

  private func shoot(_ name: String) {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../docs/design/brewer-size").standardized
    guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path)
    else { return }
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    try? app.screenshot().pngRepresentation.write(
      to: folder.appendingPathComponent("\(prefix)brewer-size-\(name).png"))
  }

  private func launch(_ extra: [String]) {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments =
      ["-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio"]
      + extra
    app.launch()
    XCTAssertTrue(element("tab.root.journal").waitForExistence(timeout: 10))
  }

  func testSizeQuestionStoresThePickShownInSettings() throws {
    launch(["-brewerSizeQuestion"])
    app.tabBars.buttons["Brew"].tap()
    element("recipes.add").tap()
    app.buttons["Create with AI"].firstMatch.tap()
    let question = element("brewerSize.question")
    XCTAssertTrue(question.waitForExistence(timeout: 5))
    XCTAssertTrue(element("brewerSize.switch-03").exists)
    XCTAssertTrue(element("brewerSize.skip").exists, "skip assumes the common size")
    shoot("question")
    element("brewerSize.switch-02").tap()
    XCTAssertTrue(question.waitForNonExistence(timeout: 5))
    element("recipe.create.cancel").tap()

    app.tabBars.buttons["Journal"].tap()
    let gear = element("journal.settings")
    if !gear.waitForExistence(timeout: 2) { app.tabBars.buttons["Journal"].tap() }
    gear.tap()
    XCTAssertTrue(element("tab.root.settings").waitForExistence(timeout: 5))
    let sizes = element("settings.brewerSizes")
    for _ in 0..<6 where !(sizes.exists && sizes.isHittable) { app.swipeUp() }
    XCTAssertTrue(sizes.isHittable)
    sizes.tap()
    let picker = element("settings.brewerSize.switchable-dripper")
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertTrue(picker.label.contains("Hario Switch 02"), picker.label)
    shoot("settings")
  }

  func testNextCupShowsItFitsTheBrewer() throws {
    launch(["-demoBrews", "-fakeNextCupAI"])
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.press(forDuration: 1.2)
    app.buttons["Ask AI for Next Cup"].firstMatch.tap()
    XCTAssertTrue(element("nextcup.done").waitForExistence(timeout: 15))
    let fit = element("recipe.fit")
    XCTAssertTrue(fit.exists)
    XCTAssertTrue(fit.label.hasPrefix("Fits your"), fit.label)
    shoot("result")
    element("nextcup.save").tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Next Cup'")).firstMatch.tap()
    XCTAssertTrue(element("recipe.nextCupNote").waitForExistence(timeout: 5))
    XCTAssertTrue(element("recipe.brewerSize").exists, "Start brew shows the brewer size")
    shoot("start-brew")
  }

  /// A built-in Switch steep turned up past what the Switch 03 holds is split to fit, and
  /// the brewer size is right there to change.
  func testBigSwitchBrewIsSplitToFit() throws {
    launch(["-brewer.size.switchable-dripper", "switch-03"])
    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    XCTAssertTrue(element("style.1").waitForExistence(timeout: 5))
    element("style.1").tap()
    let size = element("recipe.brewerSize")
    XCTAssertTrue(size.waitForExistence(timeout: 5))
    XCTAssertEqual(size.value as? String, "Hario Switch 03")
    XCTAssertFalse(element("recipe.fit").exists, "the recipe's own size fits")
    shoot("start-brew-size")
    let more = app.buttons["recipe.yield.increase"]
    // Clear of the Start brew bar pinned to the bottom.
    for _ in 0..<5 where !(more.exists && more.frame.maxY < app.frame.height - 220) {
      app.swipeUp(velocity: .slow)
    }
    for _ in 0..<20 where !element("recipe.fit").exists { more.tap() }
    let fit = element("recipe.fit")
    XCTAssertTrue(fit.exists, "a brew too big for the Switch 03 was not adjusted")
    XCTAssertTrue(fit.label.contains("Hario Switch 03"), fit.label)
    XCTAssertFalse(element("recipe.fit.warning").exists)
    shoot("fitted")
    app.swipeUp()
    shoot("fitted-steps")
  }

  /// Stepping the amount never moves the + under the finger: nothing above it changes height,
  /// whether the dose leaves the recipe's or the brew outgrows the brewer.
  func testSteppingTheAmountKeepsThePageStill() throws {
    launch(["-brewer.size.switchable-dripper", "switch-03"])
    app.tabBars.buttons["Brew"].tap()
    let method = element("brew.method.Switchable immersion dripper")
    XCTAssertTrue(method.waitForExistence(timeout: 10))
    method.tap()
    XCTAssertTrue(element("style.1").waitForExistence(timeout: 5))
    element("style.1").tap()
    let more = app.buttons["recipe.yield.increase"]
    XCTAssertTrue(more.waitForExistence(timeout: 5))
    for _ in 0..<5 where !(more.exists && more.frame.maxY < app.frame.height - 220) {
      app.swipeUp(velocity: .slow)
    }
    app.buttons["oz"].tap()
    var tops = [more.frame.minY]
    for _ in 0..<10 {
      more.tap()
      sleep(1)
      tops.append(more.frame.minY)
    }
    XCTAssertTrue(element("recipe.fit").exists, "the brew outgrew the Switch 03 on the way")
    shoot("no-jump")
    app.swipeDown(velocity: .slow)
    shoot("no-jump-dose")
    XCTAssertEqual(Set(tops.map { Int($0.rounded()) }).count, 1, "the + moved: \(tops)")
  }
}
