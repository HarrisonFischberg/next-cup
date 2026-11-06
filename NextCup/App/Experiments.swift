import Foundation

/// Features being tried behind a flag (evolve cycles). Each case is one flag; its raw value is
/// its key in the experiments store, so it must not change while the flag ships.
enum Experiment: String, CaseIterable, Identifiable {
  // Cycle 001 (2026-11-06). Raw values are the stored keys; see evolve/cycles/001/cards/.
  /// Timer: a pour step shows how much to pour now, with the running total second.
  case pourAmount = "exp_pour_amount"
  /// Beans tab: how much coffee is on hand across open bags.
  case beansOnHand = "exp_beans_on_hand"
  /// Recipe setup: last time with this bean (rating, taste, note) before you brew.
  case lastTimeNote = "exp_last_time_note"
  /// Bean detail: a small chart of ratings across this bean's brews.
  case beanTrend = "exp_bean_trend"
  /// Recipe setup: the bean menu shows grams left and freshness, least left first.
  case beanPickerDetail = "exp_bean_picker_detail"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pourAmount: "Timer: this pour's amount"
    case .beansOnHand: "Beans: coffee on hand"
    case .lastTimeNote: "Recipe setup: last time with this bean"
    case .beanTrend: "Bean detail: rating trend"
    case .beanPickerDetail: "Recipe setup: bean menu with grams left"
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
