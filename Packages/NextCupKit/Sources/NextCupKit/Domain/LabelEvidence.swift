import Foundation

/// Conservative readers for text found on a coffee bag (OCR lines, top to bottom).
/// They return a value only when the label states it plainly, so a guess never fills
/// a field: a date needs a roast word on its line and a full, unambiguous day, month
/// and year; best-before, packed and harvest lines are never read as roast dates.
public enum LabelEvidence {
  private static let roastWords = ["roast", "röst", "rost", "tost", "tueste", "torr"]
  private static let otherDates = [
    "best", "use by", "exp", "bb", "mhd", "consum", "pack", "harvest", "cosecha", "ernte",
    "récolte", "mindestens", "caduc",
  ]
  /// Printed text is data: a line that reads like an instruction is never evidence.
  private static var instruction: Regex<Substring> {
    /\b(?:ignore|instructions?|set|change|use|should|must)\b/
  }
  private static let months: [String: Int] = [
    "jan": 1, "ene": 1, "gen": 1, "feb": 2, "fev": 2, "mar": 3, "apr": 4, "abr": 4, "avr": 4,
    "may": 5, "mai": 5, "mag": 5, "jun": 6, "jui": 6, "giu": 6, "jul": 7, "lug": 7,
    "aug": 8, "ago": 8, "aou": 8, "sep": 9, "set": 9, "oct": 10, "okt": 10, "ott": 10,
    "nov": 11, "dec": 12, "dez": 12, "dic": 12,
  ]

  /// The roast date as `yyyy-MM-dd`, or nil when no line states one unambiguously or
  /// lines state different ones (likely more than one bag in the photo).
  public static func roastDate(in lines: [String]) -> String? {
    let dates = roastDates(in: lines)
    return dates.count == 1 ? dates.first : nil
  }

  /// Every distinct roast date the lines state plainly.
  public static func roastDates(in lines: [String]) -> Set<String> {
    Set(
      lines.compactMap { line -> String? in
        let text = fold(line)
        guard roastWords.contains(where: text.contains),
          !otherDates.contains(where: { text.contains($0) }), !text.contains(instruction)
        else { return nil }
        return date(in: text)
      })
  }

  /// The bag weight in grams. Grams or kilograms win over ounces or pounds.
  public static func bagWeightGrams(in lines: [String]) -> Double? {
    let pattern = /(\d+(?:[.,]\d+)?)\s*(kg|grams|gram|gr|g|oz|lbs|lb)\b/
    var metric: Double?
    var imperial: Double?
    for line in lines {
      for match in fold(line).matches(of: pattern) {
        guard let value = Double(match.1.replacingOccurrences(of: ",", with: ".")), value > 0
        else { continue }
        switch match.2 {
        case "kg": metric = metric ?? value * 1000
        case "oz": imperial = imperial ?? value * 28.3495
        case "lb", "lbs": imperial = imperial ?? value * 453.592
        default: metric = metric ?? value
        }
      }
    }
    return (metric ?? imperial).map { ($0 * 10).rounded() / 10 }
  }

  /// Whether any line names a farm or producer, the only evidence for a farm field.
  public static func namesFarm(in lines: [String]) -> Bool {
    let words = [
      "farm", "finca", "estate", "hacienda", "fazenda", "producer", "productor", "sitio",
    ]
    return lines.contains { line in words.contains(where: fold(line).contains) }
  }

  /// Whether a line states a roast level, the only evidence for a roast-level field.
  public static func statesRoastLevel(in lines: [String]) -> Bool {
    let levels = ["light", "medium", "dark", "city", "hell", "dunkel", "claro", "oscuro", "medio"]
    return lines.contains { line in
      let text = fold(line)
      return roastWords.contains(where: text.contains) && levels.contains(where: text.contains)
    }
  }

  // MARK: Private

  private static func fold(_ text: String) -> String {
    text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
      .replacingOccurrences(of: "ö", with: "o")
  }

  private static func date(in text: String) -> String? {
    let cleaned = text.replacing(/([0-9])(st|nd|rd|th)\b/) { "\($0.1)" }
    if let m = cleaned.firstMatch(of: /\b([0-9]{4})[-\/.]([0-9]{1,2})[-\/.]([0-9]{1,2})\b/) {
      return valid(Int(m.1)!, Int(m.2)!, Int(m.3)!)
    }
    if let m = cleaned.firstMatch(of: /\b([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})\b/) {
      return valid(Int(m.3)!, Int(m.2)!, Int(m.1)!)
    }
    if let m = cleaned.firstMatch(of: /\b([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})\b/) {
      let (a, b, year) = (Int(m.1)!, Int(m.2)!, Int(m.3)!)
      // 03/04/2026 could be either order; only a day above 12 or equal parts settle it.
      if a > 12 { return valid(year, b, a) }
      if b > 12 || a == b { return valid(year, a, b) }
      return nil
    }
    if let m = cleaned.firstMatch(
      of: /\b([0-9]{1,2})\.?\s+(?:de\s+)?([a-z]{3,})\.?,?\s+(?:de\s+)?([0-9]{4})\b/),
      let month = months[String(m.2.prefix(3))]
    {
      return valid(Int(m.3)!, month, Int(m.1)!)
    }
    if let m = cleaned.firstMatch(of: /\b([a-z]{3,})\.?\s+([0-9]{1,2}),?\s+([0-9]{4})\b/),
      let month = months[String(m.1.prefix(3))]
    {
      return valid(Int(m.3)!, month, Int(m.2)!)
    }
    return nil
  }

  private static func valid(_ year: Int, _ month: Int, _ day: Int) -> String? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let parts = DateComponents(year: year, month: month, day: day)
    guard (2000...2100).contains(year), let date = calendar.date(from: parts),
      calendar.dateComponents([.year, .month, .day], from: date) == parts
    else { return nil }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }
}
