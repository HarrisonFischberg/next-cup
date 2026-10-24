import Foundation

/// Which brew form fields a method switches on. Dose and water are always
/// shown: a brew cannot be saved without them. Yield is kept on a method
/// untouched, but the form has no field for it yet, so the editor does not offer it.
enum MethodParameters {
  /// Needed to save any brew, so a method cannot turn them off.
  static let required: [BrewParameter] = [.dose, .water]

  /// The optional fields the brew form can show today, in form order.
  static let optional: [BrewParameter] = [
    .temperature, .time, .grind, .tds, .rating, .notes, .photo,
  ]

  /// The fields the form shows for a method that tracks these parameters.
  static func shown(tracked: [BrewParameter]) -> Set<BrewParameter> {
    Set(tracked).union(required)
  }

  static func title(_ parameter: BrewParameter) -> String {
    switch parameter {
    case .dose: "Dose"
    case .water: "Water"
    case .yield: "Yield"
    case .grind: "Grind setting"
    case .temperature: "Temperature"
    case .time: "Brew time"
    case .tds: "TDS"
    case .rating: "Grade"
    case .notes: "Notes"
    case .photo: "Photo"
    }
  }

  /// A new tracked list: the chosen optional fields plus whatever the editor
  /// does not offer (yield) and the required pair, in a stable order.
  static func merged(existing: [BrewParameter], chosen: Set<BrewParameter>) -> [BrewParameter] {
    let kept = Set(existing).subtracting(optional)
    let result = kept.union(chosen).union(required)
    return BrewParameter.allCases.filter { result.contains($0) }
  }
}

extension BrewStyle {
  var title: String {
    switch self {
    case .pourOver: "Pour over"
    case .immersion: "Immersion"
    case .espresso: "Espresso"
    case .cold: "Cold"
    }
  }
}
