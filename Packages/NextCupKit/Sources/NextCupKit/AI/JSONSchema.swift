import CoreFoundation
import Foundation

/// The small slice of JSON Schema the AI features need. Objects require every
/// property and allow no extras, which is also what OpenAI strict mode demands.
public indirect enum JSONSchema: Codable, Equatable, Sendable {
  case object([String: JSONSchema])
  case array(JSONSchema)
  case string(allowed: [String]? = nil)
  case number
  case integer
  case boolean

  /// The schema as a Foundation object, ready for `JSONSerialization`.
  public var jsonObject: [String: Any] {
    switch self {
    case .object(let properties):
      return [
        "type": "object", "properties": properties.mapValues(\.jsonObject),
        "required": properties.keys.sorted(), "additionalProperties": false,
      ]
    case .array(let items): return ["type": "array", "items": items.jsonObject]
    case .string(let allowed):
      var schema: [String: Any] = ["type": "string"]
      if let allowed { schema["enum"] = allowed }
      return schema
    case .number: return ["type": "number"]
    case .integer: return ["type": "integer"]
    case .boolean: return ["type": "boolean"]
    }
  }

  /// Whether a value decoded by `JSONSerialization` matches this schema exactly.
  public func validates(_ value: Any) -> Bool {
    switch self {
    case .object(let properties):
      guard let dictionary = value as? [String: Any],
        Set(dictionary.keys) == Set(properties.keys)
      else { return false }
      return properties.allSatisfy { dictionary[$0.key].map($0.value.validates) ?? false }
    case .array(let items):
      guard let array = value as? [Any] else { return false }
      return array.allSatisfy(items.validates)
    case .string(let allowed):
      guard let string = value as? String else { return false }
      return allowed?.contains(string) ?? true
    case .number: return Self.number(value) != nil
    case .integer:
      return Self.number(value).map { $0.truncatingRemainder(dividingBy: 1) == 0 } ?? false
    case .boolean: return (value as? NSNumber).map { Self.isBoolean($0) } ?? false
    }
  }

  private static func isBoolean(_ number: NSNumber) -> Bool {
    CFGetTypeID(number) == CFBooleanGetTypeID()
  }

  private static func number(_ value: Any) -> Double? {
    guard let number = value as? NSNumber, !isBoolean(number) else { return nil }
    return number.doubleValue
  }
}
