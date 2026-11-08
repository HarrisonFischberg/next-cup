import Foundation

/// One line of text read from a photographed journal page, with how sure the
/// reader was of it (0 to 1).
public struct PaperLine: Equatable, Sendable {
  public var text: String
  public var confidence: Double
  /// The line's height as a fraction of the image height; 0 when unknown.
  public var height: Double

  public init(text: String, confidence: Double, height: Double = 0) {
    self.text = text
    self.confidence = confidence
    self.height = height
  }
}

public enum PaperField: String, CaseIterable, Sendable {
  case method, bean, dose, water, temperature, time, grind, rating, notes
}

/// What a journal page was read as. Weights are grams, temperature °C, time
/// seconds (blueprint §2). A field that was not found stays blank and has no
/// confidence entry; one that was found is flagged when the reader was unsure.
public struct PaperBrewDraft: Equatable, Sendable {
  /// Fields read with less confidence than this are highlighted in the review.
  public static let lowConfidence = 0.6

  public var method = ""
  public var bean = ""
  public var grind = ""
  public var notes = ""
  public var doseG: Double?
  public var waterG: Double?
  public var tempC: Double?
  public var totalTimeS: Int?
  public var ratingTenths: Int?
  public var confidence: [PaperField: Double] = [:]

  public init() {}

  public func needsCheck(_ field: PaperField) -> Bool {
    (confidence[field] ?? 1) < Self.lowConfidence
  }

  public var needsCheckCount: Int { PaperField.allCases.filter(needsCheck).count }

  public var isEmpty: Bool { confidence.isEmpty }
}

/// Reads journal-page text into a `PaperBrewDraft` (blueprint §3a). Pure text
/// rules, so the same code serves on-device recognition and the AI answer.
///
/// shortcut: one brew per page, found by its label ("Dose 18 g"); a line with no
/// known label goes to the notes. Upgrade to table or multi-entry pages when real
/// pages need it.
public enum PaperImport {
  private static let labels: [(PaperField, [String])] = [
    (.method, ["method", "brewer"]),
    (.dose, ["dose", "coffee", "grounds"]),
    (.bean, ["beans", "bean", "coffee"]),
    (.water, ["water"]),
    (.temperature, ["temperature", "temp"]),
    (.time, ["time"]),
    (.grind, ["grind"]),
    (.rating, ["rating", "score", "stars"]),
    (.notes, ["tasting notes", "tasting", "notes", "note", "taste"]),
  ]

  public static func parse(_ lines: [PaperLine]) -> PaperBrewDraft {
    var draft = PaperBrewDraft()
    var leftovers: [PaperLine] = []
    for line in lines {
      let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { continue }
      if !read(text, confidence: line.confidence, into: &draft) {
        leftovers.append(PaperLine(text: text, confidence: line.confidence))
      }
    }
    if !leftovers.isEmpty {
      let joined = ([draft.notes] + leftovers.map(\.text)).filter { !$0.isEmpty }
      draft.notes = joined.joined(separator: "\n")
      let sure = leftovers.map(\.confidence) + [draft.confidence[.notes]].compactMap { $0 }
      draft.confidence[.notes] = sure.min()
    }
    return draft
  }

  private static func read(
    _ text: String, confidence: Double, into draft: inout PaperBrewDraft
  ) -> Bool {
    let lower = text.lowercased()
    for (field, names) in labels {
      for name in names where lower.hasPrefix(name) {
        if let after = lower.dropFirst(name.count).first, after.isLetter { continue }
        let value = String(text.dropFirst(name.count))
          .trimmingCharacters(in: CharacterSet(charactersIn: ":=-–— \t"))
        if set(field, from: value, confidence: confidence, in: &draft) { return true }
      }
    }
    return false
  }

  private static func set(
    _ field: PaperField, from value: String, confidence: Double, in draft: inout PaperBrewDraft
  ) -> Bool {
    guard let first = value.first else { return false }
    // "Water temp 94" is not a water amount: a measurement starts with its number.
    let measured: [PaperField] = [.dose, .water, .temperature, .time, .rating]
    if measured.contains(field), !first.isNumber, first != "★" { return false }
    switch field {
    case .method: draft.method = value
    case .bean:
      guard !first.isNumber else { return false }
      draft.bean = value
    case .grind: draft.grind = value
    case .notes: draft.notes = [draft.notes, value].filter { !$0.isEmpty }.joined(separator: "\n")
    case .dose:
      guard let grams = weight(value), grams <= 100 else { return false }
      draft.doseG = grams
    case .water:
      guard let grams = weight(value), grams <= 5000 else { return false }
      draft.waterG = grams
    case .temperature:
      guard let celsius = temperature(value) else { return false }
      draft.tempC = celsius
    case .time:
      guard let seconds = seconds(value) else { return false }
      draft.totalTimeS = seconds
    case .rating:
      guard let tenths = rating(value) else { return false }
      draft.ratingTenths = tenths
    }
    draft.confidence[field] = min(confidence, draft.confidence[field] ?? 1)
    return true
  }

  // MARK: Values

  /// The first number in `text` and what follows it. "18,5 g" is 18.5.
  static func number(in text: String) -> (value: Double, rest: Substring)? {
    guard let start = text.firstIndex(where: \.isNumber) else { return nil }
    var end = start
    var seenSeparator = false
    while end < text.endIndex {
      let character = text[end]
      if character.isNumber {
        end = text.index(after: end)
      } else if !seenSeparator, character == "." || character == ",",
        text.index(after: end) < text.endIndex, text[text.index(after: end)].isNumber
      {
        seenSeparator = true
        end = text.index(after: end)
      } else {
        break
      }
    }
    let digits = text[start..<end].replacingOccurrences(of: ",", with: ".")
    return Double(digits).map { ($0, text[end...]) }
  }

  private static func weight(_ text: String) -> Double? {
    guard let (value, rest) = number(in: text), value > 0 else { return nil }
    switch unit(rest) {
    case "", "g", "gr", "gram", "grams": return value
    case "oz", "ounce", "ounces": return value * UnitPreferences.gramsPerOunce
    // "3OO g" (letter O for zero) is not 3 g: anything else after the number is unread.
    default: return nil
    }
  }

  private static func temperature(_ text: String) -> Double? {
    guard let (value, rest) = number(in: text) else { return nil }
    let celsius: Double
    switch unit(rest, extra: "°") {
    case "": celsius = value > 110 ? (value - 32) * 5 / 9 : value
    case "c", "celsius": celsius = value
    case "f", "fahrenheit": celsius = (value - 32) * 5 / 9
    default: return nil
    }
    return (20...100).contains(celsius) ? celsius : nil
  }

  private static func unit(_ rest: Substring, extra: String = "") -> String {
    rest.trimmingCharacters(in: CharacterSet(charactersIn: " .\(extra)")).lowercased()
  }

  /// "2:30", "150", "150 s", "2 min 30" and "2.5 min" are all 150 seconds.
  private static func seconds(_ text: String) -> Int? {
    guard let (first, rest) = number(in: text) else { return nil }
    let tail = rest.trimmingCharacters(in: .whitespaces).lowercased()
    var total: Double
    if tail.hasPrefix(":"), let (second, _) = number(in: String(tail.dropFirst())) {
      total = first * 60 + second
    } else if tail.hasPrefix("m"), !tail.hasPrefix("ms") {
      total = first * 60
      let after = tail.drop(while: \.isLetter).trimmingCharacters(in: .whitespaces)
      if let (second, _) = number(in: after) { total += second }
    } else if ["", "s", "sec", "secs", "second", "seconds"].contains(unit(rest)) {
      total = first
    } else {
      return nil
    }
    return (1...3600).contains(total) ? Int(total.rounded()) : nil
  }

  /// "4", "4.5/5", "8/10" and "★★★★" are grades; the result is in half steps.
  /// A rating as tenths out of 10. Stars and "x/5" count double; "x/10" or a bare number
  /// above 5 is read as out of 10.
  private static func rating(_ text: String) -> Int? {
    let stars = text.filter { $0 == "★" }.count
    var outOfTen = Double(stars) * 2
    if stars == 0 {
      guard let (value, rest) = number(in: text) else { return nil }
      let outOf = number(in: String(rest)).map(\.value) ?? (value > 5 ? 10 : 5)
      outOfTen = outOf == 10 ? value : value * 2
    }
    guard outOfTen > 0, outOfTen <= 10 else { return nil }
    return Int((outOfTen * 10).rounded())
  }

  // MARK: AI reading

  public static let schema = JSONSchema.object([
    "method": .string(), "bean": .string(), "doseGrams": .number, "waterGrams": .number,
    "temperatureCelsius": .number, "timeSeconds": .number, "grind": .string(),
    "ratingOutOfFive": .number, "notes": .string(), "uncertain": .string(),
  ])

  public static let schemaName = "journal_page"

  private static let system = """
    You read one handwritten coffee brew journal entry from a photo. Copy only what is written. \
    Use an empty string for text you cannot read and 0 for a number you cannot read. Never guess \
    or calculate. doseGrams and waterGrams are in grams, temperatureCelsius in degrees Celsius, \
    timeSeconds in seconds, ratingOutOfFive from 0.5 to 5. notes holds the tasting notes and \
    anything else written. uncertain lists, separated by commas, the fields you are unsure you \
    read correctly, using these names: method, bean, dose, water, temperature, time, grind, \
    rating, notes.
    """

  /// `photo` must already be sanitized (no metadata); the queue sends it as-is.
  public static func payload(photo: Data) -> AIRequestPayload {
    AIRequestPayload(
      system: system, userText: "Read this journal entry.", schemaName: schemaName,
      schema: schema, imageJPEG: photo)
  }

  /// Confidence given to an AI-read field the model did not flag, and to one it did.
  static let aiSure = 0.9
  static let aiUnsure = 0.4

  /// The draft for an AI answer, or `nil` when it does not match the schema. The
  /// answer goes through the same rules as recognized text, so a dose of 4000 g
  /// or a 300 °C brew is dropped the same way.
  public static func draft(fromAI json: Data) -> PaperBrewDraft? {
    guard let object = try? JSONSerialization.jsonObject(with: json), schema.validates(object),
      let answer = object as? [String: Any]
    else { return nil }
    let unsure = Set(
      (answer["uncertain"] as? String ?? "").lowercased().split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) })
    func line(_ label: String, _ field: PaperField, _ value: String?) -> PaperLine? {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
      else { return nil }
      let name = field == .temperature ? "temp" : field.rawValue
      return PaperLine(
        text: "\(label) \(value)", confidence: unsure.contains(name) ? aiUnsure : aiSure)
    }
    func amount(_ key: String, _ suffix: String) -> String? {
      (answer[key] as? Double).flatMap { $0 > 0 ? "\($0) \(suffix)" : nil }
    }
    let lines = [
      line("Method:", .method, answer["method"] as? String),
      line("Beans:", .bean, answer["bean"] as? String),
      line("Dose:", .dose, amount("doseGrams", "g")),
      line("Water:", .water, amount("waterGrams", "g")),
      line("Temp:", .temperature, amount("temperatureCelsius", "C")),
      line("Time:", .time, amount("timeSeconds", "s")),
      line("Grind:", .grind, answer["grind"] as? String),
      line("Rating:", .rating, amount("ratingOutOfFive", "/ 5")),
      line("Notes:", .notes, answer["notes"] as? String),
    ].compactMap { $0 }
    return parse(lines)
  }
}
