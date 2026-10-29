import XCTest

/// A bean added from a bag photo keeps the photo: it shows in the editor and on the bean.
/// Runs only while `docs/design/bag-photo/.capture` exists and the simulator's library has a
/// bag photo (`simctl addmedia`); files are named with CAPTURE_PREFIX (old_ or new_).
final class BagPhotoCaptureUITests: XCTestCase {
  @MainActor
  func testCaptureBagPhotoOnBean() throws {
    let folder = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/design/bag-photo")
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: folder.appendingPathComponent(".capture").path),
      "screenshot capture is off")
    let prefix = ProcessInfo.processInfo.environment["CAPTURE_PREFIX"] ?? "new_"
    let app = XCUIApplication()
    app.launchArguments = [
      "-inMemoryStore", "-resetNavigationState", "-resetDraft", "-appStyle", "sundayStudio",
      "-demoBeans",
    ]
    app.launch()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    func shot(_ name: String) throws {
      sleep(1)
      try app.screenshot().pngRepresentation.write(
        to: folder.appendingPathComponent("\(prefix)\(name).png"))
    }

    app.tabBars.buttons["Beans"].tap()
    XCTAssertTrue(element("beans.add").waitForExistence(timeout: 10))
    element("beans.add").tap()
    XCTAssertTrue(element("beans.editor.scan").waitForExistence(timeout: 5))
    element("beans.editor.scan").coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
    let library = app.descendants(matching: .any)["Choose from library"].firstMatch
    XCTAssertTrue(library.waitForExistence(timeout: 5), app.debugDescription)
    library.tap()
    // The system photo picker runs out of process, so its newest photo (the bag, first in
    // the grid under the Private Access card) is tapped by position.
    sleep(3)
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 66, dy: 378)).tap()

    let kept = element("beans.editor.photo")
    var tries = 0
    while !kept.waitForExistence(timeout: 5) && tries < 4 {
      app.swipeUp()
      tries += 1
    }
    XCTAssertTrue(kept.exists, "the bag photo was not kept in the editor")
    let name = element("beans.editor.name")
    tries = 0
    while !name.isHittable && tries < 6 {
      app.swipeDown()
      tries += 1
    }
    name.tap()
    name.typeText("Ethiopia Guji")
    app.buttons["Done"].firstMatch.tap()
    tries = 0
    while !kept.isHittable && tries < 6 {
      app.swipeUp()
      tries += 1
    }
    try shot("editor-bag-photo")
    element("beans.editor.save").tap()

    let row = element("beans.row.Ethiopia Guji")
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    let onBean = element("bean.photo")
    tries = 0
    while !onBean.isHittable && tries < 6 {
      app.swipeUp()
      tries += 1
    }
    XCTAssertTrue(onBean.exists, "the bag photo is not on the bean")
    try shot("bean-detail-bag-photo")
  }
}
