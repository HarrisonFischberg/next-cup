import XCTest

extension XCUIApplication {
  /// Taps a `DialStepper`'s − or + until its number reads `target`; "—" counts as below all.
  func step(_ id: String, to target: Double, file: StaticString = #filePath, line: UInt = #line) {
    let stepper = descendants(matching: .any)[id].firstMatch
    func current() -> Double {
      Double((stepper.value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }
    // Out from under the bars first: a tap there would land on the bar. Slow, held drags,
    // so the page does not fling the stepper past the other bar.
    func drag(from: CGFloat, to: CGFloat) {
      coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: from))
        .press(
          forDuration: 0.05,
          thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: to)),
          withVelocity: .slow, thenHoldForDuration: 0.2)
    }
    for _ in 0..<6 where stepper.frame.maxY > frame.height * 0.7 { drag(from: 0.7, to: 0.5) }
    for _ in 0..<6 where stepper.frame.minY < frame.height * 0.2 { drag(from: 0.4, to: 0.6) }
    for _ in 0..<100 where current() != target {
      buttons["\(id).\(current() < target ? "increase" : "decrease")"].tap()
    }
    XCTAssertEqual(current(), target, file: file, line: line)
  }
}
