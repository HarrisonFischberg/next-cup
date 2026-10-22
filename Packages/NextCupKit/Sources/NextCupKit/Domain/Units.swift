import Foundation

public enum WeightUnit: String, CaseIterable, Sendable {
  case grams
  case ounces
}

public enum TemperatureUnit: String, CaseIterable, Sendable {
  case celsius
  case fahrenheit
}

/// The single units setting. Storage is always grams and °C; conversion happens here, at display.
public struct UnitPreferences: Equatable, Sendable {
  public static let gramsPerOunce = 28.349523125

  public var weight: WeightUnit
  public var temperature: TemperatureUnit

  public init(weight: WeightUnit = .grams, temperature: TemperatureUnit = .celsius) {
    self.weight = weight
    self.temperature = temperature
  }

  public func displayWeight(grams: Double) -> Double {
    switch weight {
    case .grams: grams
    case .ounces: grams / Self.gramsPerOunce
    }
  }

  public func grams(fromDisplayWeight value: Double) -> Double {
    switch weight {
    case .grams: value
    case .ounces: value * Self.gramsPerOunce
    }
  }

  public func displayTemperature(celsius: Double) -> Double {
    switch temperature {
    case .celsius: celsius
    case .fahrenheit: celsius * 9 / 5 + 32
    }
  }

  public func celsius(fromDisplayTemperature value: Double) -> Double {
    switch temperature {
    case .celsius: value
    case .fahrenheit: (value - 32) * 5 / 9
    }
  }

  public var weightSymbol: String { weight == .grams ? "g" : "oz" }
  public var temperatureSymbol: String { temperature == .celsius ? "°C" : "°F" }
}
