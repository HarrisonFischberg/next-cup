import NextCupKit
import SwiftUI

/// The grind setting as a − / + stepper with a hold-for-dial, so a scroll cannot turn it:
/// the grinder's own notation from the guide, or 0–40 by halves for a grinder the guide
/// does not know. "—" means no grind noted; a saved setting off the guide is kept as its
/// own stop.
struct GrindWheel: View {
  @Binding var setting: String
  let grinderName: String?
  let identifier: String

  private var guide: GrinderGuide? { GrinderGuide.find(grinderName) }

  private var stops: [String] {
    let stops = guide?.settings ?? GrinderGuide.otherSettings
    let typed = setting.trimmingCharacters(in: .whitespaces)
    let offWheel = !typed.isEmpty && GrinderGuide.setting(typed, in: stops) == nil
    return [""] + (offWheel ? [typed] : []) + stops
  }

  private var unit: String? {
    switch guide?.notation {
    case "clicks": "clicks"
    case "rotations": "turns"
    default: nil
    }
  }

  var body: some View {
    let stops = stops
    DialStepper(
      title: "Grind setting", options: stops,
      selection: Binding(
        get: { GrinderGuide.setting(setting, in: stops) ?? "" },
        set: { setting = $0 }),
      unit: unit, identifier: identifier)
  }
}
