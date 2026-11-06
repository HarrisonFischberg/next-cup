import Foundation

/// Features being tried behind a flag (evolve cycles). Each case is one flag; its raw value is
/// its key in the experiments store, so it must not change while the flag ships.
enum Experiment: String, CaseIterable, Identifiable {
  /// Placeholder so the registry and its screen have a row; it gates nothing.
  case example

  var id: String { rawValue }

  var title: String {
    switch self {
    case .example: "Example (does nothing)"
    }
  }
}

/// Reads and sets experiment flags. Every flag is off in App Store builds, whatever is stored.
/// Debug and TestFlight builds can turn flags on in the hidden Experiments screen
/// (long-press the version in Settings) or all at once with the launch argument `-evolve_all YES`.
enum Experiments {
  static let suiteName = "evolve.experiments"
  static let allOnArgument = "-evolve_all"

  /// Overrides live only here, never in the app's standard defaults.
  static var store: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

  static var canOverride: Bool {
    #if DEBUG
      let isDebug = true
    #else
      let isDebug = false
    #endif
    return canOverride(
      isDebug: isDebug, receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent)
  }

  /// TestFlight installs carry a sandbox receipt; App Store installs do not.
  static func canOverride(isDebug: Bool, receiptName: String?) -> Bool {
    isDebug || receiptName == "sandboxReceipt"
  }

  static func isOn(_ experiment: Experiment) -> Bool {
    isOn(
      experiment, canOverride: canOverride, defaults: store,
      arguments: ProcessInfo.processInfo.arguments)
  }

  static func isOn(
    _ experiment: Experiment, canOverride: Bool, defaults: UserDefaults, arguments: [String]
  ) -> Bool {
    guard canOverride else { return false }
    if let index = arguments.firstIndex(of: allOnArgument), index + 1 < arguments.count,
      arguments[index + 1] == "YES"
    {
      return true
    }
    return defaults.bool(forKey: experiment.rawValue)
  }

  static func set(_ experiment: Experiment, on: Bool, defaults: UserDefaults = store) {
    defaults.set(on, forKey: experiment.rawValue)
  }

  static func turnAllOn(defaults: UserDefaults = store) {
    for experiment in Experiment.allCases { set(experiment, on: true, defaults: defaults) }
  }

  static func reset(defaults: UserDefaults = store) {
    for experiment in Experiment.allCases { defaults.removeObject(forKey: experiment.rawValue) }
  }
}
