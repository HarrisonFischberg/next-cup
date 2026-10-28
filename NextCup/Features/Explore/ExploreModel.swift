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

  /// Every saved brew made with a method the user brews with (not hidden), with the
  /// buckets of all beans in it. A hidden method is never recommended back.
  static func history(
    of brews: [Brew], taxonomy: Taxonomy, aliases: [Taxonomy.Alias]
  ) -> [RecommenderBrew] {
    // Many brews share a bean, so each bean is mapped through the taxonomy once.
    var byBean: [UUID: [BucketRef]] = [:]
    return brews.compactMap { brew in
      guard let method = brew.method, !method.isHidden else { return nil }
      var seen = Set<BucketRef>()
      let buckets = (brew.beans ?? []).compactMap(\.bean).flatMap { bean in
        if let known = byBean[bean.id] { return known }
        let mapped = Self.buckets(of: bean, taxonomy: taxonomy, aliases: aliases)
        byBean[bean.id] = mapped
        return mapped
      }.filter { seen.insert($0).inserted }
      return RecommenderBrew(
        date: brew.date, ratingTenths: brew.ratingTenths, methodKey: method.builtInKey,
        methodName: method.name, recipeName: brew.recipe?.name, doseG: brew.doseG,
        waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS,
        grindSetting: brew.grindSetting, buckets: buckets)
    }
  }

  /// Beans worth planning a brew for: the ones in use or marked to buy again.
  static func planned(_ beans: [Bean]) -> [Bean] {
    beans.filter { $0.status == .inUse || $0.status == .buyAgain }
  }

  /// Keeps a default pick to the brew types the user brews with: the bundled default
  /// becomes recipes of the shown methods, ones not brewed yet first, the default's
  /// own method ahead of the rest. History picks are already limited by `history`.
  static func limited(
    _ result: RecommendationResult, to methods: [BrewMethod], limit: Int = 3
  ) -> RecommendationResult {
    let shown = methods.filter { !$0.isHidden }
    guard result.isDefault, let fallback = result.items.first, let first = shown.first else {
      return result
    }
    let rank = { (method: BrewMethod, recipe: Recipe) in
      (
        recipe.brews?.count ?? 0, method.builtInKey == fallback.methodKey ? 0 : 1,
        method.sortOrder, recipe.name
      )
    }
    let picks = shown.flatMap { method in (method.recipes ?? []).map { (method, $0) } }
      .sorted { rank($0.0, $0.1) < rank($1.0, $1.1) }.prefix(limit)
      .map { method, recipe in
        Recommendation(
          methodKey: method.builtInKey, methodName: method.name, recipeName: recipe.name,
          start: StartParameters(
            doseG: recipe.doseG, waterG: recipe.waterG, tempC: recipe.tempC,
            totalTimeS: recipe.totalTimeS),
          basis: fallback.basis)
      }
    var limited = result
    if !picks.isEmpty {
      limited.items = Array(picks)
    } else if !shown.contains(where: { $0.builtInKey == fallback.methodKey }) {
      // No recipes to offer: keep the starting values, on a method the user brews with.
      limited.items = [
        Recommendation(
          methodKey: first.builtInKey, methodName: first.name, recipeName: nil,
          start: fallback.start, basis: fallback.basis)
      ]
    }
    return limited
  }
}
