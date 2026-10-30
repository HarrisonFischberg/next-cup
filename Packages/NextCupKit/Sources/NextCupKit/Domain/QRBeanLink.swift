import Foundation

/// A QR code on a coffee bag, read into a bean draft. Most codes are a link to the
/// roaster's page for that coffee; the page is fetched once and read for the
/// product's name, roaster and the usual coffee facts. Pure: the app supplies the
/// transport, so validation, parsing and every failure path are testable.
///
/// Page text is data, not instructions. Nothing here is saved: values only
/// prefill the bean form for the user to check.
public enum QRBeanLink {
  public static let userAgent = "NextCup/1.0 (iOS; hello@rarecreatures.app)"
  /// Pages bigger than this are cut before parsing; product facts sit near the top.
  public static let maxPageBytes = 2_000_000
  /// Longest value kept for a field; anything longer is a paragraph, not a fact.
  static let maxValueLength = 80

  // MARK: Link

  /// The web link in a scanned payload, or nil when it is not one this app opens.
  /// Only web links to a named host are fetched: no other scheme, no user name or
  /// password, no IP address or local name (which would reach the home network).
  /// A plain `http` link is upgraded to `https`.
  public static func link(from payload: String) -> URL? {
    var text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    // Some bags print a bare "www.roaster.com/coffee".
    if text.lowercased().hasPrefix("www."), !text.contains("://") { text = "https://" + text }
    guard text.count <= 2048, !text.contains(where: \.isWhitespace),
      var parts = URLComponents(string: text),
      let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
      parts.user == nil, parts.password == nil,
      let host = parts.host?.lowercased(), isPublicName(host)
    else { return nil }
    parts.scheme = "https"
    parts.host = host
    if parts.port == 80 { parts.port = nil }
    return parts.url
  }

  private static func isPublicName(_ host: String) -> Bool {
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }),
      host.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }),
      !["local", "localhost", "internal", "lan", "home", "arpa"].contains(String(labels.last!)),
      // An all-digit last label is an IPv4 address; real top-level domains have letters.
      !labels.last!.allSatisfy(\.isNumber)
    else { return false }
    return true
  }

  public static func request(for link: URL) -> URLRequest {
    var request = URLRequest(url: link, timeoutInterval: 10)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    return request
  }

  // MARK: Result

  /// What a page or code said about the coffee. Blank means not found.
  public struct Draft: Equatable, Sendable {
    public var name = ""
    public var roaster = ""
    public var originCountry = ""
    public var region = ""
    public var farm = ""
    public var process = ""
    public var varietal = ""
    /// As written on the page, e.g. "Medium-light"; the app maps it to its levels.
    public var roastLevel = ""
    /// `yyyy-MM-dd`, only when the page states a roast date plainly.
    public var roastDate: String?
    public var flavorNotes = ""
    public var bagWeightGrams: Double?
    public var isDecaf = false
    /// The roaster's site (`https://host/`), from the page the link ended up on.
    public var website: URL?

    public init() {}

    subscript(field: Field) -> String {
      get {
        switch field {
        case .name: name
        case .roaster: roaster
        case .originCountry: originCountry
        case .region: region
        case .farm: farm
        case .process: process
        case .varietal: varietal
        case .roastLevel: roastLevel
        case .flavorNotes: flavorNotes
        }
      }
      set {
        switch field {
        case .name: name = newValue
        case .roaster: roaster = newValue
        case .originCountry: originCountry = newValue
        case .region: region = newValue
        case .farm: farm = newValue
        case .process: process = newValue
        case .varietal: varietal = newValue
        case .roastLevel: roastLevel = newValue
        case .flavorNotes: flavorNotes = newValue
        }
      }
    }

    /// Whether anything about the coffee itself was found (a website alone is not).
    public var isEmpty: Bool {
      name.isEmpty && roaster.isEmpty && originCountry.isEmpty && region.isEmpty
        && farm.isEmpty && process.isEmpty && varietal.isEmpty && roastLevel.isEmpty
        && roastDate == nil && flavorNotes.isEmpty && bagWeightGrams == nil
    }
  }

  public enum Failure: Error, Equatable, Sendable {
    /// The link was fetched but the page said nothing about a coffee.
    case nothingFound
    case offline
    /// Not a page (an error status, an image, a file) or not readable as text.
    case unreadable
  }

  /// Fetches `link` through `fetch` and reads the page. `fetch` returns the body, the
  /// status code, the final URL after redirects, and the MIME type when known.
  public static func lookUp(
    _ link: URL,
    fetch: @Sendable (URLRequest) async throws -> (Data, Int, URL?, String?)
  ) async -> Result<Draft, Failure> {
    let response: (data: Data, status: Int, finalURL: URL?, mime: String?)
    do {
      response = try await fetch(request(for: link))
    } catch {
      return .failure(.offline)
    }
    let (data, status, finalURL, mime) = response
    guard (200..<300).contains(status) else { return .failure(.unreadable) }
    if let mime, !mime.lowercased().contains("html"), !mime.lowercased().hasPrefix("text/") {
      return .failure(.unreadable)
    }
    let body = data.prefix(maxPageBytes)
    guard
      let html = String(data: body, encoding: .utf8)
        ?? String(data: body, encoding: .isoLatin1)
    else { return .failure(.unreadable) }
    var draft = parse(html: html)
    if !draft.isEmpty { draft.website = site(of: finalURL ?? link) }
    return draft.isEmpty ? .failure(.nothingFound) : .success(draft)
  }

  /// `https://host/` for a page, or nil for a link that is not one this app opens.
  public static func site(of url: URL) -> URL? {
    guard let page = link(from: url.absoluteString), let host = page.host else { return nil }
    return URL(string: "https://\(host)/")
  }

  // MARK: Parsing

  /// Reads a product page: structured data first (schema.org JSON-LD, Open Graph),
  /// then labelled facts in the visible text ("Origin: Ethiopia", or a label line
  /// followed by its value, as in a spec table).
  public static func parse(html: String) -> Draft {
    var draft = Draft()
    var facts: [(String, String)] = []

    let product = jsonLDProducts(in: html).first
    if let product {
      draft.name = clean(product["name"] as? String)
      draft.roaster = clean(brandName(product["brand"]) ?? brandName(product["manufacturer"]))
      for property in (product["additionalProperty"] as? [[String: Any]]) ?? [] {
        if let name = property["name"] as? String, let value = textValue(property["value"]) {
          facts.append((name, value))
        }
      }
    }
    let meta = metaTags(in: html)
    let siteName = clean(meta["og:site_name"])
    if draft.roaster.isEmpty { draft.roaster = clean(meta["product:brand"] ?? meta["og:brand"]) }
    if draft.roaster.isEmpty { draft.roaster = siteName }
    if draft.name.isEmpty {
      draft.name = clean(meta["og:title"] ?? meta["twitter:title"] ?? title(in: html))
    }
    draft.name = strippingSiteName(draft.name, names: [draft.roaster, siteName])

    let lines = visibleLines(in: html)
    facts += labelledFacts(in: lines)
    apply(facts, to: &draft)

    let description = clean(
      (product?["description"] as? String) ?? meta["og:description"] ?? meta["description"],
      limit: 2000)
    let evidence = lines + (description.isEmpty ? [] : [description])
    if draft.roastDate == nil { draft.roastDate = LabelEvidence.roastDate(in: evidence) }
    if draft.bagWeightGrams == nil {
      // Only a weight next to the product, not one from a size picker or shipping note.
      draft.bagWeightGrams = LabelEvidence.bagWeightGrams(in: [draft.name] + facts.map(\.1))
    }
    draft.isDecaf = [draft.name, draft.process].contains { fold($0).contains("decaf") }
    return draft
  }

  /// The app's roast level (`RoastLevel` raw value) for a level as a page writes it,
  /// or nil when the words name none ("Filter", "Omni", "Espresso").
  public static func roastLevelName(_ text: String) -> String? {
    let words = fold(text)
    let light = words.contains("light") || words.contains("blonde")
    let dark = words.contains("dark")
    let medium = words.contains("medium")
    switch (light, medium, dark) {
    case (true, _, _) where words.contains("ultra") || words.contains("extra"): return "ultraLight"
    case (true, true, false): return "mediumLight"
    case (false, true, true): return "mediumDark"
    case (true, false, false): return "light"
    case (false, true, false): return "medium"
    case (false, false, true): return "dark"
    default: return nil
    }
  }

  /// Reads a code that holds text instead of a link, one fact per line.
  public static func parse(text: String) -> Draft {
    let lines = text.components(separatedBy: .newlines).map { clean($0, limit: 200) }
      .filter { !$0.isEmpty }
    var draft = Draft()
    apply(labelledFacts(in: lines), to: &draft)
    draft.roastDate = LabelEvidence.roastDate(in: lines)
    draft.bagWeightGrams = LabelEvidence.bagWeightGrams(in: lines)
    draft.isDecaf = lines.contains { fold($0).contains("decaf") }
    return draft
  }

  /// The text fields a labelled fact can fill.
  enum Field: Sendable {
    case name, roaster, originCountry, region, farm, process, varietal, roastLevel, flavorNotes
  }

  /// Field labels as roasters write them, folded (lowercase, no accents).
  private static let labels: [(field: Field, words: [String])] = [
    (.name, ["coffee name", "product name"]),
    (.roaster, ["roaster", "roasted by", "roastery"]),
    (.originCountry, ["origin", "country", "country of origin", "origin country"]),
    (.region, ["region", "growing region", "subregion"]),
    (
      .farm,
      [
        "farm", "producer", "producers", "farmer", "estate", "finca", "washing station",
        "station", "cooperative", "co-op", "grower",
      ]
    ),
    (.process, ["process", "processing", "processing method"]),
    (.varietal, ["variety", "varieties", "varietal", "varietals", "cultivar", "cultivars"]),
    (.roastLevel, ["roast", "roast level", "roast profile", "roast degree", "roast style"]),
    (
      .flavorNotes,
      [
        "tasting notes", "notes", "flavor notes", "flavour notes", "flavor", "flavour",
        "cup notes", "cupping notes", "we taste", "tastes like",
      ]
    ),
  ]

  private static func field(for label: String) -> Field? {
    let key = fold(label).trimmingCharacters(in: CharacterSet(charactersIn: " :-–—"))
    return labels.first { $0.words.contains(key) }?.field
  }

  /// Fills blank fields only, so structured data wins over loose page text.
  private static func apply(_ facts: [(String, String)], to draft: inout Draft) {
    for (label, raw) in facts {
      let value = clean(raw)
      guard !value.isEmpty, value.count <= maxValueLength, !reads(asInstruction: value) else {
        continue
      }
      if fold(label).hasPrefix("roast date") || fold(label).hasPrefix("roasted on") {
        if draft.roastDate == nil {
          draft.roastDate = LabelEvidence.roastDate(in: ["roast \(value)"])
        }
        continue
      }
      if fold(label) == "weight" || fold(label) == "size" || fold(label) == "net weight" {
        if draft.bagWeightGrams == nil {
          draft.bagWeightGrams = LabelEvidence.bagWeightGrams(in: [value])
        }
        continue
      }
      guard let field = field(for: label), draft[field].isEmpty else { continue }
      draft[field] = value
    }
    // "Ethiopia, Yirgacheffe" as one origin line: the country first, the rest is the region.
    if draft.region.isEmpty, let comma = draft.originCountry.firstIndex(of: ",") {
      let rest = clean(String(draft.originCountry[draft.originCountry.index(after: comma)...]))
      draft.originCountry = clean(String(draft.originCountry[..<comma]))
      draft.region = rest
    }
  }

  /// "Label: value" on one line, or a line that is only a label followed by its value.
  static func labelledFacts(in lines: [String]) -> [(String, String)] {
    var facts: [(String, String)] = []
    var index = 0
    while index < lines.count {
      let line = lines[index]
      if let colon = line.firstIndex(of: ":"), line.distance(from: line.startIndex, to: colon) <= 30
      {
        let label = String(line[..<colon])
        let value = String(line[line.index(after: colon)...])
        if isKnownLabel(label), !clean(value).isEmpty {
          facts.append((label, value))
          index += 1
          continue
        }
      }
      if isKnownLabel(line), index + 1 < lines.count, !isKnownLabel(lines[index + 1]) {
        facts.append((line, lines[index + 1]))
        index += 2
        continue
      }
      index += 1
    }
    return facts
  }

  private static func isKnownLabel(_ text: String) -> Bool {
    let key = fold(text).trimmingCharacters(in: CharacterSet(charactersIn: " :-–—"))
    return field(for: text) != nil
      || ["roast date", "roasted on", "weight", "size", "net weight"].contains(key)
  }

  /// Page text that reads like it is talking to an assistant is never a fact.
  private static func reads(asInstruction text: String) -> Bool {
    text.lowercased().contains(/\b(?:ignore|instructions?|assistant|prompt|you must)\b/)
  }

  // MARK: HTML

  /// schema.org `Product` objects from JSON-LD blocks, including inside `@graph` and arrays.
  static func jsonLDProducts(in html: String) -> [[String: Any]] {
    let pattern =
      /(?is)<script[^>]*type\s*=\s*["']?application\/ld\+json["']?[^>]*>(.*?)<\/script>/
    var products: [[String: Any]] = []
    func walk(_ value: Any) {
      if let list = value as? [Any] { list.forEach(walk) }
      guard let object = value as? [String: Any] else { return }
      let type = object["@type"]
      let types = (type as? [String]) ?? [(type as? String) ?? ""]
      if types.contains(where: { $0 == "Product" || $0 == "ProductGroup" }) {
        products.append(object)
      }
      if let graph = object["@graph"] { walk(graph) }
    }
    for match in html.matches(of: pattern) {
      let json = decodeEntities(String(match.1)).trimmingCharacters(in: .whitespacesAndNewlines)
      if let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)) { walk(value) }
    }
    return products
  }

  private static func brandName(_ value: Any?) -> String? {
    if let name = value as? String { return name }
    if let object = value as? [String: Any] { return object["name"] as? String }
    if let list = value as? [Any] { return list.lazy.compactMap(brandName).first }
    return nil
  }

  private static func textValue(_ value: Any?) -> String? {
    if let text = value as? String { return text }
    if let number = value as? NSNumber { return number.stringValue }
    if let list = value as? [Any] {
      let parts = list.compactMap { $0 as? String }
      return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
    return nil
  }

  /// `<meta property|name="…" content="…">`, keys lowercased. The first tag for a key wins.
  static func metaTags(in html: String) -> [String: String] {
    var tags: [String: String] = [:]
    for tag in html.matches(of: /(?is)<meta\s[^>]*>/) {
      let attributes = attributes(in: String(tag.0))
      guard let key = (attributes["property"] ?? attributes["name"])?.lowercased(),
        let content = attributes["content"], tags[key] == nil
      else { continue }
      tags[key] = decodeEntities(content)
    }
    return tags
  }

  private static func attributes(in tag: String) -> [String: String] {
    var result: [String: String] = [:]
    for match in tag.matches(of: /(?i)([a-z:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/) {
      result[String(match.1).lowercased()] = String(match.2 ?? match.3 ?? "")
    }
    return result
  }

  private static func title(in html: String) -> String? {
    html.firstMatch(of: /(?is)<title[^>]*>(.*?)<\/title>/).map { decodeEntities(String($0.1)) }
  }

  /// "Ethiopia Guji – Sey Coffee" → "Ethiopia Guji" when the tail is the roaster or site.
  private static func strippingSiteName(_ name: String, names: [String]) -> String {
    let separators = [" | ", " – ", " — ", " - ", " · ", " :: "]
    for separator in separators {
      guard let range = name.range(of: separator, options: .backwards) else { continue }
      let tail = fold(String(name[range.upperBound...]))
      if names.contains(where: { !$0.isEmpty && (fold($0) == tail || tail.contains(fold($0))) }) {
        return clean(String(name[..<range.lowerBound]))
      }
    }
    return name
  }

  /// The page's text, one line per block element, without scripts, styles or markup.
  static func visibleLines(in html: String) -> [String] {
    var text = html
    for tag in ["head", "script", "style", "noscript", "template", "svg"] {
      if let hidden = try? Regex("(?is)<\(tag)\\b.*?</\(tag)\\s*>") {
        text.replace(hidden, with: " ")
      }
    }
    text.replace(/(?is)<!--.*?-->/, with: " ")
    text.replace(
      /(?i)<\/?(?:p|div|li|tr|td|th|dt|dd|h[1-6]|br|section|article|ul|ol|dl|table)\b[^>]*>/,
      with: "\n")
    text.replace(/(?s)<[^>]*>/, with: " ")
    return decodeEntities(text).components(separatedBy: .newlines)
      .map { clean($0, limit: 300) }
      .filter { !$0.isEmpty }
  }

  private static let entities: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "ndash": "–",
    "mdash": "—", "rsquo": "’", "lsquo": "‘", "ldquo": "“", "rdquo": "”", "hellip": "…",
    "eacute": "é", "aacute": "á", "iacute": "í", "oacute": "ó", "uacute": "ú", "ntilde": "ñ",
    "uuml": "ü", "ouml": "ö", "auml": "ä", "ccedil": "ç", "egrave": "è",
  ]

  static func decodeEntities(_ text: String) -> String {
    guard text.contains("&") else { return text }
    return text.replacing(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
      let name = String(match.1)
      if name.hasPrefix("#x"), let code = UInt32(name.dropFirst(2), radix: 16),
        let scalar = Unicode.Scalar(code)
      {
        return String(Character(scalar))
      }
      if name.hasPrefix("#"), let code = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(code)
      {
        return String(Character(scalar))
      }
      return entities[name.lowercased()] ?? String(match.0)
    }
  }

  /// Collapsed whitespace, trimmed, and blank when longer than `limit`.
  private static func clean(_ text: String?, limit: Int = 120) -> String {
    let collapsed = (text ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return collapsed.count > limit ? "" : collapsed
  }

  private static func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}
