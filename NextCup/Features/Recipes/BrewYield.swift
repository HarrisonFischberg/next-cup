import Foundation

/// The units "How much coffee?" takes. A cup is the US cup, 8 fl oz.
enum BrewYield: String, CaseIterable {
  case oz, cups, ml

  static let unitKey = "brew.yieldUnit"
  static var defaultUnit: BrewYield { Locale.current.measurementSystem == .us ? .oz : .ml }

  var title: String {
    switch self {
    case .oz: "oz"
    case .cups: "cups"
    case .ml: "ml"
    }
  }

  var millilitres: Double {
    switch self {
    case .oz: 29.5735
    case .cups: 236.588
    case .ml: 1
    }
  }

  /// The amounts its wheel offers: oz by the ounce, cups by the half, ml by 50.
  var options: [Double] {
    switch self {
    case .oz: Array(stride(from: 4, through: 32, by: 1))
    case .cups: Array(stride(from: 0.5, through: 4, by: 0.5))
    case .ml: Array(stride(from: 100, through: 1_000, by: 50))
    }
  }

  /// The wheel's amount nearest to `ml`, for keeping the amount when the unit changes.
  func nearest(toMillilitres ml: Double) -> Double? {
    options.min { abs($0 * millilitres - ml) < abs($1 * millilitres - ml) }
  }
}
