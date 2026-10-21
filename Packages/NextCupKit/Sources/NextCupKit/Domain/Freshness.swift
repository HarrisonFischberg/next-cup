import Foundation

/// A span the bag spent in the freezer. `thawedOn == nil` means it is still frozen.
public struct FrozenSpan: Equatable, Sendable {
  public var frozenOn: Date
  public var thawedOn: Date?

  public init(frozenOn: Date, thawedOn: Date? = nil) {
    self.frozenOn = frozenOn
    self.thawedOn = thawedOn
  }
}

public enum FreshnessState: Equatable, Sendable {
  case unknown
  case resting
  case peak
  case pastPeak
  case frozen
}

public struct FreshnessWindows: Equatable, Sendable {
  /// Days after roast the beans are still resting (before this age).
  public var restingDays: Int
  /// Last day (inclusive) counted as peak.
  public var peakEndDay: Int

  public init(restingDays: Int = 5, peakEndDay: Int = 30) {
    self.restingDays = restingDays
    self.peakEndDay = peakEndDay
  }
}

public enum Freshness {
  /// Calendar days since roast in `calendar`'s zone, with frozen days left out.
  /// `nil` without a roast date or when the roast date is in the future.
  public static func ageDays(
    roastDate: Date?, frozenSpans: [FrozenSpan] = [], today: Date,
    calendar: Calendar = .current
  ) -> Int? {
    guard let roastDate else { return nil }
    let start = calendar.startOfDay(for: roastDate)
    let end = calendar.startOfDay(for: today)
    guard end >= start else { return nil }

    var frozenDays = 0
    for span in frozenSpans {
      let spanStart = max(calendar.startOfDay(for: span.frozenOn), start)
      let spanEnd = min(span.thawedOn.map { calendar.startOfDay(for: $0) } ?? end, end)
      if spanEnd > spanStart {
        frozenDays += calendar.dateComponents([.day], from: spanStart, to: spanEnd).day ?? 0
      }
    }
    let total = calendar.dateComponents([.day], from: start, to: end).day ?? 0
    return max(total - frozenDays, 0)
  }

  public static func state(
    roastDate: Date?, frozenSpans: [FrozenSpan] = [], today: Date,
    windows: FreshnessWindows = FreshnessWindows(), calendar: Calendar = .current
  ) -> FreshnessState {
    guard roastDate != nil else { return .unknown }
    let isFrozenNow = frozenSpans.contains {
      $0.thawedOn == nil && calendar.startOfDay(for: $0.frozenOn) <= calendar.startOfDay(for: today)
    }
    if isFrozenNow { return .frozen }
    guard
      let age = ageDays(
        roastDate: roastDate, frozenSpans: frozenSpans, today: today, calendar: calendar)
    else { return .unknown }
    if age < windows.restingDays { return .resting }
    if age <= windows.peakEndDay { return .peak }
    return .pastPeak
  }
}
