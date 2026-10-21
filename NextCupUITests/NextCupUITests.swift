import XCTest

final class NextCupUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testAppLaunchesToRoot() {
    let app = XCUIApplication()
    app.launch()
    let root = app.descendants(matching: .any)["launch.root"].firstMatch
    XCTAssertTrue(root.waitForExistence(timeout: 10))
  }
}
