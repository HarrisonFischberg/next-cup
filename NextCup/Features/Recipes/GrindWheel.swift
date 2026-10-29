import NextCupKit
import SwiftUI

/// The grind setting as a wheel, styled like "How much coffee?": the grinder's own
/// notation from the guide, or 0–40 by halves for a grinder the guide does not know.
/// "—" means no grind noted; a saved setting off the wheel is kept as its own stop.
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
    let selection = Binding(
      get: { GrinderGuide.setting(setting, in: stops) ?? "" },
      set: { setting = $0 })
    HStack(spacing: DS.Space.sm) {
      Picker("Grind setting", selection: selection) {
        ForEach(stops, id: \.self) { Text($0.isEmpty ? "—" : $0) }
      }
      .pickerStyle(.wheel).font(DS.Font.dataLarge).foregroundStyle(DS.ink)
      .frame(height: 120).clipped()
      .accessibilityIdentifier(identifier)
      if let unit {
        Text(unit).font(DS.Font.dataLarge).foregroundStyle(DS.ink2)
          .frame(minWidth: 64, alignment: .leading)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, DS.Space.sm)
    .sensoryFeedback(.selection, trigger: setting)
  }
}
