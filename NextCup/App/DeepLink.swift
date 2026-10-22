import Foundation

/// A `nextcup://` entry point (blueprint §3c):
/// `brew/new`, `brew/<id>`, `brew-again/<id>`, `recipe/<id>`, `bean/<id>`.
enum DeepLink: Hashable, Sendable {
  case newBrew
  case brew(UUID)
  /// A new brew that repeats the saved brew with this id.
  case brewAgain(UUID)
  case recipe(UUID)
  case bean(UUID)

  static let scheme = "nextcup"

  /// Returns `nil` for another scheme, an unknown kind, a missing or malformed id,
  /// or extra path segments, so a bad link never lands on a wrong screen.
  init?(url: URL) {
    guard url.scheme?.lowercased() == Self.scheme, let kind = url.host()?.lowercased() else {
      return nil
    }
    let segments = url.pathComponents.filter { $0 != "/" }
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
    default:
      return nil
    }
  }

  var tab: AppTab {
    switch self {
    case .newBrew, .brew, .brewAgain: .journal
    case .recipe: .recipes
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
    }
  }

  var identifier: String {
    switch self {
    case .newBrew: "destination.brew.new"
    case .brew(let id): "destination.brew.\(id.uuidString)"
    case .brewAgain(let id): "destination.brew-again.\(id.uuidString)"
    case .recipe(let id): "destination.recipe.\(id.uuidString)"
    case .bean(let id): "destination.bean.\(id.uuidString)"
    }
  }
}
