import NextCupKit
import SwiftData
import SwiftUI

/// The Explore tab: for each bean in use, which method and starting values the
/// recommender suggests and why. The explanation is built from facts the
/// recommender computed; with too few graded brews the card says it is a default.
struct ExploreView: View {
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
  @Query(sort: \Brew.date, order: .reverse)
  private var brews: [Brew]
  @Query private var storedAliases: [TaxonomyAlias]
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Environment(\.modelContext) private var context
  @State private var insightsBean: Bean?
  @State private var taxonomy = ExploreModel.taxonomy
  @State private var addingBean = false
  @State private var showsRoasters = false
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
      if let taxonomy {
        content(taxonomy)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: DS.Space.lg) {
            StateBanner(
              kind: .error,
              message:
                "The flavor vocabulary could not be read, so recommendations are unavailable.",
              actionTitle: "Try again", action: { taxonomy = try? Taxonomy(bundle: .main) }
            )
            .accessibilityIdentifier("explore.error")
            moreSections
          }
          .padding(DS.Space.lg)
        }
      }
    }
    .background(DS.bg)
    .navigationTitle("Explore")
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $addingBean) { BeanEditorView(target: .new) { addingBean = false } }
    .sheet(isPresented: $showsRoasters) { RoasterDiscoveryView { showsRoasters = false } }
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the cards inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.explore")
    }
  }

  /// Roasters and flavors as labeled sections under the recommendations, not
  /// icon-only toolbar buttons.
  @ViewBuilder private var moreSections: some View {
    SavedRoasters()
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("ROASTERS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        VStack(spacing: 0) {
          if let catalog = RoasterCatalog.shared {
            NavigationLink {
              RoasterCatalogView(catalog: catalog)
            } label: {
              sectionRow("Roaster catalog", "Coffees with starter recipes", "storefront")
            }
            .accessibilityIdentifier("explore.catalog")
            Hairline()
          }
          Button {
            showsRoasters = true
          } label: {
            sectionRow("Find roasters near me", "Search the map while you use the app", "map")
          }
          .accessibilityIdentifier("explore.roasters")
        }
      }
      .buttonStyle(.plain)
    }
    if let taxonomy {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("FLAVORS").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        PaperBox {
          NavigationLink {
            FlavorExplorerView(taxonomy: taxonomy)
          } label: {
            sectionRow("Flavor explorer", "Origins, processes and tasting words", "book")
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("explore.flavors")
        }
      }
    }
  }

  /// The Start brew page for a suggestion: its recipe when one matches, else its
  /// brewer's styles.
  private func link(for item: Recommendation) -> DeepLink? {
    guard
      let method = methods.first(where: { item.methodKey != nil && $0.builtInKey == item.methodKey }
      )
        ?? methods.first(where: { $0.name == item.methodName })
    else { return nil }
    let recipes = method.recipes ?? []
    let recipe =
      recipes.first { $0.name == item.recipeName }
      ?? (item.recipeName == nil && recipes.count == 1 ? recipes.first : nil)
    return recipe.map { .recipe($0.id) } ?? .method(method.id)
  }

  private func sectionRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
    HStack(spacing: DS.Space.md) {
      Image(systemName: symbol).foregroundStyle(DS.ink2).frame(width: 24).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(detail).font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(DS.ink2).accessibilityHidden(true)
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func content(_ taxonomy: Taxonomy) -> some View {
    let planned = ExploreModel.planned(beans)
    if planned.isEmpty {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          PageHeader(title: "Explore") { SettingsGear(id: "explore.settings", large: true) }
            .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.lg)
          EmptyState(
            title: "Nothing to plan yet",
            message:
              "Add a bean you are brewing and Explore suggests a method and starting values for it.",
            actionTitle: "Add a bean", action: { addingBean = true })
          moreSections.padding(.horizontal, DS.Space.lg)
        }
        .padding(.bottom, DS.Space.lg)
      }
      .accessibilityIdentifier("explore.empty")
    } else {
      let aliases = ExploreModel.aliases(storedAliases)
      let history = ExploreModel.history(of: brews, taxonomy: taxonomy, aliases: aliases)
      let brewedBeanIDs = Set(brews.flatMap { ($0.beans ?? []).compactMap { $0.bean?.id } })
      ScrollView {
        LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
          PageHeader(title: "Explore") { SettingsGear(id: "explore.settings", large: true) }
          Kicker("For your Next Cup", color: DS.ink2).accessibilityAddTraits(.isHeader)
          ForEach(planned) { bean in
            let refs = ExploreModel.buckets(of: bean, taxonomy: taxonomy, aliases: aliases)
            BeanRecommendationCard(
              bean: bean, buckets: refs,
              result: ExploreModel.limited(
                Recommender.recommend(for: refs, history: history), to: methods),
              units: units,
              canAsk: brewedBeanIDs.contains(bean.id), featured: bean.id == planned.first?.id,
              link: link(for:), onAsk: { insightsBean = bean })
          }
          moreSections
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
  /// The first card is the screen's standout; the rest show only their top pick.
  let featured: Bool
  let link: (Recommendation) -> DeepLink?
  let onAsk: () -> Void

  var body: some View {
    PaperBox {
      VStack(alignment: .leading, spacing: 0) {
        header
        ForEach(
          Array(result.items.prefix(featured ? result.items.count : 1).enumerated()), id: \.offset
        ) { index, item in
          Hairline()
          let rank = result.items.count > 1 ? index + 1 : nil
          // A tap on a suggestion opens its Start brew page.
          if let link = link(item) {
            NavigationLink(value: link) {
              RecommendationRow(item: item, rank: rank, units: units, opens: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("explore.pick.\(bean.name).\(index + 1)")
          } else {
            RecommendationRow(item: item, rank: rank, units: units)
          }
        }
        Hairline()
        if featured {
          NavigationLink(value: DeepLink.newBrew) {
            Text("Log a brew".dsTitle).font(DS.Font.din(24, relativeTo: .title2)).tracking(1)
              .frame(maxWidth: .infinity, minHeight: DS.Size.primary)
          }
          .buttonStyle(SteelButtonStyle())
          .padding(DS.Space.md)
          .accessibilityIdentifier("explore.brew.\(bean.name)")
        } else {
          NavigationLink(value: DeepLink.newBrew) {
            Text("Log a brew".dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
              .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
              .padding(.horizontal, DS.Space.md)
          }
          .accessibilityIdentifier("explore.brew.\(bean.name)")
        }
        if canAsk {
          Hairline()
          Button(action: onAsk) {
            Text("Ask AI about this coffee".dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
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
        Text(bean.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
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
        "DEFAULT  ·  \(result.similarRatedCount) of \(Recommender.minimumSimilarBrews) rated similar brews"
    }
    return "FROM YOUR BREWS  ·  \(result.similarRatedCount) rated similar brews"
  }
}

private struct RecommendationRow: View {
  let item: Recommendation
  let rank: Int?
  let units: UnitPreferences
  var opens = false

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
        if let rank { Text("\(rank)").font(DS.Font.data).foregroundStyle(DS.ink2) }
        Text(item.methodName.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
        if item.isDefault { Tag(text: "Default") }
        if opens {
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            .foregroundStyle(DS.ink2).accessibilityHidden(true)
        }
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
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityHint(opens ? "Opens Start brew" : "")
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
