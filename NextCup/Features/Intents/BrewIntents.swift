import AppIntents
import Foundation
import SwiftData

/// Which screen each Shortcuts and Siri action opens. Every intent opens an
/// existing `nextcup://` link, so an action reaches the same screens as a link.
@MainActor
enum IntentLinks {
  static var logBrew: DeepLink { .newBrew }

  /// The link that repeats the most recent saved brew, or `nil` when there is none.
  static func brewAgain(in context: ModelContext) -> DeepLink? {
    var latest = FetchDescriptor<Brew>(
      predicate: #Predicate { !$0.isDraft }, sortBy: [SortDescriptor(\.date, order: .reverse)])
    latest.fetchLimit = 1
    return (try? context.fetch(latest))?.first.map { .brewAgain($0.id) }
  }

  /// The guided timer for a recipe, at the dose the recipe asks for.
  static func startRecipe(_ recipe: Recipe) -> DeepLink {
    .timer(recipeID: recipe.id, doseG: recipe.doseG)
  }

  /// The recipe an action names, if it still exists and can be timed.
  static func startRecipe(id: UUID, in context: ModelContext) -> DeepLink? {
    guard let recipe = try? Store(context: context).find(Recipe.self, id: id), recipe.doseG > 0
    else { return nil }
    return startRecipe(recipe)
  }
}

enum BrewIntentError: Error, CustomLocalizedStringResourceConvertible {
  case noBrews
  case recipeUnavailable
  case storeUnavailable

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noBrews: "There is no saved brew to repeat yet."
    case .recipeUnavailable: "That recipe is no longer available."
    case .storeUnavailable: "Next Cup could not open your journal."
    }
  }
}

@MainActor
private func openContext() throws -> ModelContext {
  do { return try NextCupContainer.make().mainContext } catch {
    throw BrewIntentError.storeUnavailable
  }
}

struct LogBrewIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a brew"
  static let description = IntentDescription("Opens a new brew in Next Cup.")

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(IntentLinks.logBrew.url))
  }
}

struct BrewAgainIntent: AppIntent {
  static let title: LocalizedStringResource = "Brew again"
  static let description = IntentDescription("Repeats your most recent brew.")

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    guard let link = IntentLinks.brewAgain(in: try openContext()) else {
      throw BrewIntentError.noBrews
    }
    return .result(opensIntent: OpenURLIntent(link.url))
  }
}

struct RecipeEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
  static let defaultQuery = RecipeEntityQuery()

  let id: UUID
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct RecipeEntityQuery: EntityQuery {
  @MainActor
  func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
    try recipes().filter { identifiers.contains($0.id) }
  }

  @MainActor
  func suggestedEntities() async throws -> [RecipeEntity] { try recipes() }

  @MainActor
  private func recipes() throws -> [RecipeEntity] {
    let all = try openContext().fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.name)]))
    return all.map { RecipeEntity(id: $0.id, name: $0.name) }
  }
}

struct StartRecipeIntent: AppIntent {
  static let title: LocalizedStringResource = "Start recipe"
  static let description = IntentDescription("Opens a recipe's guided timer.")

  @Parameter(title: "Recipe") var recipe: RecipeEntity

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    guard let link = IntentLinks.startRecipe(id: recipe.id, in: try openContext()) else {
      throw BrewIntentError.recipeUnavailable
    }
    return .result(opensIntent: OpenURLIntent(link.url))
  }
}

struct NextCupShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogBrewIntent(), phrases: ["Log a brew in \(.applicationName)"],
      shortTitle: "Log a brew", systemImageName: "plus.circle")
    AppShortcut(
      intent: BrewAgainIntent(), phrases: ["Brew again in \(.applicationName)"],
      shortTitle: "Brew again", systemImageName: "arrow.counterclockwise")
    AppShortcut(
      intent: StartRecipeIntent(),
      phrases: ["Start a recipe in \(.applicationName)"],
      shortTitle: "Start recipe", systemImageName: "timer")
  }
}
