import Foundation

/// Maps the raw words on a bag (origin, process, roast, flavor notes) and the
/// brewer name onto a small set of shared buckets, so history, recommendations
/// and the flavor explorer all speak the same vocabulary (blueprint §3a).
///
/// Mapping is deterministic: normalize the raw value, look for a user alias, then
/// the bundled map. A user alias always wins over the bundle, so the owner's
/// correction is never undone by an app update.
public struct Taxonomy: Sendable, Equatable {
  public enum Dimension: String, Codable, CaseIterable, Sendable {
    case origin, process, roast, flavor, brewer
  }

  public struct Bucket: Codable, Hashable, Sendable {
    public var key: String
    public var name: String

    public init(key: String, name: String) {
      self.key = key
      self.name = name
    }
  }

  /// A user's own mapping of a raw value to a bucket. `rawValue` is stored
  /// normalized, matching the `TaxonomyAlias` model.
  public struct Alias: Codable, Hashable, Sendable {
    public var dimension: Dimension
    public var rawValue: String
    public var bucketKey: String

    public init(dimension: Dimension, rawValue: String, bucketKey: String) {
      self.dimension = dimension
      self.rawValue = Taxonomy.normalize(rawValue)
      self.bucketKey = bucketKey
    }
  }

  /// The result of mapping one raw value.
  public enum Mapping: Hashable, Sendable {
    case bucket(Bucket, source: Source)
    /// Not in the bundle or the aliases. Offered to the user for mapping.
    case unmapped(raw: String)

    public enum Source: Hashable, Sendable {
      case bundle
      case userAlias
    }

    public var bucket: Bucket? {
      if case .bucket(let bucket, _) = self { return bucket }
      return nil
    }
  }

  public enum LoadError: Error, Equatable {
    case unknownDimension(String)
    case unknownBucket(dimension: String, key: String)
  }

  public let version: Int
  private let bucketsByDimension: [Dimension: [Bucket]]
  private let bundledMap: [Dimension: [String: String]]

  private struct File: Decodable {
    struct Section: Decodable {
      var buckets: [Bucket]
      var map: [String: String]
    }
    var version: Int
    var dimensions: [String: Section]
  }

  /// Parses `taxonomy.json`. Throws on an unknown dimension or a map entry that
  /// points at a bucket that does not exist, so a bad bundle fails in tests.
  public init(json: Data) throws {
    let file = try JSONDecoder().decode(File.self, from: json)
    var buckets: [Dimension: [Bucket]] = [:]
    var maps: [Dimension: [String: String]] = [:]
    for (name, section) in file.dimensions {
      guard let dimension = Dimension(rawValue: name) else {
        throw LoadError.unknownDimension(name)
      }
      let keys = Set(section.buckets.map(\.key))
      var normalized: [String: String] = [:]
      for (raw, key) in section.map {
        guard keys.contains(key) else {
          throw LoadError.unknownBucket(dimension: name, key: key)
        }
        normalized[Taxonomy.normalize(raw)] = key
      }
      buckets[dimension] = section.buckets
      maps[dimension] = normalized
    }
    version = file.version
    bucketsByDimension = buckets
    bundledMap = maps
  }

  public init(bundle: Bundle = .main) throws {
    guard let url = bundle.url(forResource: "taxonomy", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    try self.init(json: Data(contentsOf: url))
  }

  /// Lowercased, accents and punctuation folded, runs of whitespace collapsed:
  /// "Costa  Rica", "costa-rica" and "COSTA RICA" are the same raw value.
  public static func normalize(_ raw: String) -> String {
    let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    let spaced = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
    return String(spaced).split(separator: " ").joined(separator: " ")
  }

  public func buckets(in dimension: Dimension) -> [Bucket] {
    bucketsByDimension[dimension] ?? []
  }

  public func bucket(key: String, in dimension: Dimension) -> Bucket? {
    buckets(in: dimension).first { $0.key == key }
  }

  /// Maps one raw value. Empty input is `.unmapped` with an empty raw value so a
  /// caller can skip it; it is never offered for mapping.
  public func map(
    _ raw: String, in dimension: Dimension, aliases: [Alias] = []
  ) -> Mapping {
    let normalized = Taxonomy.normalize(raw)
    guard !normalized.isEmpty else { return .unmapped(raw: "") }

    if let alias = aliases.last(where: {
      $0.dimension == dimension && $0.rawValue == normalized
    }), let bucket = bucket(key: alias.bucketKey, in: dimension) {
      return .bucket(bucket, source: .userAlias)
    }
    if let key = bundledMap[dimension]?[normalized], let bucket = bucket(key: key, in: dimension) {
      return .bucket(bucket, source: .bundle)
    }
    return .unmapped(raw: normalized)
  }

  /// The distinct buckets for a list of raw values, in first-seen order.
  public func buckets(
    for raws: [String], in dimension: Dimension, aliases: [Alias] = []
  ) -> [Bucket] {
    var seen: Set<Bucket> = []
    var result: [Bucket] = []
    for raw in raws {
      if let bucket = map(raw, in: dimension, aliases: aliases).bucket, seen.insert(bucket).inserted
      {
        result.append(bucket)
      }
    }
    return result
  }

  /// Raw values that map nowhere, normalized and de-duplicated, for the
  /// "Unmapped" list where the user picks a bucket.
  public func unmapped(
    in raws: [String], dimension: Dimension, aliases: [Alias] = []
  ) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []
    for raw in raws {
      if case .unmapped(let value) = map(raw, in: dimension, aliases: aliases),
        !value.isEmpty, seen.insert(value).inserted
      {
        result.append(value)
      }
    }
    return result
  }

  /// A new alias, or `nil` when the bucket does not exist in that dimension or the
  /// raw value is empty. Replaces any earlier alias for the same raw value.
  public func alias(
    mapping raw: String, to bucketKey: String, in dimension: Dimension,
    replacing existing: [Alias] = []
  ) -> [Alias]? {
    let normalized = Taxonomy.normalize(raw)
    guard !normalized.isEmpty, bucket(key: bucketKey, in: dimension) != nil else { return nil }
    var aliases = existing.filter { !($0.dimension == dimension && $0.rawValue == normalized) }
    aliases.append(Alias(dimension: dimension, rawValue: normalized, bucketKey: bucketKey))
    return aliases
  }
}
