import XCTest

/// Long-press a card in Journal and in Brew, pick Favorite, and the star shows. While
/// `docs/design/favorites/.capture` exists it also saves screenshots named with
/// CAPTURE_PREFIX and CAPTURE_VARIANT (light or dark, set with `simctl ui appearance`).
final class FavoriteUITests: XCTestCase {
  @MainActor
  func testLongPressFavoriteStarsJournalAndBrewCards() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/favorites")
    let capturing = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let environment = ProcessInfo.processInfo.environment
    let prefix = environment["CAPTURE_PREFIX"] ?? "new_"
    let variant = environment["CAPTURE_VARIANT"] ?? "light"
    for style in capturing ? ["sundayStudio", "steelBlue"] : ["sundayStudio"] {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-demoBrews", "-resetNavigationState", "-resetDraft", "-appStyle", style,
      ]
      app.launch()

      app.tabBars.buttons["Journal"].tap()
      let row = app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'")).firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertFalse(row.label.contains("Favorite"))
      row.press(forDuration: 1.2)
      let favorite = app.buttons["journal.favorite"]
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
      favorite.tap()
      XCTAssertTrue(waitForLabel(row, contains: "Favorite"))
      if capturing { try shoot(app, folder, "\(prefix)favorite-journal-\(style)-\(variant)") }

      // The menu's dismiss can swallow the first tab tap, so tap until Brew is on screen.
      let card = app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH 'recipe.row.'")).firstMatch
      for _ in 0..<3 where !card.isHittable {
        app.tabBars.buttons["Brew"].tap()
        _ = XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate(format: "isHittable == true"), object: card)
          ],
          timeout: 3)
      }
      XCTAssertTrue(card.isHittable)
      card.press(forDuration: 1.2)
      let star = app.buttons["recipe.favorite"]
      XCTAssertTrue(star.waitForExistence(timeout: 5))
      star.tap()
      XCTAssertTrue(waitForLabel(card, contains: "Favorite"))
      if capturing {
        try shoot(app, folder, "\(prefix)favorite-brew-\(style)-\(variant)")
      }
      app.terminate()
    }
  }

  private func waitForLabel(_ element: XCUIElement, contains text: String) -> Bool {
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5)
      == .completed
  }

  private func shoot(_ app: XCUIApplication, _ folder: URL, _ name: String) throws {
    sleep(1)
    try app.screenshot().pngRepresentation.write(
      to: folder.appendingPathComponent("\(name).png"))
  }
}
