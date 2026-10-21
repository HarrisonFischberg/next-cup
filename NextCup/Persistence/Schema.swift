import Foundation
import SwiftData

enum NextCupSchemaV1: VersionedSchema {
  static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

  static var models: [any PersistentModel.Type] {
    [
      Brew.self, BrewBean.self, Bean.self, Roaster.self, BrewMethod.self, Recipe.self,
      RecipeStep.self, Grinder.self, Suggestion.self, AIRequest.self, TaxonomyAlias.self,
      WaterProfile.self,
    ]
  }
}

/// Schema v1 is the first version, so there are no stages yet. Later versions
/// append their schema here and add lightweight or custom stages.
enum NextCupMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [NextCupSchemaV1.self] }
  static var stages: [MigrationStage] { [] }
}

enum NextCupContainer {
  /// The on-disk container, or an in-memory one for tests and previews.
  static func make(inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema(versionedSchema: NextCupSchemaV1.self)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    return try ModelContainer(
      for: schema, migrationPlan: NextCupMigrationPlan.self, configurations: [configuration])
  }
}
