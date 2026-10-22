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
