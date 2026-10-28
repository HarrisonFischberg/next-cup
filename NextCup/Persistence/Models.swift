import Foundation
import SwiftData

/// Every model carries a stable `id` (survives export and import) and UTC
/// timestamps. `id` uniqueness is enforced by `Store.upsert`, not by the schema,
/// so the schema stays CloudKit-compatible (blueprint §2).
protocol Identified: PersistentModel {
  var id: UUID { get set }
  var createdAt: Date { get set }
  var updatedAt: Date { get set }
}

@Model
final class Brew: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var date: Date = Date()
  var doseG: Double?
  var waterG: Double?
  /// Unused: espresso output weight is kept in `waterG`. Kept so the schema stays valid.
  var yieldG: Double?
  var grindSetting: String?
  var grindValue: Double?
  var tempC: Double?
  var totalTimeS: Int?
  var tds: Double?
  /// 0 to 100: the rating out of 10 in tenths. Stored under its old name, when it held
  /// half points out of 5; `RatingMigration` converted those once.
  @Attribute(originalName: "ratingHalfSteps") var ratingTenths: Int?
  /// The first taste picked; dial-in and the journal's colours follow it.
  var verdict: Verdict?
  /// Further tastes picked with `verdict`, as raw values: a cup can be sour and weak.
  var alsoTasted: [String]?
  var notes: String = ""
  @Attribute(.externalStorage) var photo: Data?
  var targetsJSON: Data?
  /// Unused: drafts live in files (`DraftStore`). Kept so the schema and old archives stay valid.
  var isDraft: Bool = false

  /// Every taste picked, the first one first.
  var verdicts: [Verdict] {
    (verdict.map { [$0] } ?? []) + (alsoTasted ?? []).compactMap(Verdict.init(rawValue:))
  }

  var method: BrewMethod?
  var recipe: Recipe?
  var grinder: Grinder?
  @Relationship(deleteRule: .cascade, inverse: \BrewBean.brew) var beans: [BrewBean]?
  var waterProfile: WaterProfile?
  @Relationship(deleteRule: .cascade, inverse: \Suggestion.sourceBrew)
  var suggestionsMade: [Suggestion]?
  var suggestionFollowed: Suggestion?
  @Relationship(deleteRule: .cascade, inverse: \AIRequest.brew) var aiRequests: [AIRequest]?

  init(id: UUID = UUID(), date: Date = Date()) {
    self.id = id
    self.date = date
  }
}

@Model
final class BrewBean: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var grams: Double = 0
  var beanNameSnapshot: String = ""

  var brew: Brew?
  var bean: Bean?

  init(id: UUID = UUID(), grams: Double = 0, beanNameSnapshot: String = "") {
    self.id = id
    self.grams = grams
    self.beanNameSnapshot = beanNameSnapshot
  }
}

@Model
final class Bean: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var originCountry: String?
  var region: String?
  var farm: String?
  var process: String?
  var varietal: String?
  var roastLevel: RoastLevel?
  var roastDate: Date?
  var bagFlavorNotes: [String] = []
  var bagWeightG: Double?
  var remainingAdjustmentG: Double = 0
  var status: BeanStatus = BeanStatus.inUse
  var isDecaf: Bool = false
  var frozenOn: Date?
  var thawedOn: Date?
  /// 0 to 100: the rating out of 10 in tenths. Stored under its old name, when it held
  /// half points out of 5; `RatingMigration` converted those once.
  @Attribute(originalName: "ratingHalfSteps") var ratingTenths: Int?
  @Attribute(.externalStorage) var photo: Data?

  var roaster: Roaster?
  @Relationship(deleteRule: .nullify, inverse: \BrewBean.bean) var brewUses: [BrewBean]?

  init(id: UUID = UUID(), name: String = "") {
    self.id = id
    self.name = name
  }
}

@Model
final class Roaster: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var city: String?
  var website: URL?
  var latitude: Double?
  var longitude: Double?
  var savedFromMap: Bool = false

  @Relationship(deleteRule: .nullify, inverse: \Bean.roaster) var beans: [Bean]?

  init(id: UUID = UUID(), name: String = "") {
    self.id = id
    self.name = name
  }
}

@Model
final class BrewMethod: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var style: BrewStyle = BrewStyle.pourOver
  var symbol: String = "cup.and.saucer"
  var trackedParameters: [BrewParameter] = []
  var defaultStepKinds: [StepKind] = []
  var sortOrder: Int = 0
  var isHidden: Bool = false
  var builtInKey: String?

  @Relationship(deleteRule: .nullify, inverse: \Recipe.method) var recipes: [Recipe]?
  @Relationship(deleteRule: .nullify, inverse: \Brew.method) var brews: [Brew]?

  init(id: UUID = UUID(), name: String = "", style: BrewStyle = .pourOver) {
    self.id = id
    self.name = name
    self.style = style
  }
}

@Model
final class Recipe: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var credit: String?
  var creditURL: URL?
  var doseG: Double = 0
  var waterG: Double = 0
  var tempC: Double?
  var totalTimeS: Int?
  var tuningNote: String?
  var includesIce: Bool = false
  var iceG: Double?
  var builtInKey: String?

  var method: BrewMethod?
  @Relationship(deleteRule: .cascade, inverse: \RecipeStep.recipe) var steps: [RecipeStep]?
  @Relationship(deleteRule: .nullify, inverse: \Brew.recipe) var brews: [Brew]?

  init(id: UUID = UUID(), name: String = "", doseG: Double = 0, waterG: Double = 0) {
    self.id = id
    self.name = name
    self.doseG = doseG
    self.waterG = waterG
  }
}

@Model
final class RecipeStep: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var order: Int = 0
  var kind: StepKind = StepKind.pour
  var startOffsetS: Int = 0
  var targetCumulativeWaterG: Double?
  var instruction: String = ""

  var recipe: Recipe?

  init(id: UUID = UUID(), order: Int = 0, kind: StepKind = .pour, startOffsetS: Int = 0) {
    self.id = id
    self.order = order
    self.kind = kind
    self.startOffsetS = startOffsetS
  }
}

@Model
final class Grinder: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var notes: String?

  @Relationship(deleteRule: .nullify, inverse: \Brew.grinder) var brews: [Brew]?

  init(id: UUID = UUID(), name: String = "") {
    self.id = id
    self.name = name
  }
}

@Model
final class Suggestion: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var source: SuggestionSource = SuggestionSource.rules
  var field: BrewParameter = BrewParameter.grind
  var fromValue: String = ""
  var toValue: String = ""
  var rationale: String = ""
  var state: SuggestionState = SuggestionState.proposed
  var modelID: String?

  var sourceBrew: Brew?
  @Relationship(deleteRule: .nullify, inverse: \Brew.suggestionFollowed) var appliedTo: [Brew]?

  init(id: UUID = UUID()) {
    self.id = id
  }
}

@Model
final class AIRequest: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var feature: AIFeature = AIFeature.diagnosis
  var provider: AIProvider = AIProvider.anthropic
  var modelID: String = ""
  var status: AIRequestStatus = AIRequestStatus.queued
  var payloadJSON: Data = Data()
  @Attribute(.externalStorage) var attachment: Data?
  var resultJSON: Data?
  var errorMessage: String?
  var attempts: Int = 0

  var brew: Brew?

  init(id: UUID = UUID()) {
    self.id = id
  }
}

@Model
final class TaxonomyAlias: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var dimension: TaxonomyDimension = TaxonomyDimension.origin
  var rawValue: String = ""
  var bucketKey: String = ""

  init(
    id: UUID = UUID(), dimension: TaxonomyDimension = .origin, rawValue: String = "",
    bucketKey: String = ""
  ) {
    self.id = id
    self.dimension = dimension
    self.rawValue = rawValue
    self.bucketKey = bucketKey
  }
}

@Model
final class WaterProfile: Identified {
  var id: UUID = UUID()
  var createdAt: Date = Date()
  var updatedAt: Date = Date()
  var name: String = ""
  var ppmHardness: Double?
  var ppmAlkalinity: Double?
  var calcium: Double?
  var magnesium: Double?
  var sodium: Double?

  @Relationship(deleteRule: .nullify, inverse: \Brew.waterProfile) var brews: [Brew]?

  init(id: UUID = UUID(), name: String = "") {
    self.id = id
    self.name = name
  }
}
