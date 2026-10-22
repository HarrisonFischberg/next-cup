import XCTest

final class NextCupUITests: XCTestCase {
  private let sampleID = "6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B"

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(deepLink: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
    if let deepLink { app.launchArguments += ["-deepLink", deepLink] }
    app.launch()
    return app
  }

  private func scrollUntilHittable(_ target: XCUIElement, in app: XCUIApplication) {
    var swipes = 0
    while !target.isHittable && swipes < 12 {
      app.swipeUp()
      swipes += 1
    }
  }

  /// The text inside a tile after its title: value, unit and target, in order.
  private func text(_ app: XCUIApplication, in identifier: String) -> String {
    element(app, identifier).staticTexts.allElementsBoundByIndex.dropFirst().map { $0.label }
      .joined(separator: " ")
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

  /// Opens a recipe's detail with a sped-up timer clock and taps Start brew.
  @MainActor
  private func openTimer(speed: Int, extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      ["-inMemoryStore", "-resetNavigationState", "-resetDraft", "-timerSpeed", "\(speed)"]
      + extraArguments
    app.launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Recipes"].tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    let start = app.buttons["Start brew"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    XCTAssertTrue(element(app, "timer.screen").waitForExistence(timeout: 5))
    return app
  }

  @MainActor
  func testTimerRunsARecipeToTheEndAndOpensThePrefilledForm() {
    let app = openTimer(speed: 60)
    XCTAssertTrue(element(app, "timer.status").label.hasPrefix("READY"))
    app.buttons["Start"].tap()
    // Pause and resume keep the controls reachable and change the label.
    XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
    app.buttons["Pause"].tap()
    XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "timer.status").label.contains("PAUSED"))
    app.buttons["Resume"].tap()

    // Sixty times faster, the whole recipe takes a few seconds.
    let form = element(app, "brewform.prefilled")
    XCTAssertTrue(form.waitForExistence(timeout: 30), "timer never reached the brew form")
    XCTAssertTrue(
      text(app, in: "brewform.dose").hasPrefix("15"), "dose prefilled: \(app.debugDescription)")
    XCTAssertTrue(text(app, in: "brewform.water").hasPrefix("250"))
    XCTAssertFalse(text(app, in: "brewform.time").hasPrefix("0:00"))
    // The recipe's number sits beside the value, not in place of it.
    XCTAssertTrue(text(app, in: "brewform.time").contains("TARGET"))

    // Back returns to the finished timer, which can reopen the form.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["Log this brew"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLoggingAFinishedBrewSavesItOnceAndLocksTheTimerButton() {
    let app = openTimer(speed: 60)
    app.buttons["Start"].tap()
    XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 30))
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.saved").waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["Brew logged"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Brew logged"].isEnabled)
  }

  @MainActor
  func testTimerKeepsTimeWhileTheAppIsInTheBackground() {
    let app = openTimer(speed: 6)
    app.buttons["Start"].tap()
    XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
    XCUIDevice.shared.press(.home)
    sleep(6)  // 36 timer seconds pass while the app is not running its tick
    app.activate()
    XCTAssertTrue(element(app, "timer.screen").waitForExistence(timeout: 10))
    // Six real seconds at 6x is 36 timer seconds, so the readout cannot still say zero.
    let spoken = element(app, "timer.elapsed").value.map { "\($0)" } ?? ""
    let finished = element(app, "brewform.prefilled").exists
    XCTAssertTrue(
      finished || (!spoken.isEmpty && spoken != "0 seconds"),
      "time moved on in the background, got '\(spoken)'")
  }

  @MainActor
  func testEndEarlyOpensTheFormWithTheTimeReached() {
    let app = openTimer(speed: 20)
    app.buttons["Start"].tap()
    XCTAssertTrue(app.buttons["End early"].waitForExistence(timeout: 5))
    sleep(2)
    app.buttons["End early"].tap()
    XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 10))
    XCTAssertFalse(text(app, in: "brewform.time").hasPrefix("0:00"))
    XCTAssertTrue(app.staticTexts["You ended this brew early. The time is what it reached."].exists)
  }

  // MARK: Brew form (S02)

  /// Opens the blank form through the deep link, with dose and water set.
  @MainActor
  private func openBlankForm(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      ["-inMemoryStore", "-resetNavigationState", "-resetDraft", "-deepLink", "nextcup://brew/new"]
      + extraArguments
    app.launch()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 10))
    return app
  }

  @MainActor
  func testJournalOffersLogABrewAndOpensTheBlankForm() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.buttons["Log a brew"].tap()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Save brew"].isEnabled, "nothing to save yet")
    XCTAssertTrue(element(app, "brewform.save.hint").exists)
  }

  @MainActor
  func testBrewFormDraftSurvivesRelaunch() {
    let app = openBlankForm()
    app.buttons["Increase Dose"].tap()
    let grind = app.textFields["brewform.grind"]
    scrollUntilHittable(grind, in: app)
    // Lift the field clear of the Save bar with a short drag.
    let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
    let higher = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
    mid.press(forDuration: 0.05, thenDragTo: higher)
    grind.tap()
    grind.typeText("21 clicks")
    app.keyboards.buttons["Done"].tap()  // dismisses the keyboard and the draft stays
    sleep(1)  // autosave waits for typing to pause

    app.terminate()
    app.launchArguments = ["-inMemoryStore", "-deepLink", "nextcup://brew/new"]
    app.launch()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 10))
    XCTAssertTrue(element(app, "brewform.notice").waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["brewform.grind"].value as? String, "21 clicks")
    XCTAssertTrue(text(app, in: "brewform.dose").hasPrefix("15"))
  }

  @MainActor
  func testFailedSaveShowsTheErrorAndKeepsTheDraftUntilARetrySucceeds() {
    let app = openBlankForm(extraArguments: ["-failBrewSave"])
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.error").waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Save brew"].isEnabled, "the draft stays savable")
    XCTAssertFalse(element(app, "brewform.saved").exists)

    app.terminate()
    app.launchArguments = ["-inMemoryStore", "-deepLink", "nextcup://brew/new"]
    app.launch()
    XCTAssertTrue(element(app, "brewform.notice").waitForExistence(timeout: 10))
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.saved").waitForExistence(timeout: 5))
  }

  @MainActor
  func testKeyboardNeverCoversSaveAtTheLargestTextSize() {
    let app = openBlankForm(extraArguments: [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ])
    let notes = element(app, "brewform.notes")
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    scrollUntilHittable(notes, in: app)
    notes.tap()
    notes.typeText("Sweet and clean")
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
    let save = app.buttons["Save brew"]
    XCTAssertTrue(save.exists)
    XCTAssertLessThanOrEqual(
      save.frame.maxY, keyboard.frame.minY + 1,
      "Save (\(save.frame)) must sit above the keyboard (\(keyboard.frame))")
  }

  // MARK: Journal (S01)

  /// Logs one brew from the empty journal, with a note to search for, and
  /// returns to the list.
  @MainActor
  private func logBrew(_ app: XCUIApplication, note: String) {
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    let notes = element(app, "brewform.notes")
    scrollUntilHittable(notes, in: app)
    notes.tap()
    notes.typeText(note)
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.saved").waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 5))
  }

  @MainActor
  private func journalRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
  }

  /// F01 end to end: log a brew, find it by search, edit it, and delete it with Undo.
  @MainActor
  func testJournalLogsFindsEditsAndDeletesABrewWithUndo() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["NO BREWS YET"].exists, "empty journal offers the next action")

    logBrew(app, note: "Washed Ethiopia sweet")
    XCTAssertTrue(journalRow(app, containing: "Washed Ethiopia sweet").waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["NO BREWS YET"].exists)

    // Search finds it; a miss shows the way out.
    let search = app.searchFields.firstMatch
    search.tap()
    search.typeText("zzzz")
    XCTAssertTrue(app.staticTexts["NO MATCHES"].waitForExistence(timeout: 5))
    app.buttons["Clear filters"].tap()
    XCTAssertTrue(journalRow(app, containing: "Washed Ethiopia sweet").waitForExistence(timeout: 5))
    search.tap()
    search.typeText("ethiopia")
    let row = journalRow(app, containing: "Washed Ethiopia sweet")
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.label.contains("15 g"), "row shows the dose, got \(row.label)")

    // Edit: the form opens on the saved values; Save changes the same brew.
    row.tap()
    XCTAssertTrue(element(app, "brewform.edit").waitForExistence(timeout: 5))
    XCTAssertTrue(text(app, in: "brewform.dose").hasPrefix("15"))
    app.buttons["Increase Dose"].tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.saved").waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    XCTAssertTrue(
      journalRow(app, containing: "15.1 g").waitForExistence(timeout: 5),
      "list shows the edited dose: \(app.debugDescription)")

    // Delete with Undo: the row goes, Undo brings it back untouched.
    let edited = journalRow(app, containing: "Washed Ethiopia sweet")
    edited.swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["Brew deleted"].waitForExistence(timeout: 5))
    XCTAssertFalse(journalRow(app, containing: "Washed Ethiopia sweet").exists)
    app.buttons["UNDO"].tap()
    XCTAssertTrue(journalRow(app, containing: "Washed Ethiopia sweet").waitForExistence(timeout: 5))

    // Delete again and let the toast run out: the brew stays gone.
    journalRow(app, containing: "Washed Ethiopia sweet").swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["NO BREWS YET"].waitForExistence(timeout: 5))
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: app.staticTexts["Brew deleted"])
    waitForExpectations(timeout: 12)
    XCTAssertTrue(app.staticTexts["NO BREWS YET"].exists)
  }

  /// X2: "Brew again" opens a new brew with the old amounts and none of the old
  /// notes, and saving it adds a second brew.
  @MainActor
  func testBrewAgainRepeatsASavedBrew() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    logBrew(app, note: "Washed Ethiopia sweet")
    let row = journalRow(app, containing: "Washed Ethiopia sweet")
    XCTAssertTrue(row.waitForExistence(timeout: 5))

    // Leading swipe is the quick path; the context menu and VoiceOver action
    // reach the same screen.
    row.swipeRight()
    app.buttons["Brew again"].tap()
    XCTAssertTrue(element(app, "brewform.again").waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["BREW AGAIN"].exists)
    XCTAssertTrue(text(app, in: "brewform.dose").hasPrefix("15"), "dose carried over")
    XCTAssertTrue(text(app, in: "brewform.time").hasPrefix("—"), "time starts empty")
    XCTAssertEqual(
      element(app, "brewform.notes").value as? String ?? "", "", "the old notes are not copied")

    app.buttons["Save brew"].tap()
    XCTAssertTrue(element(app, "brewform.saved").waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
    XCTAssertTrue(
      rows.element(boundBy: 1).waitForExistence(timeout: 5), "the repeat is a second brew")
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(
      journalRow(app, containing: "Washed Ethiopia sweet").exists, "the first is intact")
  }

  private func openMethods(_ app: XCUIApplication) {
    app.tabBars.buttons["Settings"].tap()
    XCTAssertTrue(element(app, "settings.methods").waitForExistence(timeout: 5))
    element(app, "settings.methods").tap()
    XCTAssertTrue(element(app, "methods.screen").waitForExistence(timeout: 5))
  }

  private func addMethod(_ app: XCUIApplication, name: String, switchOff: String) {
    app.buttons["methods.add"].tap()
    let field = element(app, "methods.editor.name")
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(name)
    app.keyboards.buttons["Done"].tap()
    // The switch element spans the row; its thumb is at the trailing edge.
    app.switches[switchOff].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    XCTAssertEqual(app.switches[switchOff].value as? String, "0", "\(switchOff) is switched off")
    app.buttons["methods.editor.save"].tap()
    XCTAssertTrue(element(app, "methods.row.\(name)").waitForExistence(timeout: 5))
  }

  /// T012: add a method with a field switched off, move it up without a drag,
  /// hide another, and see the brew form follow.
  @MainActor
  func testMethodsAddReorderHideAndShapeTheBrewForm() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    openMethods(app)
    addMethod(app, name: "Moka pot", switchOff: "Temperature")

    // The new method is last; "Move up" in its editor puts it above the old last.
    let rows = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'methods.row.'"))
    let before = rows.count
    XCTAssertEqual(rows.element(boundBy: before - 1).identifier, "methods.row.Moka pot")
    element(app, "methods.row.Moka pot").tap()
    XCTAssertTrue(element(app, "methods.editor.name").waitForExistence(timeout: 5))
    XCTAssertEqual(
      app.switches["Temperature"].value as? String, "0", "the switch stayed off after saving")
    XCTAssertEqual(app.switches["Grind setting"].value as? String, "1")
    let up = element(app, "methods.editor.up")
    var swipes = 0
    while !up.isHittable && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertTrue(up.isHittable, "Move up is reachable by scrolling")
    up.tap()
    app.buttons["methods.editor.cancel"].tap()
    XCTAssertTrue(element(app, "methods.screen").waitForExistence(timeout: 5))
    XCTAssertEqual(rows.element(boundBy: before - 2).identifier, "methods.row.Moka pot")

    // Hiding keeps the row, marked, and takes it out of the picker.
    let press = element(app, "methods.row.Press pot")
    press.swipeLeft()
    app.buttons["Hide"].tap()
    XCTAssertTrue(
      element(app, "methods.row.Press pot").label.contains("hidden"),
      "hidden rows stay in the list: \(element(app, "methods.row.Press pot").label)")

    app.tabBars.buttons["Journal"].tap()
    app.buttons["Log a brew"].tap()
    XCTAssertTrue(element(app, "brewform.blank").waitForExistence(timeout: 5))
    XCTAssertTrue(
      element(app, "brewform.temperature").exists, "the first method tracks temperature")
    element(app, "brewform.method").tap()
    XCTAssertTrue(app.buttons["Moka pot"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Press pot"].exists, "a hidden method is not offered")
    app.buttons["Moka pot"].tap()
    XCTAssertTrue(element(app, "brewform.grind").waitForExistence(timeout: 5))
    XCTAssertFalse(
      element(app, "brewform.temperature").exists, "temperature is off for Moka pot")
    XCTAssertTrue(element(app, "brewform.dose").exists && element(app, "brewform.water").exists)
  }

  /// Writes the methods list, editor and shaped form in light, dark and the
  /// largest text size. Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureMethodsScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
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
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      app.tabBars.buttons["Settings"].tap()
      XCTAssertTrue(element(app, "settings.methods").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/settings-\(variant.name).png")
      element(app, "settings.methods").tap()
      XCTAssertTrue(element(app, "methods.screen").waitForExistence(timeout: 5))
      let press = element(app, "methods.row.Press pot")
      scrollUntilHittable(press, in: app)
      press.swipeLeft()
      app.buttons["Hide"].tap()
      try save(app.screenshot(), "\(folderURL.path)/methods-list-\(variant.name).png")
      for _ in 0..<6 { app.swipeDown() }
      element(app, "methods.row.Cone dripper").tap()
      XCTAssertTrue(element(app, "methods.editor.name").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/methods-editor-\(variant.name).png")
      app.terminate()
    }
  }

  /// Writes journal screenshots in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureJournalScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
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
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      try save(app.screenshot(), "\(folderURL.path)/journal-empty-\(variant.name).png")
      logBrew(app, note: "Washed Ethiopia sweet")
      XCTAssertTrue(journalRow(app, containing: "Washed Ethiopia").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/journal-list-\(variant.name).png")
      journalRow(app, containing: "Washed Ethiopia").swipeLeft()
      app.buttons["Delete"].tap()
      XCTAssertTrue(app.staticTexts["Brew deleted"].waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/journal-undo-\(variant.name).png")
      app.terminate()
    }
  }

  /// Writes "Brew again" screenshots in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureBrewAgainScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
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
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      logBrew(app, note: "Washed Ethiopia sweet")
      let row = journalRow(app, containing: "Washed Ethiopia")
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      row.swipeRight()
      try save(app.screenshot(), "\(folderURL.path)/journal-brew-again-swipe-\(variant.name).png")
      app.buttons["Brew again"].tap()
      XCTAssertTrue(element(app, "brewform.again").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/brewform-again-\(variant.name).png")
      app.terminate()
    }
  }

  /// Writes form screenshots in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureBrewFormScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
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
      let app = openTimer(
        speed: 60,
        extraArguments: variant.size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
      app.buttons["Start"].tap()
      XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 30))
      try save(app.screenshot(), "\(folderURL.path)/brewform-prefilled-\(variant.name).png")
      if variant.name == "light" {
        app.swipeUp()
        try save(app.screenshot(), "\(folderURL.path)/brewform-lower-light.png")
      }
      app.terminate()
      let blank = openBlankForm(
        extraArguments: variant.size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
      try save(blank.screenshot(), "\(folderURL.path)/brewform-blank-\(variant.name).png")
      blank.terminate()
    }
  }

  /// Writes timer screenshots (ready and running) in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureTimerScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
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
      var extra: [String] = []
      if let size = variant.size { extra = ["-UIPreferredContentSizeCategoryName", size] }
      let app = openTimer(speed: 1, extraArguments: extra)
      try save(app.screenshot(), "\(folderURL.path)/timer-ready-\(variant.name).png")
      app.buttons["Start"].tap()
      XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
      sleep(3)
      try save(app.screenshot(), "\(folderURL.path)/timer-running-\(variant.name).png")
      app.terminate()
    }
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
