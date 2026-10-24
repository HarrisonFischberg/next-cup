import Foundation
import NextCupKit

/// Reads a bag or coffee photo into a bean draft (T024). The result only ever fills
/// `BeanFields` for the bean editor to review: nothing here inserts a `Bean`, and
/// an answer that does not match the schema is discarded.
enum BagRecognition {
  static let features: [AIFeature] = [.bagRecognition, .photoInterpretation]

  static let schema = JSONSchema.object([
    "name": .string(),
    "roaster": .string(),
    "originCountry": .string(),
    "region": .string(),
    "farm": .string(),
    "process": .string(),
    "varietal": .string(),
    "roastLevel": .string(allowed: [""] + RoastLevel.allCases.map(\.rawValue)),
    "roastDate": .string(),
    "bagWeightGrams": .number,
    "flavorNotes": .string(),
    "isDecaf": .boolean,
  ])

  private static let schemaName = "bean_draft"

  private static let system = """
    You read coffee bag labels. Fill only what is printed or clearly visible in the photo. \
    Use an empty string for text you cannot read, 0 for a weight you cannot read, and false for \
    decaf unless the photo says so. roastDate is YYYY-MM-DD or empty. flavorNotes are the tasting \
    notes on the bag, separated by commas. Never guess.
    """

  /// `photo` must already be sanitized (no metadata); the queue sends it as-is.
  static func payload(photo: Data, feature: AIFeature) -> AIRequestPayload {
    AIRequestPayload(
      system: system,
      userText: feature == .bagRecognition
        ? "Read the label on this bag of coffee."
        : "Describe the coffee in this photo as a bean entry.",
      schemaName: schemaName, schema: schema, imageJPEG: photo)
  }

  /// The draft for a finished request. Blank answers stay blank.
  static func draft(from request: AIRequest) -> Result<BeanFields, AIError> {
    guard features.contains(request.feature), request.status == .done,
      let data = request.resultJSON,
      let object = try? JSONSerialization.jsonObject(with: data), schema.validates(object),
      let answer = object as? [String: Any]
    else { return .failure(.invalidResponse) }

    func text(_ key: String) -> String {
      (answer[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    var fields = BeanFields()
    fields.name = text("name")
    fields.roasterName = text("roaster")
    fields.originCountry = text("originCountry")
    fields.region = text("region")
    fields.farm = text("farm")
    fields.process = text("process")
    fields.varietal = text("varietal")
    fields.roastLevel = RoastLevel(rawValue: text("roastLevel"))
    fields.roastDate = date(text("roastDate"))
    fields.flavorNotes = text("flavorNotes")
    fields.bagWeightG = (answer["bagWeightGrams"] as? Double).flatMap { $0 > 0 ? $0 : nil }
    fields.isDecaf = answer["isDecaf"] as? Bool ?? false
    return .success(fields)
  }

  /// Puts the draft into `fields` without touching anything already typed.
  static func fill(_ fields: inout BeanFields, with draft: BeanFields) {
    func keep(_ current: inout String, _ new: String) { if current.isEmpty { current = new } }
    keep(&fields.name, draft.name)
    keep(&fields.roasterName, draft.roasterName)
    keep(&fields.originCountry, draft.originCountry)
    keep(&fields.region, draft.region)
    keep(&fields.farm, draft.farm)
    keep(&fields.process, draft.process)
    keep(&fields.varietal, draft.varietal)
    keep(&fields.flavorNotes, draft.flavorNotes)
    fields.roastLevel = fields.roastLevel ?? draft.roastLevel
    fields.roastDate = fields.roastDate ?? draft.roastDate
    fields.bagWeightG = fields.bagWeightG ?? draft.bagWeightG
    fields.isDecaf = fields.isDecaf || draft.isDecaf
  }

  /// A printed date in the past; anything unparseable or in the future is dropped
  /// because the editor's roast-date picker only allows days up to today.
  private static func date(_ text: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: text).flatMap { $0 <= Date() ? $0 : nil }
  }
}
