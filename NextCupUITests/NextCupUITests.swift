import XCTest

final class NextCupUITests: XCTestCase {
  private let sampleID = "6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B"

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(deepLink: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-inMemoryStore", "-resetNavigationState"]
    if let deepLink { app.launchArguments += ["-deepLink", deepLink] }
    app.launch()
    return app
  }

  private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  @MainActor
  func testAppLaunchesToJournalTab() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    for title in ["Journal", "Recipes", "Beans", "Explore", "Settings"] {
      XCTAssertTrue(app.tabBars.buttons[title].exists, "missing tab \(title)")
    }
  }

  @MainActor
  func testEveryDeepLinkOpensItsScreen() {
    let links: [(url: String, destination: String, tab: String)] = [
      ("nextcup://brew/new", "destination.brew.new", "Journal"),
      ("nextcup://brew/\(sampleID)", "destination.brew.\(sampleID)", "Journal"),
      ("nextcup://recipe/\(sampleID)", "destination.recipe.\(sampleID)", "Recipes"),
      ("nextcup://bean/\(sampleID)", "destination.bean.\(sampleID)", "Beans"),
    ]
    for link in links {
      let app = launch(deepLink: link.url)
      XCTAssertTrue(
        element(app, link.destination).waitForExistence(timeout: 10),
        "\(link.url) did not open \(link.destination)")
      XCTAssertTrue(app.tabBars.buttons[link.tab].isSelected, "\(link.url) not on \(link.tab)")
      app.terminate()
    }
  }

  @MainActor
  func testMalformedDeepLinkIsIgnored() {
    let app = launch(deepLink: "nextcup://recipe/not-a-uuid")
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Journal"].isSelected)
  }

  @MainActor
  func testRecipeLibraryGroupsSearchesAndScales() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Recipes"].tap()
    XCTAssertTrue(element(app, "tab.root.recipes").waitForExistence(timeout: 5))
    XCTAssertTrue(
      element(app, "POUR OVER").waitForExistence(timeout: 5),
      "recipes are grouped by style: \(app.debugDescription)")

    // No match shows the empty state with a way out.
    let search = app.searchFields.firstMatch
    search.tap()
    search.typeText("zzzz")
    XCTAssertTrue(app.staticTexts["NO MATCHES"].waitForExistence(timeout: 5))
    app.buttons["Clear search"].tap()

    search.tap()
    search.typeText("balanced")
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()

    let water = element(app, "recipe.water")
    XCTAssertTrue(water.waitForExistence(timeout: 5))
    XCTAssertTrue(water.label.contains("250"), "unscaled water is 250 g, got \(water.label)")
    app.buttons["Increase dose"].tap()  // 15 g to 15.5 g: 250 g x 15.5 / 15 = 258 g
    XCTAssertTrue(water.label.contains("258"), "scaled water is 258 g, got \(water.label)")
    XCTAssertTrue(element(app, "recipe.dose.reset").exists)
    element(app, "recipe.dose.reset").tap()
    XCTAssertTrue(water.label.contains("250"))
  }

  /// Writes library and detail screenshots in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureRecipeScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    let folder = folderURL.path
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let variants: [(name: String, appearance: XCUIDevice.Appearance, size: String?)] = [
      ("light", .light, nil),
      ("dark", .dark, nil),
      ("largest-text", .light, "UICTContentSizeCategoryAccessibilityXXXL"),
    ]
    defer { XCUIDevice.shared.appearance = .light }
    for variant in variants {
      XCUIDevice.shared.appearance = variant.appearance
      let app = XCUIApplication()
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState"]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      app.tabBars.buttons["Recipes"].tap()
      XCTAssertTrue(app.staticTexts["POUR OVER"].waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folder)/recipes-library-\(variant.name).png")

      app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'")).firstMatch
        .tap()
      XCTAssertTrue(element(app, "recipe.water").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folder)/recipe-detail-\(variant.name).png")
      if variant.name == "light" {
        app.swipeUp()
        try save(app.screenshot(), "\(folder)/recipe-detail-steps-light.png")
      }
      app.terminate()
    }
  }

  private func save(_ screenshot: XCUIScreenshot, _ path: String) throws {
    try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
  }

  @MainActor
  func testSelectedTabRestoresAfterRelaunch() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))

    app.terminate()
    // Relaunch without the reset flag, as the user would.
    app.launchArguments = ["-inMemoryStore"]
    app.launch()

    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Beans"].isSelected)
  }
}
