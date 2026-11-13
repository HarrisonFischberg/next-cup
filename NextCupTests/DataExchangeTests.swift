import Foundation
import SwiftData
import Testing

@testable import NextCup

@Suite(.serialized) @MainActor struct DataExchangeTests {
  private struct Env {
    let container: ModelContainer
    let store: Store
    let defaults: UserDefaults
    let suite: String
  }

  private func makeEnv() throws -> Env {
    let container = try NextCupContainer.make(inMemory: true)
    let suite = "DataExchangeTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let store = Store(context: container.mainContext)
    _ = BuiltInSeeder(store: store, defaults: defaults).seed(try BuiltInContent(bundle: .main))
    return Env(container: container, store: store, defaults: defaults, suite: suite)
  }

  private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "DataExchangeTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// A journal with a roaster, a blend, a custom recipe and a suggestion.
  @discardableResult
  private func populate(_ store: Store) throws -> Brew {
    let context = store.context
    let roaster = Roaster(name: "Synthetic Roasters")
    roaster.city = "Testville"
    context.insert(roaster)
    let beanA = Bean(name: "Test Bean A")
    beanA.roaster = roaster
    beanA.roastLevel = .light
    beanA.bagWeightG = 250
    beanA.roastDate = Date(timeIntervalSince1970: 1_700_000_000.123)
    beanA.photo = Data([1, 2, 3])
    context.insert(beanA)
    let beanB = Bean(name: "Test Bean B")
    context.insert(beanB)
    let grinder = Grinder(name: "Test Grinder")
    context.insert(grinder)
    let method = try #require(try context.fetch(FetchDescriptor<BrewMethod>()).first)
    let recipe = Recipe(name: "My recipe", doseG: 15, waterG: 250)
    recipe.method = method
    context.insert(recipe)
    let step = RecipeStep(order: 0, kind: .bloom, startOffsetS: 0)
    step.instruction = "Wet the bed"
    context.insert(step)
    step.recipe = recipe
    let brew = Brew(date: Date(timeIntervalSince1970: 1_700_000_100.5))
    brew.doseG = 15
    brew.waterG = 250
    brew.notes = "Sweet, \"bright\"\nsecond line"
    brew.verdict = .sour
    brew.ratingTenths = 7
    brew.method = method
    brew.recipe = recipe
    brew.grinder = grinder
    context.insert(brew)
    for (bean, grams) in [(beanA, 9.0), (beanB, 6.0)] {
      let use = BrewBean(grams: grams, beanNameSnapshot: bean.name)
      context.insert(use)
      use.brew = brew
      use.bean = bean
    }
    let suggestion = Suggestion()
    suggestion.field = .grind
    suggestion.fromValue = "20"
    suggestion.toValue = "18"
    context.insert(suggestion)
    suggestion.sourceBrew = brew
    context.insert(
      TaxonomyAlias(dimension: .origin, rawValue: "kenya aa", bucketKey: "east-africa"))
    try store.save().get()
    return brew
  }

  private func counts(_ context: ModelContext) throws -> [Int] {
    [
      try context.fetchCount(FetchDescriptor<Brew>()),
      try context.fetchCount(FetchDescriptor<BrewBean>()),
      try context.fetchCount(FetchDescriptor<Bean>()),
      try context.fetchCount(FetchDescriptor<Roaster>()),
      try context.fetchCount(FetchDescriptor<Recipe>()),
      try context.fetchCount(FetchDescriptor<RecipeStep>()),
      try context.fetchCount(FetchDescriptor<BrewMethod>()),
      try context.fetchCount(FetchDescriptor<Suggestion>()),
      try context.fetchCount(FetchDescriptor<TaxonomyAlias>()),
    ]
  }

  private func eraser(
    _ env: Env, drafts: URL, backups: BackupStore, keys: @escaping @MainActor () -> Void = {}
  )
    -> DataEraser
  {
    // No scratch folders: the real tmp holds the other tests' files.
    DataEraser(
      store: env.store, defaults: env.defaults, defaultsDomain: env.suite, draftsDirectory: drafts,
      backups: backups, clearKeys: keys, endActivity: {}, clearReminders: {},
      scratchDirectories: [], heldDrafts: tempDir().appendingPathComponent("Held"))
  }

  /// Delete all keeps the ratings flag, so the next launch does not convert ratings
  /// that are already out of 10 a second time.
  @Test func eraseKeepsRatingsOutOfTen() throws {
    let env = try makeEnv()
    env.defaults.set(true, forKey: RatingMigration.doneKey)
    let dir = tempDir()
    _ = try eraser(
      env, drafts: dir.appendingPathComponent("Drafts"),
      backups: BackupStore(directory: dir.appendingPathComponent("B"))
    ).eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()

    let brew = Brew()
    brew.ratingTenths = 85
    env.store.context.insert(brew)
    _ = try RatingMigration.run(env.store.context, defaults: env.defaults).get()
    #expect(brew.ratingTenths == 85)
  }

  /// Delete all keeps the recipe backfill flag, so a brew logged afterwards without a
  /// recipe is not linked to a look-alike recipe on the next launch.
  @Test func eraseKeepsTheRecipeBackfillDone() throws {
    let env = try makeEnv()
    env.defaults.set(true, forKey: RecipeSnapshotBackfill.doneKey)
    let dir = tempDir()
    _ = try eraser(
      env, drafts: dir.appendingPathComponent("Drafts"),
      backups: BackupStore(directory: dir.appendingPathComponent("B"))
    ).eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()

    let recipe = try #require(
      try env.store.context.fetch(FetchDescriptor<Recipe>()).first { $0.method != nil })
    let brew = Brew()
    (brew.method, brew.doseG, brew.waterG) = (recipe.method, recipe.doseG, recipe.waterG)
    env.store.context.insert(brew)
    _ = try RecipeSnapshotBackfill.run(env.store.context, defaults: env.defaults).get()
    #expect(brew.recipe == nil)
  }

  // MARK: Round trip

  @Test func exportWipeImportIsLossless() throws {
    let env = try makeEnv()
    try populate(env.store)
    let before = try DataExporter(store: env.store).archive()
    let data = try DataExporter.encode(before)
    let beforeCounts = try counts(env.store.context)

    let dir = tempDir()
    let result = eraser(
      env, drafts: dir.appendingPathComponent("Drafts"),
      backups: BackupStore(directory: dir.appendingPathComponent("B"))
    )
    .eraseAll(reseeding: try BuiltInContent(bundle: .main))
    _ = try result.get()
    #expect(try counts(env.store.context)[0] == 0)  // no brews survive the wipe

    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: try DataImporter.decode(data))
    #expect(plan.conflicts.isEmpty)
    _ = try importer.apply(plan).get()

    #expect(try counts(env.store.context) == beforeCounts)
    var after = try DataExporter(store: env.store).archive()
    var expected = before
    // Reseeded built-ins keep their new ids; everything the user made is identical.
    after.exportedAt = expected.exportedAt
    expected.methods = []
    after.methods = []
    expected.recipes = expected.recipes.filter { $0.builtInKey == nil }
    after.recipes = after.recipes.filter { $0.builtInKey == nil }
    let custom = Set(expected.recipes.map(\.id))
    expected.steps = expected.steps.filter { custom.contains($0.recipeID ?? UUID()) }
    after.steps = after.steps.filter { custom.contains($0.recipeID ?? UUID()) }
    expected.recipes = expected.recipes.map {
      var r = $0
      r.methodID = nil
      return r
    }
    after.recipes = after.recipes.map {
      var r = $0
      r.methodID = nil
      return r
    }
    expected.brews = expected.brews.map {
      var b = $0
      b.methodID = nil
      return b
    }
    after.brews = after.brews.map {
      var b = $0
      b.methodID = nil
      return b
    }
    #expect(after == expected)
  }

  @Test func importingTwiceChangesNothing() throws {
    let env = try makeEnv()
    try populate(env.store)
    let archive = try DataExporter(store: env.store).archive()
    let before = try counts(env.store.context)
    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: archive)
    #expect(plan.newCount == 0 && plan.conflicts.isEmpty)
    let summary = try importer.apply(plan).get()
    #expect(summary == ImportSummary(added: 0, replaced: 0))
    #expect(try counts(env.store.context) == before)
  }

  /// A file from before stars and recipe snapshots lacks those fields. That alone must not
  /// turn every brew and recipe into a conflict, or wipe a snapshot when it is chosen.
  @Test func olderExportWithoutNewerFieldsIsNotAConflict() throws {
    let env = try makeEnv()
    let brew = try populate(env.store)
    brew.snapshotRecipe()
    try env.store.save().get()
    var archive = try DataExporter(store: env.store).archive()
    for index in archive.recipes.indices { archive.recipes[index].isFavorite = nil }
    for index in archive.brews.indices {
      archive.brews[index].isFavorite = nil
      archive.brews[index].recipeSnapshotJSON = nil
    }
    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: archive)
    #expect(plan.newCount == 0 && plan.conflicts.isEmpty)
    _ = try importer.apply(plan, overwrite: [brew.id]).get()
    #expect(brew.recipeSnapshotJSON != nil)
  }

  // MARK: Conflicts

  @Test func conflictsKeepLocalUnlessChosen() throws {
    let env = try makeEnv()
    let brew = try populate(env.store)
    var archive = try DataExporter(store: env.store).archive()
    let index = try #require(archive.brews.firstIndex { $0.id == brew.id })
    archive.brews[index].notes = "Imported notes"
    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: archive)
    #expect(plan.conflicts.map(\.id) == [brew.id])

    _ = try importer.apply(plan).get()
    #expect(brew.notes != "Imported notes")

    let summary = try importer.apply(plan, overwrite: [brew.id]).get()
    #expect(summary.replaced == 1)
    #expect(brew.notes == "Imported notes")
  }

  /// Saving an edit gives a brew's beans and a recipe's steps new ids. Restoring an older
  /// export must not add the old rows next to them (the bag would be deducted twice).
  @Test func restoringAfterAnEditDoesNotDoubleBeansOrSteps() throws {
    let env = try makeEnv()
    let brew = try populate(env.store)
    let context = env.store.context
    let recipe = try #require(brew.recipe)
    let archive = try DataExporter(store: env.store).archive()

    for old in brew.beans ?? [] { context.delete(old) }
    let use = BrewBean(grams: 15, beanNameSnapshot: "Test Bean A")
    context.insert(use)
    use.brew = brew
    for old in recipe.steps ?? [] { context.delete(old) }
    for order in 0..<2 {
      let step = RecipeStep(order: order, kind: .pour, startOffsetS: order * 30)
      context.insert(step)
      step.recipe = recipe
    }
    recipe.name = "My recipe, edited"
    try env.store.save().get()

    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: archive)
    #expect(plan.newCount == 0)
    _ = try importer.apply(plan).get()
    #expect(brew.beans?.count == 1)
    #expect(recipe.steps?.count == 2)

    // Choosing the imported recipe and brew swaps their steps and beans back in.
    _ = try importer.apply(plan, overwrite: [recipe.id, brew.id]).get()
    #expect(recipe.steps?.map(\.instruction) == ["Wet the bed"])
    #expect((brew.beans ?? []).map(\.grams).sorted() == [6, 9])
  }

  /// A chosen recipe whose steps kept their ids (only its star changed) keeps its steps.
  @Test func choosingAnImportedRecipeKeepsStepsWithTheSameIDs() throws {
    let env = try makeEnv()
    let recipe = try #require(try populate(env.store).recipe)
    let archive = try DataExporter(store: env.store).archive()
    recipe.isFavorite = true
    try env.store.save().get()

    let importer = DataImporter(store: env.store)
    _ = try importer.apply(try importer.plan(for: archive), overwrite: [recipe.id]).get()
    #expect(!recipe.isFavorite)
    #expect(recipe.steps?.map(\.instruction) == ["Wet the bed"])
  }

  @Test func editedBuiltInIsAConflictNotADuplicate() throws {
    let env = try makeEnv()
    let method = try #require(try env.store.context.fetch(FetchDescriptor<BrewMethod>()).first)
    let key = try #require(method.builtInKey)
    var archive = try DataExporter(store: env.store).archive()
    // The file comes from another install: same built-in, different id and name.
    let index = try #require(archive.methods.firstIndex { $0.builtInKey == key })
    archive.methods[index].id = UUID()
    archive.methods[index].name = "Renamed elsewhere"
    let before = try env.store.context.fetchCount(FetchDescriptor<BrewMethod>())

    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: archive)
    #expect(plan.conflicts.map(\.id) == [method.id])
    _ = try importer.apply(plan).get()
    #expect(try env.store.context.fetchCount(FetchDescriptor<BrewMethod>()) == before)
    #expect(method.name != "Renamed elsewhere")
  }

  @Test func newerArchiveAndGarbageAreRefused() throws {
    #expect(throws: ImportError.unreadable) { try DataImporter.decode(Data("nope".utf8)) }
    var archive = DataArchive()
    archive.version = DataArchive.currentVersion + 1
    let data = try DataExporter.encode(archive)
    #expect(throws: ImportError.newerVersion(DataArchive.currentVersion + 1)) {
      try DataImporter.decode(data)
    }
  }

  // MARK: CSV

  @Test func csvQuotesAndNeutralisesFormulas() {
    let text = DataExporter.csv(
      [["name", "notes"], ["=SUM(A1)", "a, \"b\"\nc"], ["safe", "-1"]], textColumns: [0, 1])
    #expect(text == "name,notes\r\n'=SUM(A1),\"a, \"\"b\"\"\nc\"\r\nsafe,'-1\r\n")
  }

  @Test func exportWritesJSONAndCSVFiles() throws {
    let env = try makeEnv()
    try populate(env.store)
    let files = try DataExporter(store: env.store).write(into: tempDir())
    let brewsCSV = try String(contentsOf: files.csv[0], encoding: .utf8)
    #expect(brewsCSV.hasPrefix("id,date,method,recipe,beans"))
    #expect(brewsCSV.contains("Test Bean A; Test Bean B"))
    _ = try DataImporter.decode(Data(contentsOf: files.json))
  }

  // MARK: Backup

  @Test func backupKeepsSevenNewestAndOnePerDay() throws {
    let backups = BackupStore(directory: tempDir())
    let calendar = Calendar.current
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    for day in 0..<9 {
      let date = try #require(calendar.date(byAdding: .day, value: day, to: start))
      #expect(try backups.backUp(now: date) { Data("{}".utf8) } != nil)
    }
    #expect(backups.list().count == 7)
    // A second run on the same day writes nothing.
    #expect(try backups.backUp(now: start.addingTimeInterval(8 * 86_400)) { Data() } == nil)
    let names = backups.list().map(\.name)
    #expect(names == names.sorted(by: >))
    #expect(
      !names.contains {
        $0.hasSuffix(
          start.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day()))
      })
  }

  @Test func backupRestoresThroughThePreview() throws {
    let env = try makeEnv()
    try populate(env.store)
    let backups = BackupStore(directory: tempDir())
    let url = try #require(
      try backups.backUp { try DataExporter.encode(DataExporter(store: env.store).archive()) })
    let archive = try DataImporter.decode(Data(contentsOf: url))
    let plan = try DataImporter(store: env.store).plan(for: archive)
    #expect(plan.newCount == 0 && plan.conflicts.isEmpty)
  }

  // MARK: Delete all

  @Test func deleteAllClearsStoreDraftsBackupsKeysAndReseeds() throws {
    let env = try makeEnv()
    try populate(env.store)
    let dir = tempDir()
    let drafts = dir.appendingPathComponent("Drafts", isDirectory: true)
    try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: drafts.appendingPathComponent("brew-draft.json"))
    let backups = BackupStore(directory: dir.appendingPathComponent("Backups"))
    try backups.backUp { Data("{}".utf8) }
    env.defaults.set("x", forKey: "brew.lastMethodID")
    var keysCleared = false
    var activityEnded = false
    var remindersCleared = false
    let scratch = tempDir()
    try Data("x".utf8).write(to: scratch.appendingPathComponent("NextCupExport.json"))
    let external = tempDir()
    try Data("photo".utf8).write(to: external.appendingPathComponent("0001"))
    env.defaults.set(true, forKey: "ai.disclosure.accepted.anthropic")
    let aiRequest = AIRequest()
    env.store.context.insert(aiRequest)
    try env.store.save().get()

    var subject = eraser(env, drafts: drafts, backups: backups, keys: { keysCleared = true })
    subject.endActivity = { activityEnded = true }
    subject.clearReminders = { remindersCleared = true }
    subject.scratchDirectories = [scratch]
    subject.externalData = external
    let snapshot = try subject.eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()

    let context = env.store.context
    #expect(try context.fetchCount(FetchDescriptor<Brew>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Bean>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<TaxonomyAlias>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<BrewMethod>()) > 0)  // built-ins reseeded
    #expect(!FileManager.default.fileExists(atPath: drafts.path))
    #expect(backups.list().isEmpty)
    #expect(env.defaults.string(forKey: "brew.lastMethodID") == nil)
    #expect(keysCleared)
    #expect(activityEnded)
    #expect(remindersCleared)
    #expect(try context.fetchCount(FetchDescriptor<AIRequest>()) == 0)
    #expect(env.defaults.object(forKey: "ai.disclosure.accepted.anthropic") == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: scratch.path).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: external.path).isEmpty)
    #expect(snapshot.brews.count == 1)
  }

  @Test func releaseSettingsAreInTheInfoPlist() {
    let info = Bundle.main.infoDictionary
    #expect(info?["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    #expect(info?["NSLocationDefaultAccuracyReduced"] as? Bool == true)
  }

  @Test func undoAfterDeleteAllRestoresTheData() throws {
    let env = try makeEnv()
    try populate(env.store)
    let before = try counts(env.store.context)
    let dir = tempDir()
    let snapshot = try eraser(
      env, drafts: dir, backups: BackupStore(directory: dir.appendingPathComponent("B"))
    )
    .eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()
    let importer = DataImporter(store: env.store)
    let plan = try importer.plan(for: snapshot)
    _ = try importer.apply(plan, overwrite: Set(plan.conflicts.map(\.id))).get()
    #expect(try counts(env.store.context) == before)
  }

  /// Unsaved Brews wait out the Undo window: Undo brings them back, and they are deleted
  /// only when the window ends.
  @Test func draftsComeBackWithUndoAndGoWhenTheWindowEnds() throws {
    let env = try makeEnv()
    let dir = tempDir()
    let drafts = dir.appendingPathComponent("Drafts", isDirectory: true)
    let file = drafts.appendingPathComponent("brew-draft-1.json")
    try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: file)
    let subject = eraser(
      env, drafts: drafts, backups: BackupStore(directory: dir.appendingPathComponent("B")))

    _ = try subject.eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()
    #expect(!FileManager.default.fileExists(atPath: file.path))
    subject.restoreDrafts()
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(!FileManager.default.fileExists(atPath: subject.heldDrafts.path))

    _ = try subject.eraseAll(reseeding: try BuiltInContent(bundle: .main)).get()
    subject.dropHeldDrafts()
    subject.restoreDrafts()
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }
}
