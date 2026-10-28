import Foundation
import Security
import SwiftData

// Export, merge import, automatic backup and delete-all (blueprint §3a, §7).

// MARK: Export

@MainActor
struct DataExporter {
  struct Files: Equatable {
    let json: URL
    let csv: [URL]
  }

  let store: Store

  func archive(now: Date = Date()) throws -> DataArchive {
    func rows<M: Identified>(_ type: M.Type) throws -> [M] {
      // Sort keys are read once per row, not once per comparison.
      try store.context.fetch(FetchDescriptor<M>())
        .map { (row: $0, key: ($0.createdAt, $0.id.uuidString)) }
        .sorted { $0.key < $1.key }.map(\.row)
    }
    var archive = DataArchive(exportedAt: now)
    archive.methods = try rows(BrewMethod.self).map(MethodRecord.init)
    archive.grinders = try rows(Grinder.self).map(GrinderRecord.init)
    archive.roasters = try rows(Roaster.self).map(RoasterRecord.init)
    archive.waterProfiles = try rows(WaterProfile.self).map(WaterProfileRecord.init)
    archive.aliases = try rows(TaxonomyAlias.self).map(AliasRecord.init)
    archive.recipes = try rows(Recipe.self).map(RecipeRecord.init)
    archive.steps = try rows(RecipeStep.self).map(StepRecord.init)
    archive.beans = try rows(Bean.self).map(BeanRecord.init)
    archive.brews = try rows(Brew.self).map(BrewRecord.init)
    archive.brewBeans = try rows(BrewBean.self).map(BrewBeanRecord.init)
    archive.suggestions = try rows(Suggestion.self).map(SuggestionRecord.init)
    return archive
  }

  nonisolated static func encode(_ archive: DataArchive) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(archive)
  }

  /// Writes the JSON archive (lossless, importable) and two CSV files (for
  /// spreadsheets) into a fresh folder in `directory`.
  func write(into directory: URL, now: Date = Date()) throws -> Files {
    let folder = directory.appendingPathComponent("NextCupExport", isDirectory: true)
    try? FileManager.default.removeItem(at: folder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let stamp = now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    let json = folder.appendingPathComponent("NextCup-\(stamp).json")
    try Self.encode(try archive(now: now)).write(to: json, options: .atomic)
    let brews = folder.appendingPathComponent("brews.csv")
    let beans = folder.appendingPathComponent("beans.csv")
    try Data(try brewsCSV().utf8).write(to: brews, options: .atomic)
    try Data(try beansCSV().utf8).write(to: beans, options: .atomic)
    return Files(json: json, csv: [brews, beans])
  }

  func brewsCSV() throws -> String {
    let brews = try store.context.fetch(FetchDescriptor<Brew>(sortBy: [SortDescriptor(\.date)]))
    var rows = [
      [
        "id", "date", "method", "recipe", "beans", "grinder", "dose_g", "water_g", "temp_c",
        "time_s", "grind", "tds", "rating", "verdict", "notes",
      ]
    ]
    for brew in brews {
      rows.append([
        brew.id.uuidString, brew.date.formatted(.iso8601), brew.method?.name ?? "",
        brew.recipe?.name ?? "",
        (brew.beans ?? []).map { $0.bean?.name ?? $0.beanNameSnapshot }.sorted().joined(
          separator: "; "),
        brew.grinder?.name ?? "", Self.number(brew.doseG), Self.number(brew.waterG),
        Self.number(brew.tempC), brew.totalTimeS.map(String.init) ?? "",
        brew.grindSetting ?? "", Self.number(brew.tds),
        brew.ratingTenths.map { Self.number(Double($0) / 10) } ?? "",
        brew.verdicts.map(\.rawValue).joined(separator: "; "),
        brew.notes,
      ])
    }
    return Self.csv(rows, textColumns: [2, 3, 4, 5, 10, 14])
  }

  func beansCSV() throws -> String {
    let beans = try store.context.fetch(FetchDescriptor<Bean>(sortBy: [SortDescriptor(\.name)]))
    var rows = [
      [
        "id", "name", "roaster", "country", "region", "process", "varietal", "roast", "roast_date",
        "bag_g", "status", "decaf", "rating",
      ]
    ]
    for bean in beans {
      rows.append([
        bean.id.uuidString, bean.name, bean.roaster?.name ?? "", bean.originCountry ?? "",
        bean.region ?? "", bean.process ?? "", bean.varietal ?? "", bean.roastLevel?.rawValue ?? "",
        bean.roastDate?.formatted(.iso8601) ?? "", Self.number(bean.bagWeightG),
        bean.status.rawValue,
        bean.isDecaf ? "yes" : "no", bean.ratingTenths.map { Self.number(Double($0) / 10) } ?? "",
      ])
    }
    return Self.csv(rows, textColumns: [1, 2, 3, 4, 5, 6])
  }

  private static func number(_ value: Double?) -> String {
    value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? ""
  }

  /// RFC 4180 quoting. Free text that starts like a formula is prefixed with an
  /// apostrophe so a spreadsheet never runs it (CSV injection).
  static func csv(_ rows: [[String]], textColumns: Set<Int>) -> String {
    rows.enumerated().map { rowIndex, row in
      row.enumerated().map { column, cell in
        var text = cell
        if rowIndex > 0, textColumns.contains(column), let first = text.first,
          "=+-@\t\r".contains(first)
        {
          text = "'" + text
        }
        guard text.contains(where: { ",\"\n\r".contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
      }.joined(separator: ",")
    }.joined(separator: "\r\n") + "\r\n"
  }
}

// MARK: Import

struct ImportItem: Identifiable, Equatable, Sendable {
  enum Status: Sendable { case new, same, conflict }
  let id: UUID
  let label: String
  let title: String
  let status: Status
}

struct ImportSummary: Equatable {
  var added = 0
  var replaced = 0
}

enum ImportError: LocalizedError, Equatable {
  case unreadable
  case newerVersion(Int)

  var errorDescription: String? {
    switch self {
    case .unreadable: "This file is not a Next Cup export, so nothing was imported."
    case .newerVersion: "This export was made by a newer version of Next Cup. Update the app first."
    }
  }
}

/// What an import would do, shown before anything is written. Built-in methods
/// and recipes are matched by `builtInKey`, so a restore after delete-all lines
/// up with the reseeded built-ins instead of duplicating them.
struct ImportPlan {
  var archive: DataArchive
  /// Steps of built-in recipes that already exist here. They are only used when
  /// the user chooses the imported recipe, which then replaces the local steps.
  var adoptedSteps: [UUID: [StepRecord]] = [:]
  var items: [ImportItem] = []

  var conflicts: [ImportItem] { items.filter { $0.status == .conflict } }
  var newCount: Int { items.filter { $0.status == .new }.count }
  var sameCount: Int { items.filter { $0.status == .same }.count }
}

@MainActor
final class ImportSession {
  let store: Store
  let lookup = ModelLookup()
  var links: [() -> Void] = []
  var summary = ImportSummary()
  private var cache: [ObjectIdentifier: Any] = [:]

  init(store: Store) { self.store = store }

  func existing<M: Identified>(_ type: M.Type) throws -> [UUID: M] {
    if let cached = cache[ObjectIdentifier(type)] as? [UUID: M] { return cached }
    let rows = try store.context.fetch(FetchDescriptor<M>())
    let byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    cache[ObjectIdentifier(type)] = byID
    return byID
  }
}

@MainActor
protocol RecordList {
  func items(_ session: ImportSession) throws -> [ImportItem]
  func insert(_ session: ImportSession, overwrite: Set<UUID>) throws
}

extension Array: RecordList where Element: ArchiveRecord {
  func items(_ session: ImportSession) throws -> [ImportItem] {
    let existing = try session.existing(Element.Model.self)
    return map { record in
      let status: ImportItem.Status =
        existing[record.id].map { Element($0).core == record.core ? .same : .conflict } ?? .new
      return ImportItem(id: record.id, label: Element.label, title: record.title, status: status)
    }
  }

  func insert(_ session: ImportSession, overwrite: Set<UUID>) throws {
    var existing = try session.existing(Element.Model.self)
    for record in self {
      if let model = existing[record.id] {
        session.lookup.register(model)
        guard overwrite.contains(record.id), Element(model).core != record.core else { continue }
        record.copy(to: model)
        model.updatedAt = record.updatedAt
        session.links.append { [lookup = session.lookup] in record.link(model, lookup) }
        session.summary.replaced += 1
      } else {
        let model = record.make()
        model.id = record.id
        model.createdAt = record.createdAt
        model.updatedAt = record.updatedAt
        record.copy(to: model)
        session.store.context.insert(model)
        session.lookup.register(model)
        session.links.append { [lookup = session.lookup] in record.link(model, lookup) }
        existing[record.id] = model
        session.summary.added += 1
      }
    }
  }
}

@MainActor
struct DataImporter {
  let store: Store

  static func decode(_ data: Data) throws -> DataArchive {
    struct Header: Decodable { let version: Int }
    guard let header = try? JSONDecoder().decode(Header.self, from: data),
      let archive = try? JSONDecoder().decode(DataArchive.self, from: data)
    else { throw ImportError.unreadable }
    guard header.version <= DataArchive.currentVersion else {
      throw ImportError.newerVersion(header.version)
    }
    return archive
  }

  func plan(for incoming: DataArchive) throws -> ImportPlan {
    var archive = incoming
    var idMap: [UUID: UUID] = [:]
    let localMethods = try store.context.fetch(FetchDescriptor<BrewMethod>())
    let methodByKey = Dictionary(
      localMethods.compactMap { m in m.builtInKey.map { ($0, m.id) } },
      uniquingKeysWith: { first, _ in first })
    for index in archive.methods.indices {
      guard let key = archive.methods[index].builtInKey, let local = methodByKey[key] else {
        continue
      }
      idMap[archive.methods[index].id] = local
      archive.methods[index].id = local
    }
    let localRecipes = try store.context.fetch(FetchDescriptor<Recipe>())
    let recipeByKey = Dictionary(
      localRecipes.compactMap { r in r.builtInKey.map { ($0, r.id) } },
      uniquingKeysWith: { first, _ in first })
    var adopted: Set<UUID> = []
    for index in archive.recipes.indices {
      guard let key = archive.recipes[index].builtInKey, let local = recipeByKey[key] else {
        continue
      }
      idMap[archive.recipes[index].id] = local
      archive.recipes[index].id = local
      adopted.insert(local)
    }
    func mapped(_ id: UUID?) -> UUID? { id.map { idMap[$0] ?? $0 } }
    for index in archive.recipes.indices {
      archive.recipes[index].methodID = mapped(archive.recipes[index].methodID)
    }
    for index in archive.steps.indices {
      archive.steps[index].recipeID = mapped(archive.steps[index].recipeID)
    }
    for index in archive.brews.indices {
      archive.brews[index].methodID = mapped(archive.brews[index].methodID)
      archive.brews[index].recipeID = mapped(archive.brews[index].recipeID)
    }

    var plan = ImportPlan(archive: archive)
    for step in archive.steps {
      if let recipeID = step.recipeID, adopted.contains(recipeID) {
        plan.adoptedSteps[recipeID, default: []].append(step)
      }
    }
    plan.archive.steps.removeAll { step in step.recipeID.map(adopted.contains) ?? false }

    let session = ImportSession(store: store)
    plan.items = try plan.archive.lists.flatMap { try $0.items(session) }
    return plan
  }

  /// Writes the plan. Rows that differ from the matching local row are only
  /// replaced when their id is in `overwrite`; everything else is kept. A failed
  /// write is rolled back whole.
  func apply(_ plan: ImportPlan, overwrite: Set<UUID> = []) -> Result<ImportSummary, StoreError> {
    let session = ImportSession(store: store)
    var archive = plan.archive
    do {
      for recipeID in overwrite where plan.adoptedSteps[recipeID] != nil {
        for step in try session.existing(RecipeStep.self).values where step.recipe?.id == recipeID {
          store.context.delete(step)
        }
        archive.steps += plan.adoptedSteps[recipeID] ?? []
      }
      for list in archive.lists { try list.insert(session, overwrite: overwrite) }
      for link in session.links { link() }
      if case .failure(let error) = store.save() {
        store.context.rollback()
        return .failure(error)
      }
      return .success(session.summary)
    } catch {
      store.context.rollback()
      return .failure(.saveFailed(error.localizedDescription))
    }
  }
}

// MARK: Backup

/// Daily JSON backups in Application Support/Backups, newest seven kept.
struct BackupStore: Sendable {
  struct Backup: Identifiable, Equatable, Sendable {
    let url: URL
    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
  }

  let directory: URL
  var keep = 7

  static func standard() -> BackupStore {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return BackupStore(directory: base.appendingPathComponent("Backups", isDirectory: true))
  }

  /// Writes today's backup unless one exists, then drops all but the newest
  /// `keep`. Returns the new file, or `nil` when today already has one.
  @discardableResult
  func backUp(now: Date = Date(), make: () throws -> Data) throws -> URL? {
    let url = file(for: now)
    guard !FileManager.default.fileExists(atPath: url.path) else { return nil }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try make().write(to: url, options: [.atomic, .completeFileProtection])
    for old in list().dropFirst(keep) { try? FileManager.default.removeItem(at: old.url) }
    return url
  }

  /// Whether the day of `now` already has its backup.
  func hasBackup(for now: Date = Date()) -> Bool {
    FileManager.default.fileExists(atPath: file(for: now).path)
  }

  private func file(for now: Date) -> URL {
    let stamp = now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    return directory.appendingPathComponent("backup-\(stamp).json")
  }

  /// Newest first; the date is in the file name, so names sort by day.
  func list() -> [Backup] {
    let urls =
      (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))
      ?? []
    return urls.filter { $0.lastPathComponent.hasPrefix("backup-") && $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }.map(Backup.init)
  }

  func removeAll() throws {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    try FileManager.default.removeItem(at: directory)
  }
}

// MARK: Delete all

/// Wipes the store, drafts, backups, preferences and Keychain keys, then reseeds
/// the built-ins (blueprint §7). The returned snapshot lets the caller offer Undo
/// for the data; backups and keys are gone for good.
@MainActor
struct DataEraser {
  let store: Store
  let defaults: UserDefaults
  /// `UserDefaults` domain to clear: the bundle id, or a suite name in tests.
  let defaultsDomain: String
  let draftsDirectory: URL
  let backups: BackupStore
  var clearKeys: @MainActor () -> Void = DataEraser.clearKeychain
  var endActivity: @MainActor () -> Void = { LiveTimerActivity().end() }
  /// Folders whose contents are emptied: caches and tmp hold exports and AI photos.
  var scratchDirectories: [URL] = DataEraser.systemScratch
  /// SwiftData keeps photos and AI attachments as loose files here; `nil` for an
  /// in-memory store.
  var externalData: URL?

  static var systemScratch: [URL] {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
      + [FileManager.default.temporaryDirectory]
  }

  static func clearKeychain() {
    SecItemDelete([kSecClass: kSecClassGenericPassword] as CFDictionary)
  }

  /// `.<store name>_SUPPORT/_EXTERNAL_DATA` next to the store file.
  static func externalDataDirectory(of context: ModelContext) -> URL? {
    guard let url = context.container.configurations.first?.url else { return nil }
    return url.deletingLastPathComponent()
      .appendingPathComponent(".\(url.deletingPathExtension().lastPathComponent)_SUPPORT")
      .appendingPathComponent("_EXTERNAL_DATA", isDirectory: true)
  }

  private static func empty(_ directory: URL) {
    let items =
      try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for item in items ?? [] { try? FileManager.default.removeItem(at: item) }
  }

  func eraseAll(reseeding content: BuiltInContent) -> Result<DataArchive, StoreError> {
    do {
      let snapshot = try DataExporter(store: store).archive()
      let context = store.context
      try context.delete(model: Brew.self)
      try context.delete(model: BrewBean.self)
      try context.delete(model: Suggestion.self)
      try context.delete(model: AIRequest.self)
      try context.delete(model: Bean.self)
      try context.delete(model: Roaster.self)
      try context.delete(model: Recipe.self)
      try context.delete(model: RecipeStep.self)
      try context.delete(model: BrewMethod.self)
      try context.delete(model: Grinder.self)
      try context.delete(model: WaterProfile.self)
      try context.delete(model: TaxonomyAlias.self)
      if case .failure(let error) = store.save() {
        context.rollback()
        return .failure(error)
      }
      try? FileManager.default.removeItem(at: draftsDirectory)
      try backups.removeAll()
      endActivity()
      for directory in scratchDirectories + [externalData].compactMap({ $0 }) {
        Self.empty(directory)
      }
      // The selected tab stays, so the screen the user is on (and its Undo toast)
      // does not jump away. The rating flag stays, or the next launch would convert
      // ratings already out of 10 a second time.
      let tab = defaults.object(forKey: AppTab.storageKey)
      let ratingsMigrated = defaults.bool(forKey: RatingMigration.doneKey)
      defaults.removePersistentDomain(forName: defaultsDomain)
      if let tab { defaults.set(tab, forKey: AppTab.storageKey) }
      if ratingsMigrated { defaults.set(true, forKey: RatingMigration.doneKey) }
      clearKeys()
      return BuiltInSeeder(store: store, defaults: defaults).seed(content).map { _ in snapshot }
    } catch {
      store.context.rollback()
      return .failure(.saveFailed(error.localizedDescription))
    }
  }
}
