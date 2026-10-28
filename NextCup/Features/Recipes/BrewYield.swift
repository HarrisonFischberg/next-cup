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
}
