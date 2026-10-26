import Foundation

/// A `nextcup://` entry point (blueprint §3c):
/// `brew/new`, `brew/<id>`, `brew-again/<id>`, `recipe/<id>`, `bean/<id>`, `settings`,
/// `taste/<id>`.
enum DeepLink: Hashable, Sendable {
  case newBrew
  case brew(UUID)
  /// A new brew that repeats the saved brew with this id.
  case brewAgain(UUID)
  case recipe(UUID)
  case bean(UUID)
  /// The running guided timer for a recipe at the dose it was started with (Live Activity tap).
  case timer(recipeID: UUID, doseG: Double)
  /// Settings, pushed on the Journal's stack.
  case settings
  /// How a saved brew tasted, then the change for the next cup (taste reminder tap).
  case taste(UUID)

  static let scheme = "nextcup"

  /// Returns `nil` for another scheme, an unknown kind, a missing or malformed id,
  /// or extra path segments, so a bad link never lands on a wrong screen.
  init?(url: URL) {
    guard url.scheme?.lowercased() == Self.scheme, let kind = url.host()?.lowercased() else {
      return nil
    }
    let segments = url.pathComponents.filter { $0 != "/" }
    if kind == "settings", segments.isEmpty {
      self = .settings
      return
    }
    guard segments.count == 1, let target = segments.first else { return nil }
    switch kind {
    case "brew" where target.lowercased() == "new":
      self = .newBrew
    case "brew":
      guard let id = UUID(uuidString: target) else { return nil }
      self = .brew(id)
    case "brew-again":
      guard let id = UUID(uuidString: target) else { return nil }
      self = .brewAgain(id)
    case "recipe":
      guard let id = UUID(uuidString: target) else { return nil }
      self = .recipe(id)
    case "bean":
      guard let id = UUID(uuidString: target) else { return nil }
      self = .bean(id)
    case "taste":
      guard let id = UUID(uuidString: target) else { return nil }
      self = .taste(id)
    case "timer":
      let dose = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
        .first { $0.name == "dose" }?.value.flatMap(Double.init)
      guard let id = UUID(uuidString: target), let dose, dose.isFinite, dose > 0 else {
        return nil
      }
      self = .timer(recipeID: id, doseG: dose)
    default:
      return nil
    }
  }

  var tab: AppTab {
    switch self {
    case .newBrew, .brew, .brewAgain, .settings, .taste: .journal
    case .recipe, .timer: .recipes
    case .bean: .beans
    }
  }

  var url: URL {
    switch self {
    case .newBrew: URL(string: "\(Self.scheme)://brew/new")!
    case .brew(let id): URL(string: "\(Self.scheme)://brew/\(id.uuidString)")!
    case .brewAgain(let id): URL(string: "\(Self.scheme)://brew-again/\(id.uuidString)")!
    case .recipe(let id): URL(string: "\(Self.scheme)://recipe/\(id.uuidString)")!
    case .bean(let id): URL(string: "\(Self.scheme)://bean/\(id.uuidString)")!
    case .timer(let id, let doseG):
      URL(string: "\(Self.scheme)://timer/\(id.uuidString)?dose=\(doseG)")!
    case .settings: URL(string: "\(Self.scheme)://settings")!
    case .taste(let id): URL(string: "\(Self.scheme)://taste/\(id.uuidString)")!
    }
  }

  /// Stable name used for accessibility identifiers and the placeholder screens.
  var screenName: String {
    switch self {
    case .newBrew: "New brew"
    case .brew: "Brew"
    case .brewAgain: "Brew again"
    case .recipe: "Recipe"
    case .bean: "Bean"
    case .timer: "Timer"
    case .settings: "Settings"
    case .taste: "Taste"
    }
  }

  var identifier: String {
    switch self {
    case .newBrew: "destination.brew.new"
    case .brew(let id): "destination.brew.\(id.uuidString)"
    case .brewAgain(let id): "destination.brew-again.\(id.uuidString)"
    case .recipe(let id): "destination.recipe.\(id.uuidString)"
    case .bean(let id): "destination.bean.\(id.uuidString)"
    case .timer(let id, _): "destination.timer.\(id.uuidString)"
    case .settings: "tab.root.settings"
    case .taste(let id): "destination.taste.\(id.uuidString)"
    }
  }
}
