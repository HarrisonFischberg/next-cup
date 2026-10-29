import Foundation
import NextCupKit
import SwiftData

/// After a bean is added, Apple's on-device model suggests what it knows of the coffee:
/// origin, process, roast level and tasting notes. None of it is on the bag, so it is kept
/// as a suggestion (`Bean.aiSuggestion`) that the bean screen shows for Accept or Dismiss;
/// only an accepted suggestion fills blank fields. Nothing leaves the iPhone.
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

  /// Asks for suggestions in the background; a failure leaves the bean as it was.
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
        suggest(answer, for: bean)
      }
      try? context.save()
    }
  }

  /// Keeps the answer's non-empty values for fields that are still blank, for review.
  static func suggest(_ answer: [String: Any], for bean: Bean) {
    let open = suggestions(answer, for: bean)
    bean.aiSuggestion = open.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: open)
  }

  /// The pending suggestion, limited to fields that are still blank, as label/value rows.
  static func pending(for bean: Bean) -> [(label: String, value: String)] {
    guard let data = bean.aiSuggestion,
      let answer = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [] }
    let open = suggestions(answer, for: bean)
    return [
      ("Country", "originCountry"), ("Process", "process"), ("Roast", "roastLevel"),
      ("Flavor notes", "flavorNotes"),
    ].compactMap { label, key in
      open[key].map { (label, key == "roastLevel" ? RoastLevel(rawValue: $0)?.title ?? $0 : $0) }
    }
  }

  static func accept(_ bean: Bean) {
    if let data = bean.aiSuggestion,
      let answer = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      apply(answer, to: bean)
    }
    bean.aiSuggestion = nil
  }

  static func dismiss(_ bean: Bean) {
    bean.aiSuggestion = nil
    bean.updatedAt = Date()
  }

  private static func suggestions(_ answer: [String: Any], for bean: Bean) -> [String: String] {
    func text(_ key: String) -> String {
      (answer[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    var open: [String: String] = [:]
    if (bean.originCountry ?? "").isEmpty { open["originCountry"] = text("originCountry") }
    if (bean.process ?? "").isEmpty { open["process"] = text("process") }
    if bean.roastLevel == nil, RoastLevel(rawValue: text("roastLevel")) != nil {
      open["roastLevel"] = text("roastLevel")
    }
    if bean.bagFlavorNotes.isEmpty { open["flavorNotes"] = text("flavorNotes") }
    return open.filter { !$0.value.isEmpty }
  }

  /// Writes the answer into blank fields only (what Accept does).
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
