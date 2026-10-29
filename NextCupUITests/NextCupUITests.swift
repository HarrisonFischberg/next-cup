import XCTest

final class NextCupUITests: XCTestCase {
  private let sampleID = "6F1B7A52-3C4D-4E5F-8A9B-0C1D2E3F4A5B"

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(deepLink: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
    ]
    if let deepLink { app.launchArguments += ["-deepLink", deepLink] }
    app.launch()
    return app
  }

  private func scrollUntilHittable(_ target: XCUIElement, in app: XCUIApplication) {
    var swipes = 0
    // Drag in the left gutter: a swipe through the middle can land on a wheel and turn it.
    while !target.isHittable && swipes < 12 {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
      swipes += 1
    }
    // A swipe can carry the target up under the navigation bar, where a tap does not
    // reach it; a short drag brings it back down.
    if target.exists, target.frame.minY < 120 {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
    }
  }

  /// The text inside a tile after its title: value, unit and target, in order.
  private func text(_ app: XCUIApplication, in identifier: String) -> String {
    element(app, identifier).staticTexts.allElementsBoundByIndex.dropFirst().map { $0.label }
      .joined(separator: " ")
  }

  /// Settings sits behind the Journal's gear. Tapping the selected Journal tab
  /// again pops its stack, so the gear is always reachable.
  private func openSettings(_ app: XCUIApplication) {
    app.tabBars.buttons["Journal"].tap()
    let gear = element(app, "journal.settings")
    if !gear.waitForExistence(timeout: 2) { app.tabBars.buttons["Journal"].tap() }
    XCTAssertTrue(gear.waitForExistence(timeout: 5))
    gear.tap()
    XCTAssertTrue(element(app, "tab.root.settings").waitForExistence(timeout: 5))
  }

  private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  /// The wheel inside a SwiftUI wheel Picker, found by the Picker's identifier.
  private func grindWheel(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
    let wheel = app.pickerWheels[identifier]
    return wheel.exists ? wheel : app.pickers[identifier].pickerWheels.firstMatch
  }

  @MainActor
  func testAppLaunchesToJournalTab() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    for title in ["Brew", "Journal", "Beans", "Explore"] {
      XCTAssertTrue(app.tabBars.buttons[title].exists, "missing tab \(title)")
    }
    XCTAssertFalse(app.tabBars.buttons["Settings"].exists, "Settings is behind the gear")
    XCTAssertTrue(element(app, "journal.settings").exists)
  }

  @MainActor
  func testEveryDeepLinkOpensItsScreen() {
    let links: [(url: String, destination: String, tab: String)] = [
      ("nextcup://brew/new", "destination.brew.new", "Journal"),
      ("nextcup://brew/\(sampleID)", "destination.brew.\(sampleID)", "Journal"),
      ("nextcup://recipe/\(sampleID)", "destination.recipe.\(sampleID)", "Brew"),
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
  func testFlavorExplorerReachesEveryBucket() {
    let app = launch()
    app.tabBars.buttons["Explore"].tap()
    let entry = element(app, "explore.flavors")
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.tap()
    XCTAssertTrue(element(app, "flavor.list").waitForExistence(timeout: 10))
    let buckets = [
      "flavor": [
        "citrus", "stone-fruit", "berry", "tropical", "floral", "chocolate", "nutty", "caramel",
        "spice", "roasted",
      ],
      "origin": ["east-africa", "central-america", "south-america", "asia-pacific", "caribbean"],
      "process": ["washed", "natural", "honey", "experimental"],
      "roast": ["light", "medium", "dark"],
      "brewer": ["pourOver", "immersion", "espresso", "cold"],
    ]
    for (dimension, keys) in buckets {
      for key in keys {
        let row = element(app, "flavor.bucket.\(dimension).\(key)")
        // The list is lazy: start from the top each time, then scroll down to the row.
        for _ in 0..<6 { app.swipeDown() }
        scrollUntilHittable(row, in: app)
        XCTAssertTrue(row.isHittable, "bucket \(dimension).\(key) is not reachable")
      }
    }
    for _ in 0..<14 { app.swipeDown() }
    element(app, "flavor.bucket.flavor.citrus").tap()
    XCTAssertTrue(element(app, "flavor.detail.flavor.citrus").waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["WORDS THAT MAP HERE"].exists)
  }

  @MainActor
  func testCatalogCoffeeStartsAStarterBrew() {
    let app = launch()
    app.tabBars.buttons["Explore"].tap()
    let entry = element(app, "explore.catalog")
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.tap()
    let roaster = element(app, "catalog.roaster.huckleberry")
    XCTAssertTrue(roaster.waitForExistence(timeout: 10))
    roaster.tap()
    let coffee = element(app, "catalog.coffee.huck-ethiopia-haro-beddame")
    XCTAssertTrue(coffee.waitForExistence(timeout: 10))
    coffee.tap()
    XCTAssertTrue(element(app, "catalog.coffee").waitForExistence(timeout: 10))
    element(app, "catalog.add").tap()
    XCTAssertTrue(element(app, "catalog.message").waitForExistence(timeout: 5))
    let brew = element(app, "catalog.brew.pourOver")
    scrollUntilHittable(brew, in: app)
    brew.tap()
    XCTAssertTrue(element(app, "timer.status").waitForExistence(timeout: 10))
    XCTAssertTrue(element(app, "timer.status").label.hasPrefix("Ready"))
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
    app.tabBars.buttons["Brew"].tap()
    XCTAssertTrue(element(app, "tab.root.recipes").waitForExistence(timeout: 5))
    XCTAssertTrue(
      element(app, "POUR OVER").waitForExistence(timeout: 5),
      "recipes are grouped by style: \(app.debugDescription)")

    // No match shows the empty state with a way out.
    let search = element(app, "recipes.search")
    search.tap()
    search.typeText("zzzz")
    XCTAssertTrue(app.staticTexts["NO MATCHES"].waitForExistence(timeout: 5))
    app.buttons["Clear search"].firstMatch.tap()  // the field and the empty state both offer it

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

  @MainActor
  func testChangingUnitsInSettingsUpdatesRecipesAndTheBrewForm() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    openSettings(app)
    let weight = element(app, "settings.units.weight")
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.buttons["Ounces (oz)"].tap()
    defer {  // the setting outlives the app run, so put it back
      openSettings(app)
      element(app, "settings.units.weight").buttons["Grams (g)"].tap()
    }

    app.tabBars.buttons["Brew"].tap()

    // Brew types open their styles; Balanced cone is a Cone dripper style.

    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    let water = element(app, "recipe.water")
    XCTAssertTrue(water.waitForExistence(timeout: 5))
    XCTAssertTrue(water.label.contains("oz"), "recipe water in ounces, got \(water.label)")
    XCTAssertFalse(water.label.contains("250"), "grams value still shown: \(water.label)")

    app.tabBars.buttons["Journal"].tap()
    app.tabBars.buttons["Journal"].tap()  // pops Settings off the Journal's stack
    app.buttons["Log a brew"].firstMatch.tap()
    // A blank form has no dose yet; stepping gives it the default, shown in ounces.
    let increase = app.buttons["Increase Dose"]
    XCTAssertTrue(increase.waitForExistence(timeout: 5))
    increase.tap()
    let dose = element(app, "brewform.dose")
    XCTAssertTrue(dose.waitForExistence(timeout: 5))
    let shown = text(app, in: "brewform.dose")
    XCTAssertTrue(shown.contains("oz"), "brew form dose in ounces, got \(shown)")
  }

  /// Opens a recipe's detail with a sped-up timer clock and taps Start brew.
  @MainActor
  /// A finished timer waits on its finish screen until Rate while sippin’ or Rate after this cup is tapped.
  /// Reaching the target offers Finish brew; the brew keeps running until it is tapped.
  private func tasteAndLog(_ app: XCUIApplication, timeout: TimeInterval) {
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: timeout), "timer never reached the target")
    finish.tap()
    let log = app.buttons["Rate while sippin’"]
    XCTAssertTrue(log.waitForExistence(timeout: 5), "finish never offered the log")
    log.tap()
  }

  private func openTimer(speed: Int, extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
        "-timerSpeed", "\(speed)",
      ]
      + extraArguments
    app.launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    // Brew types open their styles; Balanced cone is a Cone dripper style.
    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
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
    XCTAssertTrue(
      element(app, "timer.status").label.hasPrefix("Ready"), app.debugDescription)
    app.buttons["Start"].tap()
    // Pause and resume keep the controls reachable and change the label.
    XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
    app.buttons["Pause"].tap()
    XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "timer.status").label.contains("Paused"))
    app.buttons["Resume"].tap()

    // Sixty times faster, the target comes in a few seconds. The brew runs on until
    // Finish brew, and the log waits for a tap.
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 30), "timer never reached the target")
    XCTAssertTrue(element(app, "timer.status").label.contains("Target reached"))
    finish.tap()
    XCTAssertTrue(element(app, "timer.finished").waitForExistence(timeout: 5))
    app.buttons["Rate while sippin’"].tap()
    let form = element(app, "brewform.prefilled")
    XCTAssertTrue(form.waitForExistence(timeout: 5), "timer never reached the brew form")
    XCTAssertTrue(
      text(app, in: "brewform.dose").hasPrefix("15"), "dose prefilled: \(app.debugDescription)")
    XCTAssertTrue(text(app, in: "brewform.water").hasPrefix("250"))
    XCTAssertFalse(text(app, in: "brewform.time").hasPrefix("0:00"))
    // The recipe's number sits beside the value, not in place of it.
    XCTAssertTrue(text(app, in: "brewform.time").contains("TARGET"))

    // Back returns to the finished timer, which can reopen the form.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["Rate while sippin’"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLoggingAFinishedBrewSavesItOnceAndLandsOnTheJournal() {
    let app = openTimer(speed: 60)
    app.buttons["Start"].tap()
    tasteAndLog(app, timeout: 30)
    XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 5))
    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
    let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(rows.count, 1, "the brew is saved once")
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
    let finished = element(app, "timer.finished").exists
    XCTAssertTrue(
      finished || (!spoken.isEmpty && spoken != "0 seconds"),
      "time moved on in the background, got '\(spoken)'")
  }

  @MainActor
  func testEndEarlyOpensTheFormWithTheTimeReached() {
    let app = openTimer(speed: 20)
    app.buttons["Start"].tap()
    let end = app.buttons["End brew"]  // timer.screen's identifier covers the button's own
    XCTAssertTrue(end.waitForExistence(timeout: 5))
    sleep(2)
    end.tap()
    app.buttons["End and log it"].tap()
    let log = app.buttons["Rate while sippin’"]
    XCTAssertTrue(log.waitForExistence(timeout: 5), "ending early offers the log")
    log.tap()
    XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 5))
    XCTAssertFalse(text(app, in: "brewform.time").hasPrefix("0:00"))
    XCTAssertTrue(app.staticTexts["You ended this brew early. The time is what it reached."].exists)
  }

  @MainActor
  func testRateAfterThisCupSavesTheBrewToUnsavedBrewsWithItsTime() {
    let app = openTimer(speed: 60)
    app.buttons["Start"].tap()
    let finish = app.buttons["Finish brew"]
    XCTAssertTrue(finish.waitForExistence(timeout: 30), "timer never reached the target")
    finish.tap()
    let later = app.buttons["Rate after this cup"]
    XCTAssertTrue(
      later.waitForExistence(timeout: 5), "finish never offered Rate after this cup")
    XCTAssertTrue(app.buttons["Rate while sippin’"].exists)
    later.tap()
    // Back on the Journal, with a note saying where the brew went.
    XCTAssertTrue(element(app, "journal.savedLater").waitForExistence(timeout: 5))
    let row = element(app, "journal.unsaved.row")
    XCTAssertTrue(row.waitForExistence(timeout: 5), "no Unsaved Brews row")
    scrollUntilHittable(row, in: app)
    row.tap()
    XCTAssertTrue(element(app, "brewform.dose").waitForExistence(timeout: 5))
    XCTAssertTrue(text(app, in: "brewform.dose").hasPrefix("15"), app.debugDescription)
    XCTAssertTrue(text(app, in: "brewform.water").hasPrefix("250"))
    XCTAssertFalse(text(app, in: "brewform.time").hasPrefix("0:00"))
  }

  // MARK: Brew form (S02)

  /// Opens the blank form through the deep link, with dose and water set.
  @MainActor
  private func openBlankForm(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
        "-deepLink", "nextcup://brew/new",
      ]
      + extraArguments
    app.launch()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 10))
    return app
  }

  /// Relaunches without resetting drafts and opens the first Unsaved brew in the Journal.
  private func relaunchAndOpenUnsavedBrew(_ app: XCUIApplication) {
    app.terminate()
    app.launchArguments = ["-inMemoryStore", "-appStyle", "steelKraft"]
    app.launch()
    let row = element(app, "journal.unsaved.row")
    app.tabBars.buttons["Journal"].tap()
    if !row.waitForExistence(timeout: 3) { app.tabBars.buttons["Journal"].tap() }
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    scrollUntilHittable(row, in: app)
    row.tap()
  }

  @MainActor
  func testJournalOffersLogABrewAndOpensTheBlankForm() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Save brew"].isEnabled, "nothing to save yet")
  }

  @MainActor
  func testBrewFormDraftSurvivesRelaunch() {
    let app = openBlankForm()
    app.buttons["Increase Dose"].tap()
    let grind = grindWheel(app, "brewform.grind")
    scrollUntilHittable(grind, in: app)
    grind.adjust(toPickerWheelValue: "21")
    sleep(1)  // autosave waits for a pause

    relaunchAndOpenUnsavedBrew(app)
    XCTAssertTrue(grindWheel(app, "brewform.grind").waitForExistence(timeout: 10))
    XCTAssertFalse(element(app, "brewform.notice").exists, "a reopened brew needs no banner")
    XCTAssertEqual(grindWheel(app, "brewform.grind").value as? String, "21")
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

    relaunchAndOpenUnsavedBrew(app)
    XCTAssertTrue(app.buttons["Save brew"].waitForExistence(timeout: 10))
    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
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
    // The Save bar steps aside while typing, so nothing floats over the keyboard.
    let save = app.buttons["Save brew"]
    XCTAssertTrue(save.waitForNonExistence(timeout: 2), "Save hides while the keyboard is up")
    app.toolbars.buttons["Done"].firstMatch.tap()
    XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
    XCTAssertTrue(save.waitForExistence(timeout: 2), "Done brings Save back")
    XCTAssertTrue(save.isHittable)
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
    app.toolbars.buttons["Done"].firstMatch.tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 5))
  }

  /// Writes the Brew flow (types, styles, start brew steps) and onboarding step 1 in the
  /// default style, light and dark. Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureBrewStylesScreenshots() throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    for (name, appearance) in [("light", XCUIDevice.Appearance.light), ("dark", .dark)] {
      XCUIDevice.shared.appearance = appearance
      let app = XCUIApplication()
      app.launchArguments = ["-inMemoryStore", "-resetNavigationState", "-resetDraft"]
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      app.tabBars.buttons["Brew"].tap()
      let cone = element(app, "brew.method.Cone dripper")
      XCTAssertTrue(cone.waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/brew-types-\(name).png")
      cone.tap()
      XCTAssertTrue(app.staticTexts["Pick a style"].waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/brew-styles-\(name).png")
      app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'")).firstMatch
        .tap()
      XCTAssertTrue(element(app, "recipe.water").waitForExistence(timeout: 5))
      scrollUntilHittable(element(app, "recipe.step.0"), in: app)
      app.swipeUp()
      try save(app.screenshot(), "\(folderURL.path)/brew-start-steps-\(name).png")
      app.terminate()

      app.launchArguments += ["-showOnboarding"]
      app.launch()
      _ = app.staticTexts["Switchable immersion dripper"].waitForExistence(timeout: 10)
      try save(app.screenshot(), "\(folderURL.path)/onboarding-methods-\(name).png")
      app.terminate()
    }
  }

  /// Set-up's bean step: pick two popular coffees and they land in Beans; the other
  /// routes (photo, barcode, typing) are offered beside the list.
  @MainActor
  func testOnboardingAddsBeansPickedFromThePopularList() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      "-showOnboarding",
    ]
    app.launch()
    element(app, "onboarding.next").tap()
    element(app, "onboarding.next").tap()
    element(app, "onboarding.next").tap()
    let search = element(app, "onboarding.beans.search")
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "onboarding.beans.photo").exists)
    XCTAssertTrue(element(app, "onboarding.beans.barcode").exists)
    XCTAssertTrue(element(app, "onboarding.beans.manual").exists)
    XCTAssertFalse(element(app, "onboarding.next").isEnabled, "nothing to add before a pick")
    search.tap()
    search.typeText("hair bender")
    element(app, "onboarding.bean.Hair Bender").tap()
    search.tap()
    search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 11) + "monarch")
    element(app, "onboarding.bean.Monarch").tap()
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    if FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".capture").path) {
      try save(app.screenshot(), "\(folderURL.path)/onboarding-beans.png")
    }
    app.buttons["Add 2 beans"].tap()
    let start = app.buttons["Start brewing"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "beans.row.Hair Bender").waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "beans.row.Monarch").exists)
  }

  /// Set-up's grinder: Other shows a name field; picking a listed grinder again hides it.
  @MainActor
  func testOtherGrinderFieldGoesAwayWhenAListedGrinderIsPicked() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      "-showOnboarding",
    ]
    app.launch()
    let picker = element(app, "onboarding.grinder")
    XCTAssertTrue(picker.waitForExistence(timeout: 10))
    picker.tap()
    let other = app.buttons["Other…"]
    XCTAssertTrue(other.waitForExistence(timeout: 5))
    other.tap()
    XCTAssertTrue(element(app, "onboarding.grinder.name").waitForExistence(timeout: 5))
    picker.tap()
    app.buttons["Baratza Encore"].tap()
    XCTAssertTrue(element(app, "onboarding.grinder.name").waitForNonExistence(timeout: 5))
    XCTAssertTrue(picker.label.contains("Baratza Encore"), "got \(picker.label)")
  }

  /// Each brew type's styles end with Your Style, which opens a blank recipe on that method.
  @MainActor
  func testYourStyleOpensABlankRecipeOnTheMethod() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    element(app, "brew.method.Press pot").tap()
    let yours = element(app, "style.yours")
    XCTAssertTrue(yours.waitForExistence(timeout: 5))
    scrollUntilHittable(yours, in: app)
    yours.tap()
    XCTAssertTrue(element(app, "recipe.editor").waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.buttons["Press pot"].exists || app.staticTexts["Press pot"].exists,
      "the method is set: \(app.debugDescription)")
  }

  /// Start brew: tap the dose to type grams; water scales and pour-over times stretch gently.
  /// After Start, the time stays on screen.
  @MainActor
  func testTypingADoseScalesWaterAndPourTimesAndTheTimerStaysInView() throws {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    element(app, "brew.method.Cone dripper").tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'")).firstMatch
      .tap()
    let value = element(app, "stepper.dose.value")
    XCTAssertTrue(value.waitForExistence(timeout: 5))
    value.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()  // caret after "15"
    value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "30")
    let doubled = NSPredicate(format: "label CONTAINS %@", "500")
    expectation(for: doubled, evaluatedWith: element(app, "recipe.water"))
    waitForExpectations(timeout: 5)  // the water target follows the dose
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    let capture = FileManager.default.fileExists(
      atPath: folderURL.appendingPathComponent(".capture").path)
    if capture { try save(app.screenshot(), "\(folderURL.path)/start-brew-top.png") }
    app.buttons["Start brew"].tap()
    XCTAssertTrue(element(app, "timer.screen").waitForExistence(timeout: 5))
    app.buttons["Start"].tap()
    sleep(2)
    XCTAssertTrue(element(app, "timer.elapsed").isHittable, "the time stays in view")
    if capture { try save(app.screenshot(), "\(folderURL.path)/timer-running.png") }
  }

  /// One brew type picked in set-up: Start brewing goes straight to its styles.
  @MainActor
  func testOneBrewTypeInSetUpOpensItsStyles() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      "-showOnboarding",
    ]
    app.launch()
    XCTAssertTrue(element(app, "onboarding.next").waitForExistence(timeout: 10))
    for name in [
      "Flat-bed dripper", "Switchable immersion dripper", "Press pot", "Inverted press",
      "Espresso", "Iced pour over", "Cold brew", "Moka pot", "AeroPress", "Chemex",
      "Drip machine",
    ] {
      app.buttons[name].tap()
    }
    element(app, "onboarding.next").tap()
    element(app, "onboarding.next").tap()
    element(app, "onboarding.next").tap()
    element(app, "onboarding.later").tap()
    app.buttons["Start brewing"].tap()
    XCTAssertTrue(app.staticTexts["Pick a style"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Cone dripper"].exists)
  }

  /// The daily loop: a brew saved untasted waits on the journal; tasting it
  /// offers one change for the next cup (or says to keep it the same).
  @MainActor
  func testDailyLoopTastesASavedCupAndOffersTheNextChange() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    logBrew(app, note: "Kenya, tasting later")
    XCTAssertTrue(element(app, "journal.today").waitForExistence(timeout: 5))
    element(app, "today.taste").tap()
    XCTAssertTrue(element(app, "taste.screen").waitForExistence(timeout: 5))
    let seeChange = app.buttons["See tomorrow's change"]
    XCTAssertTrue(seeChange.waitForExistence(timeout: 5))
    XCTAssertFalse(seeChange.isEnabled, "nothing to save before a taste is chosen")
    element(app, "taste.sour").tap()
    seeChange.tap()
    let change = element(app, "taste.change")
    let keep = element(app, "taste.keep")
    XCTAssertTrue(
      change.waitForExistence(timeout: 5) || keep.exists,
      "shows the next step: \(app.debugDescription)")
    let finish = change.exists ? app.buttons["Use tomorrow"] : app.buttons["Done"]
    finish.tap()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 5))
  }

  /// Writes daily loop screenshots (Daily style) in light, dark and the largest text.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureDailyLoopScreenshots() throws {
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "daily", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      logBrew(app, note: "Blackcurrant, tasting later")
      XCTAssertTrue(element(app, "journal.today").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/daily-journal-\(variant.name).png")
      element(app, "today.taste").tap()
      XCTAssertTrue(element(app, "taste.screen").waitForExistence(timeout: 5))
      element(app, "taste.sour").tap()
      try save(app.screenshot(), "\(folderURL.path)/daily-taste-\(variant.name).png")
      app.buttons["See tomorrow's change"].tap()
      XCTAssertTrue(
        element(app, "taste.change").waitForExistence(timeout: 5)
          || element(app, "taste.keep").exists)
      try save(app.screenshot(), "\(folderURL.path)/daily-next-\(variant.name).png")
      app.terminate()
    }
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
    XCTAssertTrue(app.staticTexts["GETTING STARTED"].exists, "empty journal offers the next action")

    logBrew(app, note: "Washed Ethiopia sweet")
    XCTAssertTrue(journalRow(app, containing: "Washed Ethiopia sweet").waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["GETTING STARTED"].exists)

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

    // Edit: the brew opens locked on the saved values; Edit unlocks it and Save
    // changes the same brew.
    row.tap()
    XCTAssertTrue(element(app, "brewform.edit").waitForExistence(timeout: 5))
    XCTAssertTrue(text(app, in: "brewform.dose").hasPrefix("15"))
    element(app, "brewform.unlock").tap()
    app.buttons["Increase Dose"].tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
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
    XCTAssertTrue(app.staticTexts["GETTING STARTED"].waitForExistence(timeout: 5))
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: app.staticTexts["Brew deleted"])
    waitForExpectations(timeout: 12)
    XCTAssertTrue(app.staticTexts["GETTING STARTED"].exists)
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
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
    let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journal.row.'"))
    XCTAssertTrue(
      rows.element(boundBy: 1).waitForExistence(timeout: 5), "the repeat is a second brew")
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(
      journalRow(app, containing: "Washed Ethiopia sweet").exists, "the first is intact")
  }

  /// T033: "Ask AI about this brew" shows exactly what would be sent, and with no
  /// provider, model or key chosen it offers no way to send. Writes screenshots to
  /// `SCREENSHOT_DIR` (set with `TEST_RUNNER_SCREENSHOT_DIR`), else /tmp/next-cup-screenshots.
  @MainActor
  func testAskAIShowsThePayloadAndCannotSendWithoutSetup() {
    let variants: [(name: String, args: [String])] = [
      ("light", ["-AppleInterfaceStyle", "Light"]),
      ("dark", ["-AppleInterfaceStyle", "Dark"]),
      (
        "largest-text",
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
      ),
    ]
    for variant in variants {
      let app = XCUIApplication()
      app.launchArguments =
        ["-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft"]
        + variant.args
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      logBrew(app, note: "Washed Ethiopia sweet")
      // The Today card for the untasted brew sits above the row.
      let row = journalRow(app, containing: "Washed Ethiopia sweet")
      scrollUntilHittable(row, in: app)
      row.tap()
      XCTAssertTrue(element(app, "brewform.edit").waitForExistence(timeout: 5))
      let ask = element(app, "brewform.ai")
      scrollUntilHittable(ask, in: app)
      ask.tap()

      let preview = element(app, "ai.ask.preview")
      XCTAssertTrue(preview.waitForExistence(timeout: 5))
      XCTAssertTrue(preview.label.contains("notes: Washed Ethiopia sweet"), preview.label)
      XCTAssertTrue(preview.label.contains("dose 15 g"), preview.label)
      XCTAssertTrue(element(app, "ai.ask.setup").exists, "setup is named, not hidden")
      XCTAssertFalse(element(app, "ai.ask.send").exists, "no Send without a key and a model")
      let folder = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
          ?? "/tmp/next-cup-screenshots")
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try? XCUIScreen.main.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("T033-ask-\(variant.name).png"))
      element(app, "ai.ask.close").tap()
      XCTAssertTrue(element(app, "brewform.edit").waitForExistence(timeout: 5))
      app.terminate()
    }
  }

  /// T013: customizing a built-in saves a separate copy; the original is untouched.
  @MainActor
  func testCustomizingABuiltInRecipeSavesACopy() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Brew"].tap()
    // Brew types open their styles; Balanced cone is a Cone dripper style.
    app.descendants(matching: .any)["brew.method.Cone dripper"].firstMatch.tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    element(app, "recipe.menu").tap()
    app.buttons["Customize"].tap()
    XCTAssertTrue(element(app, "recipe.editor").waitForExistence(timeout: 5))
    let name = element(app, "recipe.editor.name")
    XCTAssertEqual(name.value as? String, "Balanced cone (copy)")
    let dose = element(app, "recipe.editor.dose")
    XCTAssertEqual(dose.value as? String, "15")
    dose.tap()
    dose.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "18")
    app.buttons["recipe.editor.save"].tap()
    XCTAssertTrue(element(app, "recipe.editor").waitForNonExistence(timeout: 5))

    // Back in the library, both recipes exist with their own doses.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let copy = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Balanced cone (copy)'"))
      .firstMatch
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertTrue(copy.label.contains("18"), "the copy carries the new dose: \(copy.label)")
    let original = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'Balanced cone' AND NOT label CONTAINS[c] 'copy'")
    ).firstMatch
    XCTAssertTrue(original.exists)
    XCTAssertTrue(original.label.contains("15 g"), "the original is unchanged: \(original.label)")
  }

  private func openMethods(_ app: XCUIApplication) {
    openSettings(app)
    scrollUntilHittable(element(app, "settings.methods"), in: app)  // below the looks grid
    XCTAssertTrue(element(app, "settings.methods").waitForExistence(timeout: 5))
    element(app, "settings.methods").tap()
    XCTAssertTrue(element(app, "methods.screen").waitForExistence(timeout: 5))
  }

  private func addMethod(_ app: XCUIApplication, name: String, switchOff: String) {
    app.buttons["methods.add"].tap()
    let field = element(app, "methods.editor.name")
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    // Return dismisses the keyboard; the Done key is not always hittable.
    field.typeText(name + "\n")
    // The switch element spans the row; its thumb is at the trailing edge.
    app.switches[switchOff].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    XCTAssertEqual(app.switches[switchOff].value as? String, "0", "\(switchOff) is switched off")
    app.buttons["methods.editor.save"].tap()
    scrollUntilHittable(element(app, "methods.row.\(name)"), in: app)  // new rows go last
    XCTAssertTrue(element(app, "methods.row.\(name)").waitForExistence(timeout: 5))
  }

  /// T012: add a method with a field switched off, move it up without a drag,
  /// hide another, and see the brew form follow.
  @MainActor
  func testMethodsAddReorderHideAndShapeTheBrewForm() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    openMethods(app)
    addMethod(app, name: "Siphon", switchOff: "Temperature")

    // The new method is last; "Move up" in its editor puts it above the old last.
    let rows = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'methods.row.'"))
    let before = rows.count
    XCTAssertEqual(rows.element(boundBy: before - 1).identifier, "methods.row.Siphon")
    element(app, "methods.row.Siphon").tap()
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
    XCTAssertEqual(rows.element(boundBy: before - 2).identifier, "methods.row.Siphon")

    // Hiding keeps the row, marked, and takes it out of the picker.
    let press = element(app, "methods.row.Press pot")
    for _ in 0..<6 where !press.isHittable { app.swipeDown() }
    press.swipeLeft()
    app.buttons["Hide"].tap()
    XCTAssertTrue(
      element(app, "methods.row.Press pot").label.contains("hidden"),
      "hidden rows stay in the list: \(element(app, "methods.row.Press pot").label)")

    app.tabBars.buttons["Journal"].tap()
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element(app, "brewform.blank").waitForExistence(timeout: 5))
    XCTAssertTrue(
      element(app, "brewform.temperature").exists, "the first method tracks temperature")
    element(app, "brewform.method").tap()
    XCTAssertTrue(app.buttons["Siphon"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Press pot"].exists, "a hidden method is not offered")
    app.buttons["Siphon"].tap()
    XCTAssertTrue(element(app, "brewform.grind").waitForExistence(timeout: 5))
    XCTAssertFalse(
      element(app, "brewform.temperature").exists, "temperature is off for Siphon")
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      openSettings(app)
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
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

  /// Writes roaster catalog screenshots in light, dark and the largest text size.
  /// Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureCatalogScreenshots() throws {
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      app.tabBars.buttons["Explore"].tap()
      element(app, "explore.catalog").tap()
      XCTAssertTrue(element(app, "catalog.roaster.huckleberry").waitForExistence(timeout: 10))
      try save(app.screenshot(), "\(folderURL.path)/catalog-roasters-\(variant.name).png")
      element(app, "catalog.roaster.huckleberry").tap()
      let coffee = element(app, "catalog.coffee.huck-ethiopia-haro-beddame")
      XCTAssertTrue(coffee.waitForExistence(timeout: 10))
      try save(app.screenshot(), "\(folderURL.path)/catalog-coffees-\(variant.name).png")
      coffee.tap()
      XCTAssertTrue(element(app, "catalog.add").waitForExistence(timeout: 10))
      try save(app.screenshot(), "\(folderURL.path)/catalog-coffee-\(variant.name).png")
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
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
      tasteAndLog(app, timeout: 30)
      XCTAssertTrue(element(app, "brewform.prefilled").waitForExistence(timeout: 5))
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
      app.launchArguments = ["-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState"]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      app.tabBars.buttons["Brew"].tap()
      XCTAssertTrue(app.staticTexts["POUR OVER"].waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folder)/recipes-library-\(variant.name).png")

      element(app, "brew.method.Cone dripper").tap()
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

  // MARK: Beans (S03, S04)

  /// Adds a bean through the editor sheet: name, roaster and bag weight.
  @MainActor
  private func addBean(_ app: XCUIApplication, name: String, roaster: String, weight: String) {
    app.buttons["Add a bean"].firstMatch.tap()
    let field = element(app, "beans.editor.name")
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(name)
    let roasterField = element(app, "beans.editor.roaster")
    roasterField.tap()
    roasterField.typeText(roaster)
    app.buttons["Done"].tap()
    let bag = element(app, "beans.editor.bagWeight")
    scrollUntilHittable(bag, in: app)
    bag.tap()
    bag.typeText(weight)
    app.buttons["Done"].tap()
    app.buttons["beans.editor.save"].tap()
    XCTAssertTrue(element(app, "beans.editor").waitForNonExistence(timeout: 5))
  }

  @MainActor
  private func openBeans() -> XCUIApplication {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))
    return app
  }

  @MainActor
  func testBrewThisBeanOpensANewBrewWithTheBean() {
    let app = openBeans()
    addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
    element(app, "beans.row.Washed Ethiopia").tap()
    let brew = element(app, "bean.brew")
    XCTAssertTrue(brew.waitForExistence(timeout: 5), "bean detail has one primary action")
    brew.tap()
    XCTAssertTrue(element(app, "brewform.blank").waitForExistence(timeout: 5))
    let beans = element(app, "brewform.beans")
    XCTAssertTrue(beans.waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Washed Ethiopia'"))
        .firstMatch
        .exists, "the form starts with the bean: \(beans.debugDescription)")
  }

  @MainActor
  func testOnboardingShowsItsStepsAndEndsOnANextStep() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      "-showOnboarding",
    ]
    app.launch()
    let progress = element(app, "progress.step")
    XCTAssertTrue(progress.waitForExistence(timeout: 10))
    XCTAssertTrue(progress.label.contains("Step 1 of 4"), "got \(progress.label)")
    XCTAssertFalse(element(app, "onboarding.back").exists, "nothing before step 1")
    element(app, "onboarding.next").tap()
    XCTAssertTrue(progress.label.contains("Step 2 of 4"), "got \(progress.label)")
    element(app, "onboarding.back").tap()
    XCTAssertTrue(progress.label.contains("Step 1 of 4"), "Back returns a step")
    element(app, "onboarding.next").tap()
    element(app, "onboarding.next").tap()
    XCTAssertTrue(progress.label.contains("Step 3 of 4"), "got \(progress.label)")
    XCTAssertTrue(element(app, "onboarding.ai").exists, "step 3 is Apple Intelligence")
    element(app, "onboarding.next").tap()
    XCTAssertTrue(progress.label.contains("Step 4 of 4"), "got \(progress.label)")
    element(app, "onboarding.later").tap()
    let finish = app.buttons["Start brewing"]
    XCTAssertTrue(finish.waitForExistence(timeout: 5), "the finish names the next step")
    finish.tap()
    XCTAssertTrue(app.tabBars.buttons["Brew"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.tabBars.buttons["Brew"].isSelected)
  }

  @MainActor
  func testOnboardingCanBeSkippedFromTheFirstStep() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      "-showOnboarding",
    ]
    app.launch()
    XCTAssertTrue(element(app, "onboarding.skip").waitForExistence(timeout: 10))
    element(app, "onboarding.skip").tap()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 5))
  }

  @MainActor
  func testGettingStartedCountsWhatIsAlreadyDone() {
    let app = launch()
    let count = element(app, "gettingStarted.count")
    XCTAssertTrue(count.waitForExistence(timeout: 10))
    // Methods are seeded and units have defaults; a bag and a first brew are left.
    XCTAssertEqual(count.label, "2 of 4 set up")
  }

  @MainActor
  func testSettingsLinkOpensSettingsOnTheJournal() {
    let app = launch(deepLink: "nextcup://settings")
    XCTAssertTrue(element(app, "tab.root.settings").waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Journal"].isSelected)
  }

  /// T014: add a bean, see freshness and what is left, correct the amount, filter
  /// by status, and delete with Undo.
  @MainActor
  func testBeansAddCorrectFilterAndDeleteWithUndo() {
    let app = openBeans()
    XCTAssertTrue(app.staticTexts["NO BEANS YET"].exists, "empty library offers the next action")

    addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
    let row = element(app, "beans.row.Washed Ethiopia")
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.label.contains("250 g left"), "row shows what is left: \(row.label)")
    XCTAssertTrue(row.label.contains("Tiny Roastery"))
    XCTAssertFalse(app.staticTexts["NO BEANS YET"].exists)

    // Detail: freshness unknown without a roast date; correct the amount.
    row.tap()
    XCTAssertTrue(element(app, "bean.freshness").waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "bean.freshness").label.contains("No roast date"))
    let remaining = element(app, "bean.remaining")
    XCTAssertTrue(remaining.label.contains("250 g of 250 g"), "got \(remaining.label)")
    element(app, "bean.correct").tap()
    let amount = app.alerts.textFields.firstMatch
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "100")
    app.alerts.buttons["Save"].tap()
    // The label updates after the alert closes; wait for it instead of reading it at once.
    let updated = NSPredicate(format: "label CONTAINS %@", "100 g of 250 g")
    expectation(for: updated, evaluatedWith: remaining)
    waitForExpectations(timeout: 10)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").label.contains("100 g left"))

    // Status filter: the bean is in use, so Wishlist shows the way out.
    element(app, "beans.filter.status").tap()
    app.buttons["Wishlist"].tap()
    XCTAssertTrue(app.staticTexts["NO MATCHES"].waitForExistence(timeout: 5))
    app.buttons["Clear filters"].tap()
    XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").waitForExistence(timeout: 5))

    // Delete with Undo brings it back; letting the toast run out removes it.
    element(app, "beans.row.Washed Ethiopia").swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["Bean deleted"].waitForExistence(timeout: 5))
    app.buttons["UNDO"].tap()
    XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").waitForExistence(timeout: 5))
    element(app, "beans.row.Washed Ethiopia").swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["NO BEANS YET"].waitForExistence(timeout: 5))
  }

  /// Writes bean library, detail and editor screenshots in light, dark and the
  /// largest text size. Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureBeanScreenshots() throws {
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
      app.tabBars.buttons["Beans"].tap()
      XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/beans-empty-\(variant.name).png")
      addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
      XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/beans-list-\(variant.name).png")
      element(app, "beans.row.Washed Ethiopia").tap()
      XCTAssertTrue(element(app, "bean.freshness").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/bean-detail-\(variant.name).png")
      element(app, "bean.edit").tap()
      XCTAssertTrue(element(app, "beans.editor.name").waitForExistence(timeout: 5))
      try save(app.screenshot(), "\(folderURL.path)/bean-editor-\(variant.name).png")
      app.terminate()
    }
  }

  // MARK: Barcode (T037)

  /// The Simulator has no camera: Scan the barcode explains why and offers the
  /// AI photo route instead, and nothing is looked up or saved.
  @MainActor
  func testBarcodeWithoutACameraExplainsAndOffersThePhotoRoute() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    app.buttons["Add a bean"].firstMatch.tap()
    let barcode = app.buttons["beans.editor.barcode"]
    XCTAssertTrue(barcode.waitForExistence(timeout: 5))
    barcode.tap()
    XCTAssertTrue(element(app, "beans.editor.scan.error").waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["beans.editor.photoRoute"].exists)
    app.buttons["beans.editor.cancel"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))
  }

  // MARK: Blends, freezer, best so far (T015)

  /// Adds two beans, logs a graded 50/50 blend of them, then opens the first
  /// bean's detail. `shot` is called with a name at each screen worth capturing.
  @MainActor
  private func runBlendFlow(_ app: XCUIApplication, shot: (String) throws -> Void) throws {
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))
    addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
    XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").waitForExistence(timeout: 5))
    app.buttons["Add a bean"].firstMatch.tap()
    let field = element(app, "beans.editor.name")
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("Natural Brazil")
    app.buttons["Done"].tap()
    let bag = element(app, "beans.editor.bagWeight")
    scrollUntilHittable(bag, in: app)
    bag.tap()
    bag.typeText("250")
    app.buttons["Done"].tap()
    app.buttons["beans.editor.save"].tap()
    XCTAssertTrue(element(app, "beans.row.Natural Brazil").waitForExistence(timeout: 5))

    app.tabBars.buttons["Journal"].tap()
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "brewform.beans.empty").waitForExistence(timeout: 5))
    element(app, "brewform.beans.add").tap()
    app.buttons["Washed Ethiopia"].tap()
    element(app, "brewform.beans.add").tap()
    app.buttons["Natural Brazil"].tap()
    // Share buttons appear only once the brew is a blend.
    let moreEthiopia = app.buttons["Increase Washed Ethiopia share"]
    XCTAssertTrue(moreEthiopia.waitForExistence(timeout: 5))
    app.buttons["Increase Dose"].tap()
    app.buttons["Increase Water"].tap()
    moreEthiopia.tap()  // 55 / 45
    try shot("brewform-blend")

    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")

    app.tabBars.buttons["Beans"].tap()
    element(app, "beans.row.Washed Ethiopia").tap()
    XCTAssertTrue(element(app, "bean.freezer").waitForExistence(timeout: 5))
    // 15 g dose at 55%: 8.25 g came off this bag, so 241.75 g is left (shown rounded).
    XCTAssertTrue(
      element(app, "bean.remaining").label.contains("of 250"),
      "got \(element(app, "bean.remaining").label)")
    XCTAssertFalse(element(app, "bean.remaining").label.contains("250 g of 250"))
    element(app, "bean.freezer.toggle").tap()
    XCTAssertTrue(element(app, "bean.freezer").label.contains("Since"))
    try shot("bean-detail-freezer")
    scrollUntilHittable(element(app, "bean.best"), in: app)
    XCTAssertTrue(element(app, "bean.best").exists)
    try shot("bean-best-so-far")
  }

  @MainActor
  func testBlendBrewFreezerAndBestSoFarFlow() throws {
    let app = launch()
    try runBlendFlow(app) { _ in }
  }

  /// Writes blend, freezer and best-so-far screenshots in light, dark and the
  /// largest text size. Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureBlendScreenshots() throws {
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      try runBlendFlow(app) { name in
        try save(app.screenshot(), "\(folderURL.path)/T015-\(name)-\(variant.name).png")
      }
      app.terminate()
    }
  }

  // MARK: Explore recommendations (T017)

  /// Opens Explore with no beans, follows its next action to add one, and returns
  /// to see the bean's labelled default recommendation. `shot` is called with a
  /// name at each screen worth capturing.
  @MainActor
  private func runExploreFlow(_ app: XCUIApplication, shot: (String) throws -> Void) throws {
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Explore"].tap()
    XCTAssertTrue(element(app, "tab.root.explore").waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "explore.empty").waitForExistence(timeout: 5))
    try shot("explore-empty")

    // Explore's Add a bean opens the editor right here, not on the Beans tab.
    addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
    XCTAssertTrue(app.tabBars.buttons["Explore"].isSelected)
    let card = element(app, "explore.card.Washed Ethiopia")
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    let basis = element(app, "explore.basis.Washed Ethiopia")
    XCTAssertTrue(basis.label.hasPrefix("DEFAULT"), "cold start is labelled: \(basis.label)")
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS 'not based on your brews'")
      ).firstMatch.exists)
    try shot("explore-default")
  }

  /// Then a tap on a suggestion opens its Start brew page. Screenshots go to
  /// docs/design/explore while its `.capture` exists.
  @MainActor
  func testExploreShowsLabelledDefaultForANewBean() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/explore")
    let capture = FileManager.default.fileExists(
      atPath: folder.appendingPathComponent(".capture").path)
    func shot(_ name: String) throws {
      guard capture else { return }
      sleep(1)
      try XCUIApplication().screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("new_\(name).png"))
    }
    let app = launch()
    try runExploreFlow(app) { if $0 == "explore-default" { try shot("explore-picks") } }
    let pick = element(app, "explore.pick.Washed Ethiopia.1")
    XCTAssertTrue(pick.waitForExistence(timeout: 5))
    pick.tap()
    XCTAssertTrue(app.buttons["Start brew"].waitForExistence(timeout: 5))
    try shot("explore-pick-opens-brew")
  }

  /// Writes Explore screenshots in light, dark and the largest text size. Runs
  /// only while `ralph/screenshots/.capture` exists.
  @MainActor
  func testCaptureExploreScreenshots() throws {
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
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size = variant.size {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
      }
      app.launch()
      try runExploreFlow(app) { name in
        try save(app.screenshot(), "\(folderURL.path)/T017-\(name)-\(variant.name).png")
      }
      app.terminate()
    }
  }

  // MARK: Dial-in suggestions (T018)

  /// Logs a sour cup of a bean, reads the suggestion on the saved screen and in
  /// the journal, then starts the next brew of that bean, where the card waits.
  /// `shot` is called with a name at each screen worth capturing.
  @MainActor
  private func runDialInFlow(_ app: XCUIApplication, shot: (String) throws -> Void) throws {
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))
    addBean(app, name: "Washed Ethiopia", roaster: "Tiny Roastery", weight: "250")
    XCTAssertTrue(element(app, "beans.row.Washed Ethiopia").waitForExistence(timeout: 5))

    func startBrew(_ app: XCUIApplication) {
      app.tabBars.buttons["Journal"].tap()
      app.buttons["Log a brew"].firstMatch.tap()
      XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
      element(app, "brewform.beans.add").tap()
      app.buttons["Washed Ethiopia"].tap()
      app.buttons["Increase Dose"].tap()
      app.buttons["Increase Water"].tap()
    }

    startBrew(app)
    let grind = grindWheel(app, "brewform.grind")
    scrollUntilHittable(grind, in: app)
    grind.adjust(toPickerWheelValue: "20")
    let sour = element(app, "brewform.verdict.sour")
    scrollUntilHittable(sour, in: app)
    sour.tap()
    app.buttons["Save brew"].tap()
    XCTAssertTrue(
      element(app, "tab.root.journal").waitForExistence(timeout: 5), "a save lands on the Journal")
    try shot("dialin-saved")

    // History: the journal row names the suggestion this cup produced.
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Next: Grind: 20'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "journal row shows the suggestion")

    // The next brew of the same bean carries the card.
    app.buttons["Log a brew"].firstMatch.tap()
    XCTAssertTrue(element(app, "destination.brew.new").waitForExistence(timeout: 5))
    XCTAssertFalse(element(app, "suggestion.card").exists, "no bean yet, so no card")
    element(app, "brewform.beans.add").tap()
    app.buttons["Washed Ethiopia"].tap()
    let card = element(app, "suggestion.card")
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertTrue(element(app, "suggestion.headline").label == "Grind from 20 to 19")
    try shot("dialin-card")

    // Accepting puts the new grind in the form; Undo takes it back.
    element(app, "suggestion.accept").tap()
    XCTAssertTrue(element(app, "suggestion.undo").waitForExistence(timeout: 5))
    let nextGrind = grindWheel(app, "brewform.grind")
    scrollUntilHittable(nextGrind, in: app)
    XCTAssertEqual(nextGrind.value as? String, "19")
    try shot("dialin-accepted")
    scrollUntilHittable(element(app, "suggestion.undo"), in: app)
    element(app, "suggestion.undo").tap()
    XCTAssertTrue(element(app, "suggestion.accept").waitForExistence(timeout: 5))
    XCTAssertFalse((grindWheel(app, "brewform.grind").value as? String) == "19")

    // Dismissing keeps the form as it is and can be taken back as well.
    element(app, "suggestion.dismiss").tap()
    XCTAssertTrue(element(app, "suggestion.undo").waitForExistence(timeout: 5))
    element(app, "suggestion.undo").tap()
    XCTAssertTrue(element(app, "suggestion.accept").waitForExistence(timeout: 5))
  }

  @MainActor
  func testDialInSuggestionShowsOnTheNextBrewOfThatBean() throws {
    let app = launch()
    try runDialInFlow(app) { _ in }
  }

  @MainActor
  func testCaptureDialInLight() throws {
    try captureDialIn("light", appearance: .light, size: nil)
  }

  @MainActor
  func testCaptureDialInDark() throws {
    try captureDialIn("dark", appearance: .dark, size: nil)
  }

  @MainActor
  func testCaptureDialInLargestText() throws {
    try captureDialIn(
      "largest-text", appearance: .light, size: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  /// Writes dial-in screenshots for one appearance; one test per variant keeps each
  /// run short. Runs only while `ralph/screenshots/.capture` exists.
  @MainActor
  private func captureDialIn(
    _ variant: String, appearance: XCUIDevice.Appearance, size: String?
  ) throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    XCUIDevice.shared.appearance = appearance
    do {
      let app = XCUIApplication()
      app.launchArguments = [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
      ]
      if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
      app.launch()
      try runDialInFlow(app) { name in
        try save(app.screenshot(), "\(folderURL.path)/T018-\(name)-\(variant).png")
      }
      app.terminate()
    }
  }

  private func save(_ screenshot: XCUIScreenshot, _ path: String) throws {
    try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
  }

  // MARK: Your data (T019)

  /// Opens Settings → Your data, deletes everything, and takes it back with Undo.
  @MainActor
  private func runDataFlow(_ app: XCUIApplication, shot: (String) throws -> Void) throws {
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    openSettings(app)
    let link = element(app, "settings.data")
    // Appearance sits at the top, so Your data starts below the fold.
    scrollUntilHittable(link, in: app)
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    link.tap()
    let delete = element(app, "data.deleteAll")
    XCTAssertTrue(element(app, "data.export.json").waitForExistence(timeout: 5))
    try shot("data-screen")

    scrollUntilHittable(delete, in: app)
    delete.tap()
    XCTAssertTrue(
      element(app, "data.toast").waitForExistence(timeout: 5), app.debugDescription)
    try shot("data-deleted")
    app.buttons.matching(NSPredicate(format: "label ==[c] 'Undo'")).firstMatch.tap()
    // The message sits at the top of the list; at large text it is scrolled off.
    var swipes = 0
    while !element(app, "data.message").exists && swipes < 12 {
      app.swipeDown()
      swipes += 1
    }
    XCTAssertTrue(element(app, "data.message").exists)
    XCTAssertFalse(element(app, "data.toast").exists)
  }

  @MainActor
  func testYourDataDeleteAllCanBeUndone() throws {
    try runDataFlow(launch()) { _ in }
  }

  @MainActor
  func testCaptureDataLight() throws { try captureData("light", appearance: .light, size: nil) }

  @MainActor
  func testCaptureDataDark() throws { try captureData("dark", appearance: .dark, size: nil) }

  @MainActor
  func testCaptureDataLargestText() throws {
    try captureData(
      "largest-text", appearance: .light, size: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  @MainActor
  private func captureData(
    _ variant: String, appearance: XCUIDevice.Appearance, size: String?
  ) throws {
    let folderURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("ralph/screenshots")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    defer { XCUIDevice.shared.appearance = .light }
    XCUIDevice.shared.appearance = appearance
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
    ]
    if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
    app.launch()
    try runDataFlow(app) { name in
      try save(app.screenshot(), "\(folderURL.path)/T019-\(name)-\(variant).png")
    }
    app.terminate()
  }

  @MainActor
  func testSelectedTabRestoresAfterRelaunch() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 5))

    app.terminate()
    // Relaunch without the reset flag, as the user would.
    app.launchArguments = ["-inMemoryStore", "-appStyle", "steelKraft"]
    app.launch()

    XCTAssertTrue(element(app, "tab.root.beans").waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Beans"].isSelected)
  }

  // MARK: Paper import (T025)

  /// Saves review-screen screenshots to `ralph/screenshots` when `.capture` exists there.
  @MainActor
  func testPaperImportScreenshots() throws {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("ralph/screenshots")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "create ralph/screenshots/.capture to save screenshots")
    let directory = folder.path
    let variants: [(name: String, arguments: [String])] = [
      ("light", []),
      ("dark", ["-AppleInterfaceStyle", "Dark"]),
      (
        "largest-text",
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
      ),
    ]
    for variant in variants {
      let app = XCUIApplication()
      app.launchArguments =
        ["-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft"]
        + variant.arguments
      app.launch()
      element(app, "journal.import").tap()
      element(app, "import.sample").tap()
      try shoot(app, "\(directory)/T025-choose-\(variant.name).png")
      let read = element(app, "import.read.device")
      scrollUntilHittable(read, in: app)
      read.tap()
      XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 30))
      try shoot(app, "\(directory)/T025-review-\(variant.name).png")
      app.swipeUp()
      try shoot(app, "\(directory)/T025-review-lower-\(variant.name).png")
      app.terminate()
    }
  }

  private func shoot(_ app: XCUIApplication, _ path: String) throws {
    try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
  }

  @MainActor
  func testPaperImportCannotSaveUntilConfirmed() {
    let app = launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    element(app, "journal.import").tap()
    XCTAssertTrue(element(app, "import.sheet").waitForExistence(timeout: 5))

    element(app, "import.sample").tap()
    let read = element(app, "import.read.device")
    XCTAssertTrue(read.waitForExistence(timeout: 5))
    read.tap()

    XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 30), "page was not read")
    let save = element(app, "import.save")
    XCTAssertFalse(save.isEnabled, "Save must stay off until the page is confirmed")
    let dose = element(app, "import.dose")
    var swipes = 0
    while !dose.exists && swipes < 6 {
      app.swipeUp()
      swipes += 1
    }
    XCTAssertEqual(dose.value as? String, "18")

    // Editing a field after confirming asks for the confirmation again.
    let confirm = element(app, "import.confirm")
    scrollUntilHittable(confirm, in: app)
    // The switch sits at the trailing edge of its row.
    func flip() { confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
    flip()
    XCTAssertTrue(save.waitForExistence(timeout: 2) && save.isEnabled, "confirming enables Save")
    flip()
    XCTAssertFalse(save.isEnabled)
    flip()
    save.tap()

    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 5))
    let row = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] 'Sample Blend'")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "the imported brew is in the journal")
  }

  // MARK: Roaster discovery (T027)

  private func openRoasters(location: String, extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      [
        "-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft",
        "-roasterStub", "-locationStub",
        location,
      ] + extraArguments
    app.launch()
    XCTAssertTrue(element(app, "tab.root.journal").waitForExistence(timeout: 10))
    app.tabBars.buttons["Explore"].tap()
    let open = app.buttons["explore.roasters"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()
    XCTAssertTrue(element(app, "roasters.screen").waitForExistence(timeout: 5))
    return app
  }

  @MainActor
  func testDeniedLocationFallsBackToATypedCityAndOnlySavedRoastersStay() {
    let app = openRoasters(location: "denied")
    app.buttons["roasters.locate"].tap()
    XCTAssertTrue(
      element(app, "roasters.locationNotice").waitForExistence(timeout: 5),
      "denied location says so and offers the typed city")

    let city = app.textFields["roasters.city"]
    city.tap()
    city.typeText("Sampletown")
    app.buttons["roasters.search"].tap()
    let first = app.buttons["roasters.toggle.Sample Roasters One"]
    XCTAssertTrue(first.waitForExistence(timeout: 5), "typed city returns results")
    XCTAssertTrue(element(app, "roasters.savedEmpty").exists, "searching saves nothing")

    first.tap()
    XCTAssertTrue(
      element(app, "roasters.saved.Sample Roasters One").waitForExistence(timeout: 5),
      "a saved roaster is listed under Saved")
    XCTAssertFalse(
      element(app, "roasters.saved.Sample Roasters Two").exists, "unsaved results are not kept")
  }

  @MainActor
  func testRoasterSearchShowsEmptyAndErrorStatesWithARetry() {
    let app = openRoasters(location: "granted")
    let city = app.textFields["roasters.city"]
    city.tap()
    city.typeText("Nowhere")
    app.buttons["roasters.search"].tap()
    XCTAssertTrue(element(app, "roasters.empty").waitForExistence(timeout: 5))

    city.tap()
    city.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Nowhere".count))
    city.typeText("Offline")
    app.buttons["roasters.search"].tap()
    XCTAssertTrue(element(app, "roasters.failed").waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label ==[c] 'Retry'")).firstMatch.exists)
  }

  // MARK: Screenshot capture for T027 and T028 (only runs when ralph/screenshots/.capture exists)

  @MainActor
  func testCaptureRoasterAndFlavorScreenshots() throws {
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
      let sizeArguments =
        variant.size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? []

      // S10: results, saved roaster, then the denied-location notice.
      let app = openRoasters(location: "granted", extraArguments: sizeArguments)
      let city = app.textFields["roasters.city"]
      city.tap()
      city.typeText("Sampletown")
      app.buttons["roasters.search"].tap()
      let first = app.buttons["roasters.toggle.Sample Roasters One"]
      XCTAssertTrue(first.waitForExistence(timeout: 5))
      first.tap()
      // At the largest text the Saved list can sit below the fold; the functional tests cover it.
      if variant.size == nil {
        XCTAssertTrue(
          element(app, "roasters.saved.Sample Roasters One").waitForExistence(timeout: 5))
      }
      try save(app.screenshot(), "\(folderURL.path)/T027-results-\(variant.name).png")
      app.terminate()

      let denied = openRoasters(location: "denied", extraArguments: sizeArguments)
      denied.buttons["roasters.locate"].tap()
      XCTAssertTrue(element(denied, "roasters.locationNotice").waitForExistence(timeout: 5))
      try save(denied.screenshot(), "\(folderURL.path)/T027-denied-\(variant.name).png")
      denied.terminate()

      // S-flavor: the list and one bucket's detail.
      let flavor = XCUIApplication()
      flavor.launchArguments =
        ["-inMemoryStore", "-appStyle", "steelKraft", "-resetNavigationState", "-resetDraft"]
        + sizeArguments
      flavor.launch()
      flavor.tabBars.buttons["Explore"].tap()
      let entry = element(flavor, "explore.flavors")
      XCTAssertTrue(entry.waitForExistence(timeout: 10))
      entry.tap()
      XCTAssertTrue(element(flavor, "flavor.list").waitForExistence(timeout: 10))
      try save(flavor.screenshot(), "\(folderURL.path)/T028-list-\(variant.name).png")
      let citrus = element(flavor, "flavor.bucket.flavor.citrus")
      scrollUntilHittable(citrus, in: flavor)
      citrus.tap()
      XCTAssertTrue(element(flavor, "flavor.detail.flavor.citrus").waitForExistence(timeout: 10))
      try save(flavor.screenshot(), "\(folderURL.path)/T028-detail-\(variant.name).png")
      flavor.terminate()
    }
  }
}
