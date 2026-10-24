import Foundation
import NextCupKit
import SwiftData

enum BeanError: Error, Equatable {
  case emptyName
  case invalidBagWeight
  case invalidRemaining
  case alreadyFrozen
  case alreadyFrozenOnce
  case notFrozen
  case saveFailed(String)

  var message: String {
    switch self {
    case .alreadyFrozen: "This bag is already in the freezer."
    case .alreadyFrozenOnce:
      "This bag has already had its freezer stay. Next Cup keeps one freezer stay per bag."
    case .notFrozen: "This bag is not in the freezer."
    case .emptyName: "Give the bean a name."
    case .invalidBagWeight: "The bag weight must be more than zero."
    case .invalidRemaining: "Enter how much is left, from zero up. This bag has no weight yet."
    case .saveFailed(let reason): "The change could not be saved: \(reason)"
    }
  }
}

/// The values the bean editor edits. Weight is in grams: the view converts from
/// the user's unit before it gets here (X8).
struct BeanFields: Equatable {
  var name = ""
  var roasterName = ""
  var originCountry = ""
  var region = ""
  var farm = ""
  var process = ""
  var varietal = ""
  var roastLevel: RoastLevel?
  var roastDate: Date?
  var flavorNotes = ""
  var bagWeightG: Double?
  var status = BeanStatus.inUse
  var isDecaf = false

  init() {}

  init(_ bean: Bean) {
    name = bean.name
    roasterName = bean.roaster?.name ?? ""
    originCountry = bean.originCountry ?? ""
    region = bean.region ?? ""
    farm = bean.farm ?? ""
    process = bean.process ?? ""
    varietal = bean.varietal ?? ""
    roastLevel = bean.roastLevel
    roastDate = bean.roastDate
    flavorNotes = bean.bagFlavorNotes.joined(separator: ", ")
    bagWeightG = bean.bagWeightG
    status = bean.status
    isDecaf = bean.isDecaf
  }

  /// Notes typed as "jasmine, peach; honey" become separate, de-duplicated notes.
  static func notes(from text: String) -> [String] {
    var seen = Set<String>()
    return text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
  }
}

/// Add, change, move and delete beans (S03, S04). A failed write is rolled back
/// and returned, so the library never shows a change that was not kept. Deleting
/// a bean keeps every brew: each keeps the bean's name as logged.
@MainActor
struct BeanService {
  let store: Store

  private var context: ModelContext { store.context }

  @discardableResult
  func save(_ fields: BeanFields, editing bean: Bean? = nil) -> Result<Bean, BeanError> {
    let name = fields.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty { return .failure(.emptyName) }
    if let weight = fields.bagWeightG, weight <= 0 { return .failure(.invalidBagWeight) }

    let target = bean ?? Bean()
    if bean == nil { context.insert(target) }
    target.name = name
    target.originCountry = Self.clean(fields.originCountry)
    target.region = Self.clean(fields.region)
    target.farm = Self.clean(fields.farm)
    target.process = Self.clean(fields.process)
    target.varietal = Self.clean(fields.varietal)
    target.roastLevel = fields.roastLevel
    target.roastDate = fields.roastDate
    target.bagFlavorNotes = BeanFields.notes(from: fields.flavorNotes)
    target.bagWeightG = fields.bagWeightG
    target.status = fields.status
    target.isDecaf = fields.isDecaf
    target.roaster = roaster(named: fields.roasterName)
    target.updatedAt = Date()
    return commit { target }
  }

  func setStatus(_ bean: Bean, _ status: BeanStatus) -> Result<Void, BeanError> {
    bean.status = status
    bean.updatedAt = Date()
    return commit { () }
  }

  /// Puts the bag in the freezer: from `date` its days stop counting toward age
  /// (X6). One freezer stay is kept per bag, so a second freeze is refused instead
  /// of silently dropping the first stay's days from the age.
  func freeze(_ bean: Bean, on date: Date = Date()) -> Result<Void, BeanError> {
    if bean.frozenOn != nil {
      return .failure(bean.thawedOn == nil ? .alreadyFrozen : .alreadyFrozenOnce)
    }
    bean.frozenOn = date
    bean.thawedOn = nil
    bean.updatedAt = Date()
    return commit { () }
  }

  /// Takes the bag out; its days count toward age again from `date`.
  func thaw(_ bean: Bean, on date: Date = Date()) -> Result<Void, BeanError> {
    guard let frozenOn = bean.frozenOn, bean.thawedOn == nil else { return .failure(.notFrozen) }
    bean.thawedOn = max(date, frozenOn)
    bean.updatedAt = Date()
    return commit { () }
  }

  /// Makes the remaining amount equal `grams` by adjusting the correction, so
  /// brews already logged are never rewritten.
  func setRemaining(_ bean: Bean, grams: Double) -> Result<Void, BeanError> {
    guard
      let adjustment = BeanStock.adjustmentG(
        settingRemainingTo: grams, bagWeightG: bean.bagWeightG, usedG: bean.usedG)
    else { return .failure(.invalidRemaining) }
    bean.remainingAdjustmentG = adjustment
    bean.updatedAt = Date()
    return commit { () }
  }

  func delete(_ bean: Bean) -> Result<Void, BeanError> {
    context.delete(bean)
    return commit { () }
  }

  // MARK: Private

  private static func clean(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// The roaster with this name (any case), created if none exists. An empty name
  /// means no roaster.
  private func roaster(named name: String) -> Roaster? {
    guard let clean = Self.clean(name) else { return nil }
    let existing = (try? context.fetch(FetchDescriptor<Roaster>())) ?? []
    if let match = existing.first(where: {
      $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }) {
      return match
    }
    let created = Roaster(name: clean)
    context.insert(created)
    return created
  }

  private func commit<T>(_ value: () -> T) -> Result<T, BeanError> {
    switch store.save() {
    case .success:
      return .success(value())
    case .failure(.saveFailed(let reason)):
      context.rollback()
      return .failure(.saveFailed(reason))
    }
  }
}
