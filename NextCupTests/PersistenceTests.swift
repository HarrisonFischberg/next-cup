import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@Suite(.serialized) @MainActor struct PersistenceTests {
  private func makeStore() throws -> (Store, ModelContainer) {
    let container = try NextCupContainer.make(inMemory: true)
    return (Store(context: container.mainContext), container)
  }

  // MARK: CloudKit compatibility (blueprint §2)

  @Test func schemaHasAllBlueprintModels() {
    let names = Set(Schema(versionedSchema: NextCupSchemaV1.self).entities.map(\.name))
    let expected: Set<String> = [
      "Brew", "BrewBean", "Bean", "Roaster", "BrewMethod", "Recipe", "RecipeStep", "Grinder",
      "Suggestion", "AIRequest", "TaxonomyAlias", "WaterProfile",
    ]
    #expect(names == expected)
  }

  @Test func schemaIsCloudKitCompatible() {
    let schema = Schema(versionedSchema: NextCupSchemaV1.self)
    for entity in schema.entities {
      #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) has a unique constraint")
      for attribute in entity.attributes {
        #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) is unique")
      }
      for relationship in entity.relationships {
        #expect(relationship.isOptional, "\(entity.name).\(relationship.name) is not optional")
      }
    }

    // SwiftData rejects an inverse declared on both sides, so a pair is declared
    // from one end. Every relationship must be that end or the target of one.
    var paired = Set<String>()
    for entity in schema.entities {
      for relationship in entity.relationships {
        guard let inverse = relationship.inverseName else { continue }
        paired.insert("\(entity.name).\(relationship.name)")
        paired.insert("\(relationship.destination).\(inverse)")
      }
    }
    for entity in schema.entities {
      for relationship in entity.relationships {
        let key = "\(entity.name).\(relationship.name)"
        #expect(paired.contains(key), "\(key) has no explicit inverse")
      }
    }
  }

  /// CloudKit needs every row to be creatable from defaults alone, so each model
  /// must save when built with no arguments.
  @Test func everyModelSavesFromDefaultsAlone() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    context.insert(Brew())
    context.insert(BrewBean())
    context.insert(Bean())
    context.insert(Roaster())
    context.insert(BrewMethod())
    context.insert(Recipe())
    context.insert(RecipeStep())
    context.insert(Grinder())
    context.insert(Suggestion())
    context.insert(AIRequest())
    context.insert(TaxonomyAlias())
    context.insert(WaterProfile())
    try store.save().get()
    #expect(try context.fetch(FetchDescriptor<AIRequest>()).count == 1)
  }

  @Test func everyModelHasStableIDAndTimestamps() {
    let schema = Schema(versionedSchema: NextCupSchemaV1.self)
    for entity in schema.entities {
      let names = Set(entity.attributes.map(\.name))
      #expect(names.isSuperset(of: ["id", "createdAt", "updatedAt"]), "\(entity.name)")
    }
  }

  @Test func migrationPlanStartsAtV1() {
    #expect(NextCupMigrationPlan.schemas.count == 1)
    #expect(NextCupSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
  }

  // MARK: CRUD

  @Test func createsAndReadsBrewWithRelationships() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext

    let method = BrewMethod(name: "V60", style: .pourOver)
    let bean = Bean(name: "Synthetic Blend")
    bean.roastLevel = .light
    bean.bagFlavorNotes = ["citrus", "honey"]
    let brew = Brew()
    brew.doseG = 15
    brew.waterG = 250
    brew.verdict = .sour
    brew.method = method
    let use = BrewBean(grams: 15, beanNameSnapshot: bean.name)
    use.bean = bean
    use.brew = brew
    context.insert(method)
    context.insert(bean)
    context.insert(brew)
    context.insert(use)
    try store.save().get()

    let fetched = try context.fetch(FetchDescriptor<Brew>())
    #expect(fetched.count == 1)
    #expect(fetched[0].method?.name == "V60")
    #expect(fetched[0].beans?.first?.bean?.bagFlavorNotes == ["citrus", "honey"])
    #expect(bean.brewUses?.count == 1)
    #expect(method.brews?.count == 1)
  }

  @Test func updatesAndDeletes() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    let grinder = Grinder(name: "Hand grinder")
    context.insert(grinder)
    try store.save().get()

    grinder.notes = "Click 20"
    try store.save().get()
    #expect(try context.fetch(FetchDescriptor<Grinder>()).first?.notes == "Click 20")

    context.delete(grinder)
    try store.save().get()
    #expect(try context.fetch(FetchDescriptor<Grinder>()).isEmpty)
  }

  @Test func defaultsAreSane() {
    let brew = Brew()
    #expect(brew.notes == "")
    #expect(brew.doseG == nil)
    let bean = Bean()
    #expect(bean.status == .inUse)
    #expect(bean.remainingAdjustmentG == 0)
  }

  // MARK: Delete rules

  @Test func deletingBrewCascadesToBrewBeansButKeepsBean() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    let bean = Bean(name: "Keeper")
    let brew = Brew()
    let use = BrewBean(grams: 18)
    use.bean = bean
    use.brew = brew
    context.insert(bean)
    context.insert(brew)
    context.insert(use)
    try store.save().get()

    context.delete(brew)
    try store.save().get()
    #expect(try context.fetch(FetchDescriptor<BrewBean>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<Bean>()).count == 1)
  }

  @Test func deletingMethodKeepsBrewHistory() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    let method = BrewMethod(name: "Custom")
    let brew = Brew()
    brew.method = method
    context.insert(method)
    context.insert(brew)
    try store.save().get()

    context.delete(method)
    try store.save().get()
    let brews = try context.fetch(FetchDescriptor<Brew>())
    #expect(brews.count == 1)
    #expect(brews[0].method == nil)
  }

  @Test func deletingRecipeCascadesToSteps() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    let recipe = Recipe(name: "Test", doseG: 15, waterG: 250)
    let step = RecipeStep(order: 0, kind: .bloom, startOffsetS: 0)
    step.recipe = recipe
    context.insert(recipe)
    context.insert(step)
    try store.save().get()

    context.delete(recipe)
    try store.save().get()
    #expect(try context.fetch(FetchDescriptor<RecipeStep>()).isEmpty)
  }

  // MARK: Upsert by id

  @Test func upsertTwiceKeepsOneRow() throws {
    let (store, container) = try makeStore()
    let id = UUID()
    try store.upsert(Bean.self, id: id, make: { Bean() }, update: { $0.name = "First" })
    try store.upsert(Bean.self, id: id, make: { Bean() }, update: { $0.name = "Second" })
    try store.save().get()

    let beans = try container.mainContext.fetch(FetchDescriptor<Bean>())
    #expect(beans.count == 1)
    #expect(beans[0].id == id)
    #expect(beans[0].name == "Second")
  }

  @Test func upsertDistinctIDsInsertsBoth() throws {
    let (store, container) = try makeStore()
    try store.upsert(Roaster.self, id: UUID(), make: { Roaster() }, update: { $0.name = "A" })
    try store.upsert(Roaster.self, id: UUID(), make: { Roaster() }, update: { $0.name = "B" })
    try store.save().get()
    #expect(try container.mainContext.fetch(FetchDescriptor<Roaster>()).count == 2)
  }

  @Test func upsertStampsUpdatedAt() throws {
    let (store, container) = try makeStore()
    defer { withExtendedLifetime(container) {} }
    let id = UUID()
    let old = Date(timeIntervalSince1970: 0)
    let bean = try store.upsert(
      Bean.self, id: id, make: { Bean() }, update: { $0.updatedAt = old })
    #expect(bean.updatedAt > old)
  }

  @Test func findReturnsNilForUnknownID() throws {
    let (store, container) = try makeStore()
    defer { withExtendedLifetime(container) {} }
    #expect(try store.find(Bean.self, id: UUID()) == nil)
  }

  // MARK: Round trips

  @Test func enumsAndArraysRoundTrip() throws {
    let (store, container) = try makeStore()
    let method = BrewMethod(name: "Espresso", style: .espresso)
    method.trackedParameters = [.dose, .yield, .time]
    method.defaultStepKinds = [.bloom, .pour, .drawdown]
    container.mainContext.insert(method)
    try store.save().get()

    let fetched = try container.mainContext.fetch(FetchDescriptor<BrewMethod>())
    #expect(fetched[0].style == .espresso)
    #expect(fetched[0].trackedParameters == [.dose, .yield, .time])
    #expect(fetched[0].defaultStepKinds == [.bloom, .pour, .drawdown])
  }

  @Test func suggestionLinksToSourceAndAppliedBrews() throws {
    let (store, container) = try makeStore()
    let context = container.mainContext
    let first = Brew()
    let next = Brew()
    let suggestion = Suggestion()
    suggestion.sourceBrew = first
    suggestion.field = .grind
    suggestion.fromValue = "20"
    suggestion.toValue = "18"
    next.suggestionFollowed = suggestion
    context.insert(first)
    context.insert(next)
    context.insert(suggestion)
    try store.save().get()

    #expect(first.suggestionsMade?.count == 1)
    #expect(suggestion.appliedTo?.count == 1)
  }
}

@Suite @MainActor struct RatingMigrationTests {
  @Test func oldHalfPointsBecomeTenthsOutOfTenOnce() throws {
    let container = try NextCupContainer.make(inMemory: true)
    let context = container.mainContext
    let brew = Brew()
    brew.ratingTenths = 7  // 3.5 of 5, stored before the change
    let unrated = Brew()
    let bean = Bean(name: "Kenya")
    bean.ratingTenths = 10
    context.insert(brew)
    context.insert(unrated)
    context.insert(bean)
    let defaults = try #require(UserDefaults(suiteName: "rating.\(UUID().uuidString)"))

    #expect(throws: Never.self) {
      try RatingMigration.run(context, defaults: defaults).get()
    }
    #expect(brew.ratingTenths == 70)
    #expect(unrated.ratingTenths == nil)
    #expect(bean.ratingTenths == 100)

    _ = RatingMigration.run(context, defaults: defaults)
    #expect(brew.ratingTenths == 70, "a second launch leaves it alone")
  }
}
