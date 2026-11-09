import XCTest

/// Journal cards name the recipe each brew used. Long-press one to favorite that recipe, or
/// to save a deleted one again. While `docs/design/journal-recipe/.capture` exists it also saves
/// screenshots named with CAPTURE_PREFIX and CAPTURE_VARIANT (light or dark, set with
/// `simctl ui appearance`).
final class JournalRecipeUITests: XCTestCase {
  @MainActor
  func testJournalCardNamesRecipeFavoritesAndRestoresIt() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/journal-recipe")
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
      let anyRow = rows(app).firstMatch
      XCTAssertTrue(anyRow.waitForExistence(timeout: 10))
      if capturing { try shoot(app, folder, "\(prefix)journal-recipe-\(style)-\(variant)") }
      // The "before" capture runs on a build without recipe lines: the card is all it shows.
      if prefix == "old_" {
        app.terminate()
        continue
      }

      // A brew whose recipe still exists: favorite the recipe from the card.
      let used = rows(app, labelContains: "Recipe: ").matching(
        NSPredicate(format: "NOT label CONTAINS 'Recipe deleted'")
      ).firstMatch
      XCTAssertTrue(used.waitForExistence(timeout: 5))
      XCTAssertFalse(used.label.contains("favorite recipe"))
      used.press(forDuration: 1.2)
      let favorite = app.buttons["journal.favoriteRecipe"]
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
      if capturing { try shoot(app, folder, "\(prefix)journal-recipe-menu-\(style)-\(variant)") }
      favorite.tap()
      XCTAssertTrue(waitForLabel(used, contains: "favorite recipe"))

      // A brew whose recipe was deleted: save it again, then it can be favorited.
      let orphan = rows(app, labelContains: "Recipe deleted").firstMatch
      XCTAssertTrue(orphan.waitForExistence(timeout: 5))
      let orphanID = orphan.identifier
      orphan.press(forDuration: 1.2)
      let restore = app.buttons["journal.restoreRecipe"]
      XCTAssertTrue(restore.waitForExistence(timeout: 5))
      restore.tap()
      let restored = app.descendants(matching: .any)[orphanID]
      XCTAssertTrue(waitForLabel(restored, contains: "Recipe: "))
      XCTAssertFalse(restored.label.contains("Recipe deleted"))
      restored.press(forDuration: 1.2)
      XCTAssertTrue(app.buttons["journal.favoriteRecipe"].waitForExistence(timeout: 5))
      app.buttons["journal.favoriteRecipe"].tap()
      XCTAssertTrue(waitForLabel(restored, contains: "favorite recipe"))
      if capturing {
        try shoot(app, folder, "\(prefix)journal-recipe-after-\(style)-\(variant)")
      }
      app.terminate()
    }
  }

  private func rows(_ app: XCUIApplication, labelContains text: String? = nil) -> XCUIElementQuery {
    let format =
      "identifier BEGINSWITH 'journal.row.' AND NOT identifier BEGINSWITH 'journal.row.dialin'"
    let predicate =
      text.map { NSPredicate(format: format + " AND label CONTAINS %@", $0) }
      ?? NSPredicate(format: format)
    return app.descendants(matching: .any).matching(predicate)
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
