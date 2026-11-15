import XCTest

/// Journal cards name the recipe each brew used. Long-press one to favorite the brew and its
/// recipe together, or to save a deleted recipe again; a saved brew's page offers Brew Again. While `docs/design/brew-again/.capture` exists it also saves
/// screenshots named with CAPTURE_PREFIX and CAPTURE_VARIANT (light or dark, set with
/// `simctl ui appearance`).
final class JournalRecipeUITests: XCTestCase {
  @MainActor
  func testJournalCardNamesRecipeFavoritesAndRestoresIt() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/brew-again")
    let capturing = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    let environment = ProcessInfo.processInfo.environment
    let prefix = environment["CAPTURE_PREFIX"] ?? "new_"
    let variant = environment["CAPTURE_VARIANT"] ?? "light"
    for style in capturing ? ["sundayStudio", "steelBlue"] : ["sundayStudio"] {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-demoBrews", "-fakeNextCupAI", "-resetNavigationState", "-resetDraft",
        "-appStyle", style,
      ]
      app.launch()

      app.tabBars.buttons["Journal"].tap()
      let anyRow = rows(app).firstMatch
      XCTAssertTrue(anyRow.waitForExistence(timeout: 10))
      if capturing { try shoot(app, folder, "\(prefix)journal-recipe-\(style)-\(variant)") }
      // The "before" capture runs on the build before this change: its menu and saved brew.
      if prefix == "old_" {
        let row = rows(app, labelContains: "Recipe: ").firstMatch
        row.press(forDuration: 1.2)
        _ = app.buttons["journal.favorite"].waitForExistence(timeout: 5)
        try shoot(app, folder, "\(prefix)journal-recipe-menu-\(style)-\(variant)")
        app.buttons["journal.favorite"].tap()
        row.tap()
        _ = app.buttons["brewform.askNextCup"].waitForExistence(timeout: 5)
        try shoot(app, folder, "\(prefix)saved-brew-\(style)-\(variant)")
        try openBeanBrews(app, folder, "\(prefix)bean-brews-\(style)-\(variant)")
        app.terminate()
        continue
      }

      // A brew whose recipe still exists: one Favorite on the card, none for the recipe alone.
      let used = rows(app, labelContains: "Recipe: ").matching(
        NSPredicate(format: "NOT label CONTAINS 'Recipe deleted'")
      ).firstMatch
      XCTAssertTrue(used.waitForExistence(timeout: 5))
      XCTAssertFalse(used.label.contains("Favorite"))
      used.press(forDuration: 1.2)
      let favorite = app.buttons["journal.favorite"]
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["journal.favoriteRecipe"].exists)
      if capturing { try shoot(app, folder, "\(prefix)journal-recipe-menu-\(style)-\(variant)") }
      favorite.tap()
      XCTAssertTrue(waitForLabel(used, contains: "Favorite"))

      // A brew whose recipe was deleted: save it again.
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
      if capturing {
        try shoot(app, folder, "\(prefix)journal-recipe-after-\(style)-\(variant)")
      }

      // The favorited brew's page: Brew Again opens the recipe's Start brew page.
      used.tap()
      let again = app.buttons["brewform.brewAgain"]
      XCTAssertTrue(again.waitForExistence(timeout: 5))
      if capturing { try shoot(app, folder, "\(prefix)saved-brew-\(style)-\(variant)") }
      again.tap()
      XCTAssertTrue(app.buttons["Start brew"].waitForExistence(timeout: 10))
      if capturing { try shoot(app, folder, "\(prefix)brew-again-start-\(style)-\(variant)") }

      // Beans: a bean's brews, best rated first, open the same page with Brew Again.
      try openBeanBrews(app, folder, capturing ? "\(prefix)bean-brews-\(style)-\(variant)" : nil)
      let best = app.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH 'bean.brew.'")
      ).firstMatch
      XCTAssertTrue(best.waitForExistence(timeout: 5))
      best.tap()
      XCTAssertTrue(app.buttons["brewform.brewAgain"].waitForExistence(timeout: 5))
      app.terminate()
    }
  }

  /// Opens the demo bag on the Beans tab and scrolls to its brews.
  private func openBeanBrews(_ app: XCUIApplication, _ folder: URL, _ shot: String?) throws {
    app.tabBars.buttons["Beans"].tap()
    let bag = app.descendants(matching: .any)["beans.row.Southern Weather"]
    XCTAssertTrue(bag.waitForExistence(timeout: 5))
    bag.tap()
    let row = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'bean.brew'")
    ).firstMatch
    // The brews sit at the foot of the page.
    for _ in 0..<4 { app.swipeUp() }
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    if let shot { try shoot(app, folder, shot) }
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
