import XCTest

extension XCUIApplication {
  /// Taps a `DialStepper`'s − or + until its number reads `target`; "—" counts as below all.
  func step(_ id: String, to target: Double, file: StaticString = #filePath, line: UInt = #line) {
    let stepper = descendants(matching: .any)[id].firstMatch
    func current() -> Double {
      Double((stepper.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }
    // Out from under the bottom bar first: a tap there would land on the bar.
    for _ in 0..<6 where stepper.frame.maxY > frame.height * 0.7 {
      coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
        .press(
          forDuration: 0.05,
          thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
    }
    for _ in 0..<100 where current() != target {
      buttons["\(id).\(current() < target ? "increase" : "decrease")"].tap()
    }
    XCTAssertEqual(current(), target, file: file, line: line)
  }
}
