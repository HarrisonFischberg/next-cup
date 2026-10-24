import Foundation
import NextCupKit

enum BeanStatusFilter: String, CaseIterable, Identifiable {
  case all, inUse, buyAgain, wishlist, finished

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: "All"
    case .inUse: "In use"
    case .buyAgain: "Buy again"
    case .wishlist: "Wishlist"
    case .finished: "Finished"
    }
  }

  var status: BeanStatus? {
    switch self {
    case .all: nil
    case .inUse: .inUse
    case .buyAgain: .buyAgain
    case .wishlist: .wishlist
    case .finished: .finished
    }
  }
}

enum BeanSort: String, CaseIterable, Identifiable {
  case recent, name, roastDate, grade

  var id: String { rawValue }

  var title: String {
    switch self {
    case .recent: "Recently added"
    case .name: "Name"
    case .roastDate: "Roast date"
    case .grade: "Highest grade"
    }
  }
}

/// What the bean library shows: search text, a status and an order. Pure over
/// `Bean` rows so the rules test without a view.
struct BeanFilter: Equatable {
  var search = ""
  var status = BeanStatusFilter.all
  var sort = BeanSort.recent

  private var term: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// True when something narrows the list, so "no results" can offer a way out.
  var isNarrowing: Bool { status != .all || !term.isEmpty }

  func apply(to beans: [Bean]) -> [Bean] {
    let kept = beans.filter(matches)
    switch sort {
    case .recent:
      return kept.sorted { $0.createdAt > $1.createdAt }
    case .name:
      return kept.sorted {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
    case .roastDate:
      // Newest roast first; a bean with no roast date goes last.
      return kept.sorted {
        switch ($0.roastDate, $1.roastDate) {
        case (let a?, let b?): a > b
        case (_?, nil): true
        case (nil, _?): false
        case (nil, nil): $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
      }
    case .grade:
      return kept.sorted {
        let (a, b) = ($0.ratingHalfSteps ?? 0, $1.ratingHalfSteps ?? 0)
        return a == b ? $0.createdAt > $1.createdAt : a > b
      }
    }
  }

  private func matches(_ bean: Bean) -> Bool {
    if let wanted = status.status, bean.status != wanted { return false }
    guard !term.isEmpty else { return true }
    let fields: [String?] =
      [
        bean.name, bean.roaster?.name, bean.originCountry, bean.region, bean.farm, bean.process,
        bean.varietal,
      ] + bean.bagFlavorNotes
    return fields.contains { $0?.localizedStandardContains(term) == true }
  }
}

// MARK: Display

extension RoastLevel {
  var title: String {
    switch self {
    case .ultraLight: "Ultra light"
    case .light: "Light"
    case .mediumLight: "Medium light"
    case .medium: "Medium"
    case .mediumDark: "Medium dark"
    case .dark: "Dark"
    }
  }
}

extension BeanStatus {
  var title: String {
    switch self {
    case .inUse: "In use"
    case .buyAgain: "Buy again"
    case .wishlist: "Wishlist"
    case .finished: "Finished"
    }
  }
}

extension FreshnessState {
  var title: String {
    switch self {
    case .unknown: "No roast date"
    case .resting: "Resting"
    case .peak: "Peak"
    case .pastPeak: "Past peak"
    case .frozen: "Frozen"
    }
  }
}

extension Bean {
  /// Grams each brew took from this bag.
  var usedG: [Double] { (brewUses ?? []).map(\.grams) }

  var remainingG: Double? {
    BeanStock.remainingG(
      bagWeightG: bagWeightG, usedG: usedG, adjustmentG: remainingAdjustmentG)
  }

  var stockLevel: StockLevel {
    BeanStock.level(remainingG: remainingG, bagWeightG: bagWeightG)
  }

  /// The time in the freezer, if any, so frozen days do not age the beans.
  var frozenSpans: [FrozenSpan] {
    guard let frozenOn else { return [] }
    return [FrozenSpan(frozenOn: frozenOn, thawedOn: thawedOn)]
  }

  func freshness(today: Date = Date(), calendar: Calendar = .current) -> FreshnessState {
    Freshness.state(
      roastDate: roastDate, frozenSpans: frozenSpans, today: today, calendar: calendar)
  }

  func ageDays(today: Date = Date(), calendar: Calendar = .current) -> Int? {
    Freshness.ageDays(
      roastDate: roastDate, frozenSpans: frozenSpans, today: today, calendar: calendar)
  }

  /// "Roaster · Ethiopia" for rows and headings.
  var subtitle: String {
    [roaster?.name, originCountry].compactMap { $0 }.filter { !$0.isEmpty }.joined(
      separator: "  ·  ")
  }
}
