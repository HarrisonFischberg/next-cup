import Foundation
import SwiftData

/// One row of the export, as plain values. Relationships are ids, so the JSON
/// archive is lossless and each record can be compared with the row it matches.
protocol ArchiveRecord: Codable, Equatable, Sendable {
  associatedtype Model: Identified

  static var label: String { get }
  var id: UUID { get set }
  var createdAt: Date { get set }
  var updatedAt: Date { get set }
  var title: String { get }

  init(_ model: Model)
  func make() -> Model
  /// Copies the plain values onto `model`.
  func copy(to model: Model)
  /// Points the relationships at rows found through `lookup`.
  func link(_ model: Model, _ lookup: ModelLookup)
}

extension ArchiveRecord {
  /// The record without its timestamps: two rows with the same content are the
  /// same even when one was reseeded later.
  var core: Self {
    var copy = self
    copy.createdAt = .distantPast
    copy.updatedAt = .distantPast
    return copy
  }
}

/// Finds rows by id while an import links relationships.
final class ModelLookup {
  private var models: [UUID: any Identified] = [:]

  func register(_ model: some Identified) { models[model.id] = model }

  func find<M: Identified>(_ id: UUID?, _ type: M.Type = M.self) -> M? {
    id.flatMap { models[$0] as? M }
  }
}

/// The whole export. `version` is bumped when the shape changes; an archive from
/// a newer app is refused instead of half-read.
struct DataArchive: Codable, Equatable, Sendable {
  /// 2: ratings are tenths out of 10 (`ratingTenths`); version 1 had half points out of 5.
  static let currentVersion = 2

  var version = DataArchive.currentVersion
  var exportedAt = Date()
  var methods: [MethodRecord] = []
  var grinders: [GrinderRecord] = []
  var roasters: [RoasterRecord] = []
  var waterProfiles: [WaterProfileRecord] = []
  var aliases: [AliasRecord] = []
  var recipes: [RecipeRecord] = []
  var steps: [StepRecord] = []
  var beans: [BeanRecord] = []
  var brews: [BrewRecord] = []
  var brewBeans: [BrewBeanRecord] = []
  var suggestions: [SuggestionRecord] = []

  /// Every list in the order rows are inserted.
  @MainActor var lists: [any RecordList] {
    [
      methods, grinders, roasters, waterProfiles, aliases, recipes, steps, beans, brews,
      brewBeans, suggestions,
    ]
  }
}

// MARK: Records

struct MethodRecord: ArchiveRecord {
  static let label = "Methods"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var style: BrewStyle
  var symbol: String
  var trackedParameters: [BrewParameter]
  var defaultStepKinds: [StepKind]
  var sortOrder: Int
  var isHidden: Bool
  var builtInKey: String?
  var title: String { name }

  init(_ m: BrewMethod) {
    (id, createdAt, updatedAt) = (m.id, m.createdAt, m.updatedAt)
    (name, style, symbol, trackedParameters) = (m.name, m.style, m.symbol, m.trackedParameters)
    (defaultStepKinds, sortOrder, isHidden) = (m.defaultStepKinds, m.sortOrder, m.isHidden)
    builtInKey = m.builtInKey
  }

  func make() -> BrewMethod { BrewMethod() }

  func copy(to m: BrewMethod) {
    (m.name, m.style, m.symbol, m.trackedParameters) = (name, style, symbol, trackedParameters)
    (m.defaultStepKinds, m.sortOrder, m.isHidden) = (defaultStepKinds, sortOrder, isHidden)
    m.builtInKey = builtInKey
  }

  func link(_ m: BrewMethod, _ lookup: ModelLookup) {}
}

struct GrinderRecord: ArchiveRecord {
  static let label = "Grinders"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var notes: String?
  var title: String { name }

  init(_ g: Grinder) {
    (id, createdAt, updatedAt, name, notes) = (g.id, g.createdAt, g.updatedAt, g.name, g.notes)
  }

  func make() -> Grinder { Grinder() }
  func copy(to g: Grinder) { (g.name, g.notes) = (name, notes) }
  func link(_ g: Grinder, _ lookup: ModelLookup) {}
}

struct RoasterRecord: ArchiveRecord {
  static let label = "Roasters"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var city: String?
  var website: URL?
  var latitude: Double?
  var longitude: Double?
  var savedFromMap: Bool
  var title: String { name }

  init(_ r: Roaster) {
    (id, createdAt, updatedAt, name) = (r.id, r.createdAt, r.updatedAt, r.name)
    (city, website, latitude, longitude) = (r.city, r.website, r.latitude, r.longitude)
    savedFromMap = r.savedFromMap
  }

  func make() -> Roaster { Roaster() }

  func copy(to r: Roaster) {
    (r.name, r.city, r.website) = (name, city, website)
    (r.latitude, r.longitude, r.savedFromMap) = (latitude, longitude, savedFromMap)
  }

  func link(_ r: Roaster, _ lookup: ModelLookup) {}
}

struct WaterProfileRecord: ArchiveRecord {
  static let label = "Water profiles"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var ppmHardness: Double?
  var ppmAlkalinity: Double?
  var calcium: Double?
  var magnesium: Double?
  var sodium: Double?
  var title: String { name }

  init(_ w: WaterProfile) {
    (id, createdAt, updatedAt, name) = (w.id, w.createdAt, w.updatedAt, w.name)
    (ppmHardness, ppmAlkalinity) = (w.ppmHardness, w.ppmAlkalinity)
    (calcium, magnesium, sodium) = (w.calcium, w.magnesium, w.sodium)
  }

  func make() -> WaterProfile { WaterProfile() }

  func copy(to w: WaterProfile) {
    w.name = name
    (w.ppmHardness, w.ppmAlkalinity) = (ppmHardness, ppmAlkalinity)
    (w.calcium, w.magnesium, w.sodium) = (calcium, magnesium, sodium)
  }

  func link(_ w: WaterProfile, _ lookup: ModelLookup) {}
}

struct AliasRecord: ArchiveRecord {
  static let label = "Taxonomy aliases"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var dimension: TaxonomyDimension
  var rawValue: String
  var bucketKey: String
  var title: String { rawValue }

  init(_ a: TaxonomyAlias) {
    (id, createdAt, updatedAt) = (a.id, a.createdAt, a.updatedAt)
    (dimension, rawValue, bucketKey) = (a.dimension, a.rawValue, a.bucketKey)
  }

  func make() -> TaxonomyAlias { TaxonomyAlias() }
  func copy(to a: TaxonomyAlias) {
    (a.dimension, a.rawValue, a.bucketKey) = (dimension, rawValue, bucketKey)
  }
  func link(_ a: TaxonomyAlias, _ lookup: ModelLookup) {}
}

struct RecipeRecord: ArchiveRecord {
  static let label = "Recipes"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var credit: String?
  var creditURL: URL?
  var doseG: Double
  var waterG: Double
  var tempC: Double?
  var totalTimeS: Int?
  var tuningNote: String?
  var includesIce: Bool
  var iceG: Double?
  var builtInKey: String?
  var methodID: UUID?
  var title: String { name }

  init(_ r: Recipe) {
    (id, createdAt, updatedAt, name) = (r.id, r.createdAt, r.updatedAt, r.name)
    (credit, creditURL, doseG, waterG) = (r.credit, r.creditURL, r.doseG, r.waterG)
    (tempC, totalTimeS, tuningNote) = (r.tempC, r.totalTimeS, r.tuningNote)
    (includesIce, iceG, builtInKey, methodID) = (r.includesIce, r.iceG, r.builtInKey, r.method?.id)
  }

  func make() -> Recipe { Recipe() }

  func copy(to r: Recipe) {
    (r.name, r.credit, r.creditURL, r.doseG, r.waterG) = (name, credit, creditURL, doseG, waterG)
    (r.tempC, r.totalTimeS, r.tuningNote) = (tempC, totalTimeS, tuningNote)
    (r.includesIce, r.iceG, r.builtInKey) = (includesIce, iceG, builtInKey)
  }

  func link(_ r: Recipe, _ lookup: ModelLookup) { r.method = lookup.find(methodID) }
}

struct StepRecord: ArchiveRecord {
  static let label = "Recipe steps"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var order: Int
  var kind: StepKind
  var startOffsetS: Int
  var targetCumulativeWaterG: Double?
  var instruction: String
  var recipeID: UUID?
  var title: String { instruction.isEmpty ? kind.rawValue : instruction }

  init(_ s: RecipeStep) {
    (id, createdAt, updatedAt) = (s.id, s.createdAt, s.updatedAt)
    (order, kind, startOffsetS) = (s.order, s.kind, s.startOffsetS)
    (targetCumulativeWaterG, instruction, recipeID) = (
      s.targetCumulativeWaterG, s.instruction, s.recipe?.id
    )
  }

  func make() -> RecipeStep { RecipeStep() }

  func copy(to s: RecipeStep) {
    (s.order, s.kind, s.startOffsetS) = (order, kind, startOffsetS)
    (s.targetCumulativeWaterG, s.instruction) = (targetCumulativeWaterG, instruction)
  }

  func link(_ s: RecipeStep, _ lookup: ModelLookup) { s.recipe = lookup.find(recipeID) }
}

struct BeanRecord: ArchiveRecord {
  static let label = "Beans"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var name: String
  var originCountry: String?
  var region: String?
  var farm: String?
  var process: String?
  var varietal: String?
  var roastLevel: RoastLevel?
  var roastDate: Date?
  var bagFlavorNotes: [String]
  var bagWeightG: Double?
  var remainingAdjustmentG: Double
  var status: BeanStatus
  var isDecaf: Bool
  var frozenOn: Date?
  var thawedOn: Date?
  var ratingTenths: Int?
  /// Version 1 archives: half points out of 5, read once on import.
  var ratingHalfSteps: Int?
  var photo: Data?
  var roasterID: UUID?
  var title: String { name }

  init(_ b: Bean) {
    (id, createdAt, updatedAt, name) = (b.id, b.createdAt, b.updatedAt, b.name)
    (originCountry, region, farm) = (b.originCountry, b.region, b.farm)
    (process, varietal, roastLevel, roastDate) = (b.process, b.varietal, b.roastLevel, b.roastDate)
    (bagFlavorNotes, bagWeightG) = (b.bagFlavorNotes, b.bagWeightG)
    (remainingAdjustmentG, status, isDecaf) = (b.remainingAdjustmentG, b.status, b.isDecaf)
    (frozenOn, thawedOn, ratingTenths) = (b.frozenOn, b.thawedOn, b.ratingTenths)
    (photo, roasterID) = (b.photo, b.roaster?.id)
  }

  func make() -> Bean { Bean() }

  func copy(to b: Bean) {
    (b.name, b.originCountry, b.region, b.farm) = (name, originCountry, region, farm)
    (b.process, b.varietal, b.roastLevel, b.roastDate) = (process, varietal, roastLevel, roastDate)
    (b.bagFlavorNotes, b.bagWeightG) = (bagFlavorNotes, bagWeightG)
    (b.remainingAdjustmentG, b.status, b.isDecaf) = (remainingAdjustmentG, status, isDecaf)
    (b.frozenOn, b.thawedOn, b.ratingTenths, b.photo) = (
      frozenOn, thawedOn, ratingTenths ?? ratingHalfSteps.map { $0 * 10 }, photo
    )
  }

  func link(_ b: Bean, _ lookup: ModelLookup) { b.roaster = lookup.find(roasterID) }
}

struct BrewRecord: ArchiveRecord {
  static let label = "Brews"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var date: Date
  var doseG: Double?
  var waterG: Double?
  var yieldG: Double?
  var grindSetting: String?
  var grindValue: Double?
  var tempC: Double?
  var totalTimeS: Int?
  var tds: Double?
  var ratingTenths: Int?
  /// Version 1 archives: half points out of 5, read once on import.
  var ratingHalfSteps: Int?
  var verdict: Verdict?
  var notes: String
  var photo: Data?
  var targetsJSON: Data?
  var isDraft: Bool
  var methodID: UUID?
  var recipeID: UUID?
  var grinderID: UUID?
  var waterProfileID: UUID?
  var suggestionFollowedID: UUID?
  var title: String { date.formatted(date: .abbreviated, time: .shortened) }

  init(_ b: Brew) {
    (id, createdAt, updatedAt, date) = (b.id, b.createdAt, b.updatedAt, b.date)
    (doseG, waterG, yieldG) = (b.doseG, b.waterG, b.yieldG)
    (grindSetting, grindValue, tempC, totalTimeS) = (
      b.grindSetting, b.grindValue, b.tempC, b.totalTimeS
    )
    (tds, ratingTenths, verdict, notes) = (b.tds, b.ratingTenths, b.verdict, b.notes)
    (photo, targetsJSON, isDraft) = (b.photo, b.targetsJSON, b.isDraft)
    (methodID, recipeID, grinderID) = (b.method?.id, b.recipe?.id, b.grinder?.id)
    (waterProfileID, suggestionFollowedID) = (b.waterProfile?.id, b.suggestionFollowed?.id)
  }

  func make() -> Brew { Brew() }

  func copy(to b: Brew) {
    (b.date, b.doseG, b.waterG, b.yieldG) = (date, doseG, waterG, yieldG)
    (b.grindSetting, b.grindValue, b.tempC, b.totalTimeS) = (
      grindSetting, grindValue, tempC, totalTimeS
    )
    (b.tds, b.ratingTenths, b.verdict, b.notes) = (
      tds, ratingTenths ?? ratingHalfSteps.map { $0 * 10 }, verdict, notes
    )
    (b.photo, b.targetsJSON, b.isDraft) = (photo, targetsJSON, isDraft)
  }

  func link(_ b: Brew, _ lookup: ModelLookup) {
    b.method = lookup.find(methodID)
    b.recipe = lookup.find(recipeID)
    b.grinder = lookup.find(grinderID)
    b.waterProfile = lookup.find(waterProfileID)
    b.suggestionFollowed = lookup.find(suggestionFollowedID)
  }
}

struct BrewBeanRecord: ArchiveRecord {
  static let label = "Beans in brews"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var grams: Double
  var beanNameSnapshot: String
  var brewID: UUID?
  var beanID: UUID?
  var title: String { beanNameSnapshot }

  init(_ u: BrewBean) {
    (id, createdAt, updatedAt) = (u.id, u.createdAt, u.updatedAt)
    (grams, beanNameSnapshot, brewID, beanID) = (
      u.grams, u.beanNameSnapshot, u.brew?.id, u.bean?.id
    )
  }

  func make() -> BrewBean { BrewBean() }
  func copy(to u: BrewBean) { (u.grams, u.beanNameSnapshot) = (grams, beanNameSnapshot) }

  func link(_ u: BrewBean, _ lookup: ModelLookup) {
    u.brew = lookup.find(brewID)
    u.bean = lookup.find(beanID)
  }
}

struct SuggestionRecord: ArchiveRecord {
  static let label = "Suggestions"
  var id: UUID
  var createdAt: Date
  var updatedAt: Date
  var source: SuggestionSource
  var field: BrewParameter
  var fromValue: String
  var toValue: String
  var rationale: String
  var state: SuggestionState
  var modelID: String?
  var sourceBrewID: UUID?
  var title: String { "\(field.rawValue): \(fromValue) → \(toValue)" }

  init(_ s: Suggestion) {
    (id, createdAt, updatedAt) = (s.id, s.createdAt, s.updatedAt)
    (source, field, fromValue, toValue) = (s.source, s.field, s.fromValue, s.toValue)
    (rationale, state, modelID, sourceBrewID) = (s.rationale, s.state, s.modelID, s.sourceBrew?.id)
  }

  func make() -> Suggestion { Suggestion() }

  func copy(to s: Suggestion) {
    (s.source, s.field, s.fromValue, s.toValue) = (source, field, fromValue, toValue)
    (s.rationale, s.state, s.modelID) = (rationale, state, modelID)
  }

  func link(_ s: Suggestion, _ lookup: ModelLookup) { s.sourceBrew = lookup.find(sourceBrewID) }
}
