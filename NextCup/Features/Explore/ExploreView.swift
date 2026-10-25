import NextCupKit
import SwiftData
import SwiftUI

/// The Explore tab: for each bean in use, which method and starting values the
/// recommender suggests and why. The explanation is built from facts the
/// recommender computed; with too few graded brews the card says it is a default.
struct ExploreView: View {
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
  @Query(filter: #Predicate<Brew> { !$0.isDraft }, sort: \Brew.date, order: .reverse)
  private var brews: [Brew]
  @Query private var storedAliases: [TaxonomyAlias]
  @Environment(\.modelContext) private var context
  @State private var insightsBean: Bean?
  @AppStorage(AppTab.storageKey) private var storedTab = AppTab.explore.rawValue
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  /// Saved brews that used this bean, newest first (the query is already sorted).
  private func brews(of bean: Bean) -> [Brew] {
    brews.filter { brew in (brew.beans ?? []).contains { $0.bean?.id == bean.id } }
  }

  var body: some View {
    Group {
      if let taxonomy = ExploreModel.taxonomy {
        content(taxonomy)
      } else {
        ScrollView {
          StateBanner(
            kind: .error,
            message:
              "The flavor vocabulary could not be read, so recommendations are unavailable. Reinstalling the app restores it."
          )
          .padding(DS.Space.lg)
          .accessibilityIdentifier("explore.error")
        }
      }
    }
    .background(DS.bg)
    .navigationTitle("Explore")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let taxonomy = ExploreModel.taxonomy {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            FlavorExplorerView(taxonomy: taxonomy)
          } label: {
            Label("Flavors", systemImage: "book")
          }
          .accessibilityIdentifier("explore.flavors")
        }
      }
    }
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the cards inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.explore")
    }
  }

  @ViewBuilder
  private func content(_ taxonomy: Taxonomy) -> some View {
    let planned = ExploreModel.planned(beans)
    if planned.isEmpty {
      ScrollView {
        EmptyState(
          title: "Nothing to plan yet",
          message:
            "Add a bean you are brewing and Explore suggests a method and starting values for it.",
          actionTitle: "Add a bean", action: { storedTab = AppTab.beans.rawValue })
      }
      .accessibilityIdentifier("explore.empty")
    } else {
      let aliases = ExploreModel.aliases(storedAliases)
      let history = ExploreModel.history(of: brews, taxonomy: taxonomy, aliases: aliases)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
          Text("NEXT CUP FOR YOUR BEANS").font(DS.Font.label).foregroundStyle(DS.ink2)
            .accessibilityAddTraits(.isHeader)
          ForEach(planned) { bean in
            let refs = ExploreModel.buckets(of: bean, taxonomy: taxonomy, aliases: aliases)
            BeanRecommendationCard(
              bean: bean, buckets: refs,
              result: Recommender.recommend(for: refs, history: history), units: units,
              canAsk: !brews(of: bean).isEmpty, onAsk: { insightsBean = bean })
          }
        }
        .padding(DS.Space.lg)
      }
      .sheet(item: $insightsBean) { bean in
        let history = brews(of: bean)
        if !history.isEmpty {
          AIAskView(
            model: AIAskModel(feature: .insights, brews: history, context: context),
            close: { insightsBean = nil })
        }
      }
      .accessibilityIdentifier("explore.list")
    }
  }
}

/// One bean with its ranked suggestions.
private struct BeanRecommendationCard: View {
  let bean: Bean
  let buckets: [BucketRef]
  let result: RecommendationResult
  let units: UnitPreferences
  let canAsk: Bool
  let onAsk: () -> Void

  var body: some View {
    PaperBox {
      VStack(alignment: .leading, spacing: 0) {
        header
        ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
          Hairline()
          RecommendationRow(
            item: item, rank: result.items.count > 1 ? index + 1 : nil, units: units)
        }
        Hairline()
        NavigationLink(value: DeepLink.newBrew) {
          Text("LOG A BREW").font(DS.Font.headline).foregroundStyle(DS.ink)
            .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
            .padding(.horizontal, DS.Space.md)
        }
        .accessibilityIdentifier("explore.brew.\(bean.name)")
        if canAsk {
          Hairline()
          Button(action: onAsk) {
            Text("ASK AI ABOUT THIS COFFEE").font(DS.Font.headline).foregroundStyle(DS.ink)
              .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
              .padding(.horizontal, DS.Space.md)
          }
          .accessibilityIdentifier("explore.insights.\(bean.name)")
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("explore.card.\(bean.name)")
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      NavigationLink(value: DeepLink.bean(bean.id)) {
        Text(bean.name.uppercased()).font(DS.Font.headline).foregroundStyle(DS.ink)
          .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
      }
      .accessibilityAddTraits(.isHeader)
      if !buckets.isEmpty {
        Text(buckets.map(\.name).joined(separator: "  ·  ")).font(.footnote)
          .foregroundStyle(DS.ink2)
      }
      Text(subtitle).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
        .accessibilityIdentifier("explore.basis.\(bean.name)")
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var subtitle: String {
    if result.isDefault {
      return
        "DEFAULT  ·  \(result.similarRatedCount) of \(Recommender.minimumSimilarBrews) graded similar brews"
    }
    return "FROM YOUR BREWS  ·  \(result.similarRatedCount) graded similar brews"
  }
}

private struct RecommendationRow: View {
  let item: Recommendation
  let rank: Int?
  let units: UnitPreferences

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
        if let rank { Text("\(rank)").font(DS.Font.data).foregroundStyle(DS.ink2) }
        Text(item.methodName.uppercased()).font(DS.Font.headline).foregroundStyle(DS.ink)
        if item.isDefault { Tag(text: "Default") }
      }
      if let recipe = item.recipeName {
        Text("Recipe: \(recipe)").font(.footnote).foregroundStyle(DS.ink2)
      }
      ForEach(Array(values.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .firstTextBaseline) {
          Text(row.0.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
          Spacer(minLength: DS.Space.sm)
          Text(row.1).font(DS.Font.data).foregroundStyle(DS.ink).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
      }
      Text(item.explanation).font(.callout).foregroundStyle(DS.ink2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var values: [(String, String)] {
    let start = item.start
    return [
      ("Dose", start.doseG.map { RecipeFormat.weight($0, units) }),
      ("Water", start.waterG.map { RecipeFormat.weight($0, units) }),
      ("Temperature", start.tempC.map { RecipeFormat.temperature($0, units) }),
      ("Time", start.totalTimeS.map(RecipeFormat.clock)),
      ("Grind", start.grindSetting),
    ].compactMap { label, value in value.map { (label, $0) } }
  }
}
