import Foundation
import NextCupKit
import SwiftData

/// After a bean is added, Apple's on-device model fills in what it knows of the coffee:
/// origin, process, roast level and tasting notes. Only blank fields are filled, the model
/// is told to leave anything it is unsure of empty, and nothing leaves the iPhone. It does
/// not search the web; set-up says these come from Apple AI so they get checked.
@MainActor
enum BeanDetailsAI {
  static let enabledKey = "ai.fillBeanDetails"

  static var isOn: Bool {
    AppleIntelligence.isAvailable
      && (UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true)
  }

  static let schema = JSONSchema.object([
    "originCountry": .string(),
    "process": .string(),
    "roastLevel": .string(allowed: [""] + RoastLevel.allCases.map(\.rawValue)),
    "flavorNotes": .string(),
  ])

  private static let system = """
    You know retail and specialty coffees. Given a coffee's name and roaster, give its origin \
    country (or "Blend"), process (washed, natural, honey…), roast level and the roaster's \
    tasting notes separated by commas. Use an empty string for anything you are not sure of. \
    Never guess.
    """

  /// Fills blanks on each bean in the background; a failure leaves the bean as it was.
  static func fill(_ beans: [Bean], in context: ModelContext) {
    guard isOn else { return }
    let targets = beans.filter {
      ($0.originCountry ?? "").isEmpty || ($0.process ?? "").isEmpty || $0.roastLevel == nil
    }
    guard !targets.isEmpty else { return }
    Task {
      for bean in targets {
        let payload = AIRequestPayload(
          system: system,
          userText: "Coffee: \(bean.name)\nRoaster: \(bean.roaster?.name ?? "unknown")",
          schemaName: "bean_details", schema: schema, imageJPEG: nil)
        guard let result = try? await AppleIntelligence.send(payload),
          let answer = try? JSONSerialization.jsonObject(with: result.json) as? [String: Any]
        else { continue }
        apply(answer, to: bean)
      }
      try? context.save()
    }
  }

  /// Writes the answer into blank fields only.
  static func apply(_ answer: [String: Any], to bean: Bean) {
    func text(_ key: String) -> String {
      (answer[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    if (bean.originCountry ?? "").isEmpty, !text("originCountry").isEmpty {
      bean.originCountry = text("originCountry")
    }
    if (bean.process ?? "").isEmpty, !text("process").isEmpty { bean.process = text("process") }
    if bean.roastLevel == nil { bean.roastLevel = RoastLevel(rawValue: text("roastLevel")) }
    if bean.bagFlavorNotes.isEmpty {
      bean.bagFlavorNotes = BeanFields.notes(from: text("flavorNotes"))
    }
    bean.updatedAt = Date()
  }
}
