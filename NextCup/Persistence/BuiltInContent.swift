import Foundation

/// Decoded form of the bundled `methods.json` and `recipes.json`. The bundle is
/// original content written for Next Cup (blueprint §2). `version` only grows;
/// the seeder keys on `key`, never on version, so it stays idempotent.
struct BuiltInContent: Sendable, Equatable {
  struct MethodEntry: Codable, Sendable, Equatable {
    var key: String
    var name: String
    var style: BrewStyle
    var symbol: String
    var trackedParameters: [BrewParameter]
    var defaultStepKinds: [StepKind]
  }

  struct StepEntry: Codable, Sendable, Equatable {
    var kind: StepKind
    var startOffsetS: Int
    var targetCumulativeWaterG: Double?
    var instruction: String
  }

  struct RecipeEntry: Codable, Sendable, Equatable {
    var key: String
    var methodKey: String
    var name: String
    var doseG: Double
    var waterG: Double
    var tempC: Double?
    var totalTimeS: Int?
    var tuningNote: String?
    var includesIce: Bool
    var iceG: Double?
    var steps: [StepEntry]
  }

  var methodsVersion: Int
  var methods: [MethodEntry]
  var recipesVersion: Int
  var recipes: [RecipeEntry]

  private struct MethodsFile: Decodable {
    var version: Int
    var methods: [MethodEntry]
  }

  private struct RecipesFile: Decodable {
    var version: Int
    var recipes: [RecipeEntry]
  }

  enum LoadError: Error, Equatable {
    case missingResource(String)
  }

  /// Parses the two JSON documents. Throws on malformed or unknown enum values so
  /// a bad bundle fails loudly in tests, not silently at seed time.
  init(methodsJSON: Data, recipesJSON: Data) throws {
    let decoder = JSONDecoder()
    let methodsFile = try decoder.decode(MethodsFile.self, from: methodsJSON)
    let recipesFile = try decoder.decode(RecipesFile.self, from: recipesJSON)
    methodsVersion = methodsFile.version
    methods = methodsFile.methods
    recipesVersion = recipesFile.version
    recipes = recipesFile.recipes
  }

  init(bundle: Bundle = .main) throws {
    func data(_ name: String) throws -> Data {
      guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw LoadError.missingResource(name)
      }
      return try Data(contentsOf: url)
    }
    try self.init(methodsJSON: data("methods"), recipesJSON: data("recipes"))
  }
}
