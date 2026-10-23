import Foundation
import NextCupKit

/// Turns stored beans and brews into the plain values `Recommender` reads. The
/// taxonomy maps every raw value; one the bundle and the user's aliases do not
/// know is left out here and offered for mapping in the Unmapped flow.
enum ExploreModel {
  /// The bundled taxonomy, loaded once. `nil` when the bundle is unreadable.
  static let taxonomy: Taxonomy? = try? Taxonomy(bundle: .main)

  static func aliases(_ stored: [TaxonomyAlias]) -> [Taxonomy.Alias] {
    stored.compactMap { alias in
      Taxonomy.Dimension(rawValue: alias.dimension.rawValue).map {
        Taxonomy.Alias(dimension: $0, rawValue: alias.rawValue, bucketKey: alias.bucketKey)
      }
    }
  }

  /// Origin, process, roast and flavor buckets of one bean.
  static func buckets(
    of bean: Bean, taxonomy: Taxonomy, aliases: [Taxonomy.Alias]
  ) -> [BucketRef] {
    let raws: [(Taxonomy.Dimension, [String])] = [
      (.origin, [bean.originCountry].compactMap { $0 }),
      (.process, [bean.process].compactMap { $0 }),
      (.roast, [bean.roastLevel?.rawValue].compactMap { $0 }),
      (.flavor, bean.bagFlavorNotes),
    ]
    return raws.flatMap { dimension, values in
      taxonomy.buckets(for: values, in: dimension, aliases: aliases).map {
        BucketRef($0, in: dimension)
      }
    }
  }

  /// Every saved brew that has a method, with the buckets of all beans in it.
  static func history(
    of brews: [Brew], taxonomy: Taxonomy, aliases: [Taxonomy.Alias]
  ) -> [RecommenderBrew] {
    brews.compactMap { brew in
      guard !brew.isDraft, let method = brew.method else { return nil }
      var seen = Set<BucketRef>()
      let buckets = (brew.beans ?? []).compactMap(\.bean).flatMap {
        buckets(of: $0, taxonomy: taxonomy, aliases: aliases)
      }.filter { seen.insert($0).inserted }
      return RecommenderBrew(
        date: brew.date, ratingHalfSteps: brew.ratingHalfSteps, methodKey: method.builtInKey,
        methodName: method.name, recipeName: brew.recipe?.name, doseG: brew.doseG,
        waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS,
        grindSetting: brew.grindSetting, buckets: buckets)
    }
  }

  /// Beans worth planning a brew for: the ones in use or marked to buy again.
  static func planned(_ beans: [Bean]) -> [Bean] {
    beans.filter { $0.status == .inUse || $0.status == .buyAgain }
  }
}
