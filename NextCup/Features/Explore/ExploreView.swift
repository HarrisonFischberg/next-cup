import NextCupKit
import SwiftData
import SwiftUI

/// The Explore tab: up to three beans in use are dealt one at a time (the next ones on the
/// shelf, or the ones with a chosen taste), each with the method and starting values the
/// recommender suggests. A kept bean becomes a drawer below the deck with the recipes it was
/// brewed with and the AI's help; a skipped one leaves the deck until it is brought back.
struct ExploreView: View {
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
  @Query(sort: \Brew.date, order: .reverse)
  private var brews: [Brew]
  @Query private var storedAliases: [TaxonomyAlias]
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Environment(\.modelContext) private var context
  @State private var insightsBean: Bean?
  @State private var adviceBean: Bean?
  @State private var taxonomy = ExploreModel.taxonomy
  @State private var addingBean = false
  @State private var showsRoasters = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Kept and skipped bean ids, comma-separated, so the choices outlast a relaunch.
  @AppStorage("explore.kept") private var keptIDs = ""
  @AppStorage("explore.skipped") private var skippedIDs = ""
  /// Flavor bucket keys chosen on the taste chips; empty means the recommended three.
  @State private var tastes: Set<String> = []
  /// The beans dealt this round, in order; the decided ones drop out of the deck.
  @State private var round: [UUID] = []
  @State private var openDrawer: UUID?
  @State private var lastSkipped: Bean?
  /// How far the top card has been thrown off the side by Keep or Skip.
  @State private var thrown: CGFloat = 0
  @GestureState private var drag: CGFloat = 0
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
      .buttonStyle(PressableStyle())
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
          .buttonStyle(PressableStyle())
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

  private var kept: Set<UUID> { ExploreModel.ids(keptIDs) }
  private var decided: Set<UUID> { kept.union(ExploreModel.ids(skippedIDs)) }

  /// Deals the next round: up to three undecided beans, with a chosen taste when one is set.
  private func deal(_ taxonomy: Taxonomy) {
    let aliases = ExploreModel.aliases(storedAliases)
    round = ExploreModel.deck(ExploreModel.planned(beans), decided: decided, tastes: tastes) {
      ExploreModel.buckets(of: $0, taxonomy: taxonomy, aliases: aliases)
    }.map(\.id)
  }

  /// Keep or Skip: the card leaves by its side, then the choice is stored.
  private func decide(_ bean: Bean, keep: Bool) {
    let commit = {
      thrown = 0
      if keep {
        keptIDs = ExploreModel.adding(bean.id, to: keptIDs)
        openDrawer = bean.id
        Feedback.success()
      } else {
        skippedIDs = ExploreModel.adding(bean.id, to: skippedIDs)
        lastSkipped = bean
        Feedback.lift()
      }
    }
    guard !reduceMotion else { return commit() }
    withAnimation(.easeIn(duration: DS.Motion.local)) {
      thrown = keep ? 500 : -500
    } completion: {
      withAnimation(.spring(duration: DS.Motion.enter)) { commit() }
    }
  }

  private func undoSkip() {
    guard let bean = lastSkipped else { return }
    withAnimation(DS.Motion.enter(reduceMotion)) {
      skippedIDs = ExploreModel.removing(bean.id, from: skippedIDs)
      lastSkipped = nil
    }
    Feedback.tap()
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
      let decided = decided
      let waiting = planned.filter { !decided.contains($0.id) }
      let buckets = { (bean: Bean) in
        ExploreModel.buckets(of: bean, taxonomy: taxonomy, aliases: aliases)
      }
      let result = { (refs: [BucketRef]) in
        ExploreModel.limited(Recommender.recommend(for: refs, history: history), to: methods)
      }
      let cards = round.compactMap { id in waiting.first { $0.id == id } }
      let keptBeans = beans.filter { kept.contains($0.id) }
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          PageHeader(title: "Explore") { SettingsGear(id: "explore.settings", large: true) }
          tasteChips(ExploreModel.flavors(of: waiting, buckets: buckets))
          if let bean = cards.first {
            let refs = buckets(bean)
            deck(
              bean, refs: refs, result: result(refs),
              position: round.count - cards.count + 1, behind: cards.count - 1)
          } else {
            roundOver(waiting: waiting, taxonomy: taxonomy)
          }
          if !keptBeans.isEmpty {
            Kicker("Kept", color: DS.ink2).accessibilityAddTraits(.isHeader)
              .padding(.top, DS.Space.sm)
            ForEach(keptBeans) { bean in
              let refs = buckets(bean)
              KeptBeanDrawer(
                bean: bean, buckets: refs, pick: result(refs).items.first,
                brews: brews(of: bean), units: units, canAsk: brewedBeanIDs.contains(bean.id),
                isOpen: openDrawer == bean.id,
                toggle: {
                  withAnimation(DS.Motion.enter(reduceMotion)) {
                    openDrawer = openDrawer == bean.id ? nil : bean.id
                  }
                  Feedback.selection()
                },
                link: link(for:), onAsk: { insightsBean = bean },
                onOtherWays: { adviceBean = bean },
                onRemove: {
                  withAnimation(DS.Motion.exit(reduceMotion)) {
                    keptIDs = ExploreModel.removing(bean.id, from: keptIDs)
                  }
                  Feedback.lift()
                })
            }
          }
          moreSections
        }
        .padding(DS.Space.lg)
      }
      .safeAreaInset(edge: .bottom) {
        if let bean = lastSkipped {
          SteelToast(message: "Skipped \(bean.name)", actionTitle: "Undo", action: undoSkip)
            .padding(DS.Space.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("explore.undo")
            .task(id: bean.id) {
              try? await Task.sleep(for: .seconds(6))
              guard !Task.isCancelled else { return }
              withAnimation(DS.Motion.exit(reduceMotion)) { lastSkipped = nil }
            }
        }
      }
      .onAppear { if round.isEmpty { deal(taxonomy) } }
      .onChange(of: tastes) { deal(taxonomy) }
      .onChange(of: planned.map(\.id)) { deal(taxonomy) }
      .sheet(item: $insightsBean) { bean in
        let history = brews(of: bean)
        if !history.isEmpty {
          AIAskView(
            model: AIAskModel(feature: .insights, brews: history, context: context),
            close: { insightsBean = nil })
        }
      }
      // The same three-brews sheet as the bean's own page.
      .sheet(item: $adviceBean) { bean in BeanBrewAdviceView(bean: bean) { adviceBean = nil } }
      .accessibilityIdentifier("explore.list")
    }
  }

  /// "Recommended" (the next three on the shelf) or the tastes of the beans still waiting.
  @ViewBuilder private func tasteChips(_ flavors: [BucketRef]) -> some View {
    if !flavors.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DS.Space.sm) {
          chip("Recommended", on: tastes.isEmpty) { tastes = [] }
            .accessibilityIdentifier("explore.taste.recommended")
          ForEach(flavors, id: \.key) { flavor in
            chip(flavor.name, on: tastes.contains(flavor.key)) {
              if tastes.contains(flavor.key) {
                tastes.remove(flavor.key)
              } else {
                tastes.insert(flavor.key)
              }
            }
            .accessibilityIdentifier("explore.taste.\(flavor.key)")
          }
        }
        .padding(.horizontal, DS.Space.lg)
      }
      .padding(.horizontal, -DS.Space.lg)
      .sensoryFeedback(.selection, trigger: tastes)
    }
  }

  private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title).font(.subheadline.weight(.semibold))
        .foregroundStyle(on ? DS.onSignal : DS.ink)
        .padding(.horizontal, DS.Space.lg)
        .frame(minHeight: DS.Size.minTap)
        .background(Capsule().fill(on ? DS.signal : DS.paper))
        .overlay(Capsule().strokeBorder(DS.line.opacity(0.5), lineWidth: on ? 0 : 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityAddTraits(on ? .isSelected : [])
  }

  /// The top card of the round over the edges of the ones behind it, with Skip and Keep
  /// under it. A swipe right keeps and a swipe left skips; the buttons do the same.
  private func deck(
    _ bean: Bean, refs: [BucketRef], result: RecommendationResult, position: Int, behind: Int
  ) -> some View {
    let offset = thrown + drag
    return VStack(spacing: DS.Space.md) {
      ExploreDeckCard(
        bean: bean, buckets: refs, result: result, units: units,
        counter: "\(position) of \(round.count)", link: link(for:), lean: offset
      )
      .offset(x: offset)
      .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset) / 24), anchor: .bottom)
      .animation(reduceMotion ? nil : .interactiveSpring, value: drag)
      .id(bean.id)
      .transition(.scale(scale: 0.94).combined(with: .opacity))
      // Beside the scroll, not instead of it: only a sideways drag moves the card.
      .simultaneousGesture(
        DragGesture(minimumDistance: 16)
          .updating($drag) { value, state, _ in
            if abs(value.translation.width) > abs(value.translation.height) {
              state = value.translation.width
            }
          }
          .onEnded { value in
            let across = value.translation.width
            guard abs(across) > 110, abs(across) > abs(value.translation.height) * 2 else {
              return
            }
            decide(bean, keep: across > 0)
          }
      )
      // The edges of the cards still to come.
      .padding(.bottom, CGFloat(behind) * 10)
      .background(alignment: .bottom) {
        ZStack(alignment: .bottom) {
          ForEach(Array((0..<behind).reversed()), id: \.self) { depth in
            RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
              .fill(DS.paper.opacity(depth == 0 ? 0.7 : 0.4))
              .frame(height: 48)
              .padding(.horizontal, CGFloat(depth + 1) * 14)
              .offset(y: -CGFloat(behind - depth - 1) * 10)
          }
        }
        .accessibilityHidden(true)
      }
      HStack(spacing: DS.Space.md) {
        SteelButton(title: "Skip", kind: .secondary) { decide(bean, keep: false) }
          .accessibilityHint("Takes \(bean.name) out of the deck")
          .accessibilityIdentifier("explore.skip")
        SteelButton(title: "Keep") { decide(bean, keep: true) }
          .accessibilityHint("Keeps \(bean.name) below with its recipes")
          .accessibilityIdentifier("explore.keep")
      }
      .disabled(thrown != 0)
    }
  }

  /// The round is decided: deal again, bring the skipped beans back, or point at the kept ones.
  private func roundOver(waiting: [Bean], taxonomy: Taxonomy) -> some View {
    let skipped = !ExploreModel.ids(skippedIDs).isEmpty
    return VStack(alignment: .leading, spacing: DS.Space.md) {
      Text(round.isEmpty ? "Nothing left to deal" : "That's the round")
        .font(.system(.title2, design: .serif, weight: .medium)).foregroundStyle(DS.ink)
      Text(
        !waiting.isEmpty
          ? "There are more beans on your shelf."
          : skipped
            ? "You kept or skipped every bean on your shelf."
            : "Every bean on your shelf is kept below."
      )
      .font(.body).foregroundStyle(DS.ink2)
      if !waiting.isEmpty {
        SteelButton(title: "Deal three more", kind: .secondary) {
          tastes = tastes.intersection(
            ExploreModel.flavors(of: waiting) {
              ExploreModel.buckets(
                of: $0, taxonomy: taxonomy, aliases: ExploreModel.aliases(storedAliases))
            }.map(\.key))
          withAnimation(DS.Motion.enter(reduceMotion)) { deal(taxonomy) }
        }
        .accessibilityIdentifier("explore.deal")
      } else if skipped {
        SteelButton(title: "Bring back skipped beans", kind: .secondary) {
          skippedIDs = ""
          lastSkipped = nil
          tastes = []
          withAnimation(DS.Motion.enter(reduceMotion)) { deal(taxonomy) }
        }
        .accessibilityIdentifier("explore.restore")
      }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper, dash: [5, 3])
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("explore.roundOver")
  }
}

/// One dealt bean: its name, what it is, and the brew the recommender would start with.
private struct ExploreDeckCard: View {
  let bean: Bean
  let buckets: [BucketRef]
  let result: RecommendationResult
  let units: UnitPreferences
  /// "1 of 3".
  let counter: String
  let link: (Recommendation) -> DeepLink?
  /// How far the card is off centre: right shows Keep, left shows Skip.
  let lean: CGFloat
  @Environment(AppRouter.self) private var router: AppRouter?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline) {
        Kicker(counter)
        Spacer()
        // Named as it leans, in words: the choice is never told by direction alone.
        if abs(lean) > 24 {
          Text(lean > 0 ? "KEEP" : "SKIP").font(DS.Font.label).tracking(1.2)
            .foregroundStyle(lean > 0 ? DS.accent : DS.ink2)
            .opacity(min(1, Double(abs(lean)) / 110))
            .accessibilityHidden(true)
        }
      }
      NavigationLink(value: DeepLink.bean(bean.id)) {
        Text(bean.name).font(.system(.largeTitle, design: .serif, weight: .medium))
          .foregroundStyle(DS.ink).multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
      }
      .accessibilityAddTraits(.isHeader)
      if !buckets.isEmpty {
        Text(buckets.map(\.name).joined(separator: "  ·  ")).font(.subheadline)
          .foregroundStyle(DS.ink2)
      }
      Text(subtitle).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
        .accessibilityIdentifier("explore.basis.\(bean.name)")
      if let item = result.items.first {
        Hairline().opacity(0.6).padding(.top, DS.Space.sm)
        Kicker("Start with", color: DS.ink2).padding(.top, DS.Space.sm)
        // A tap on the suggestion opens its Start brew page with this bean chosen.
        if let link = link(item) {
          NavigationLink(value: link) {
            RecommendationRow(item: item, rank: nil, units: units, opens: true, explains: false)
          }
          .buttonStyle(PressableStyle())
          .simultaneousGesture(TapGesture().onEnded { router?.startBeanID = bean.id })
          .accessibilityIdentifier("explore.pick.\(bean.name).1")
          .padding(.horizontal, -DS.Space.md)
        } else {
          RecommendationRow(item: item, rank: nil, units: units, explains: false)
            .padding(.horizontal, -DS.Space.md)
        }
      }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("explore.card.\(bean.name)")
  }

  private var subtitle: String {
    if result.isDefault {
      return
        "DEFAULT  ·  \(result.similarRatedCount) of \(Recommender.minimumSimilarBrews) rated similar brews"
    }
    return "FROM YOUR BREWS  ·  \(result.similarRatedCount) rated similar brews"
  }
}

/// A kept bean: a row that opens to brew it, the recipes it was brewed with, and the AI's help.
private struct KeptBeanDrawer: View {
  let bean: Bean
  let buckets: [BucketRef]
  /// The recommender's top suggestion, where "Brew <bean>" goes.
  let pick: Recommendation?
  /// Saved brews of this bean, newest first.
  let brews: [Brew]
  let units: UnitPreferences
  let canAsk: Bool
  let isOpen: Bool
  let toggle: () -> Void
  let link: (Recommendation) -> DeepLink?
  let onAsk: () -> Void
  let onOtherWays: () -> Void
  let onRemove: () -> Void
  @Environment(AppRouter.self) private var router: AppRouter?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The recipes this bean was brewed with, the best rated first.
  private var recipes: [(recipe: Recipe, count: Int, best: Int?)] {
    Dictionary(grouping: brews.compactMap { brew in brew.recipe.map { ($0, brew) } }) { $0.0.id }
      .values.compactMap { group in
        group.first.map {
          (recipe: $0.0, count: group.count, best: group.compactMap(\.1.ratingTenths).max())
        }
      }
      .sorted {
        ($0.best ?? -1, $0.count, $1.recipe.name) > ($1.best ?? -1, $1.count, $0.recipe.name)
      }
  }

  var body: some View {
    PaperBox {
      VStack(alignment: .leading, spacing: 0) {
        Button(action: toggle) {
          HStack(spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
              Text(bean.name).font(.system(.title3, design: .serif, weight: .medium))
                .foregroundStyle(DS.ink).multilineTextAlignment(.leading)
              Text(summary).font(.footnote).foregroundStyle(DS.ink2)
            }
            Spacer(minLength: DS.Space.sm)
            Image(systemName: "chevron.down").font(.footnote.weight(.semibold))
              .foregroundStyle(DS.accent)
              .rotationEffect(.degrees(isOpen ? 180 : 0))
              .accessibilityHidden(true)
          }
          .padding(DS.Space.md)
          .frame(maxWidth: .infinity, minHeight: DS.Size.primary, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOpen ? "Open" : "Closed")
        .accessibilityHint(isOpen ? "Closes the drawer" : "Opens recipes and AI help")
        .accessibilityIdentifier("explore.kept.\(bean.name)")
        if isOpen {
          opened.transition(.opacity)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var summary: String {
    let count = brews.count
    let brewed = count == 0 ? "Not brewed yet" : "\(count) \(count == 1 ? "brew" : "brews")"
    return ([brewed] + buckets.filter { $0.dimension == .flavor }.map(\.name))
      .joined(separator: "  ·  ")
  }

  @ViewBuilder private var opened: some View {
    Hairline()
    if let pick, let brewLink = link(pick) {
      NavigationLink(value: brewLink) {
        ViewThatFits(in: .horizontal) {
          Text("Brew \(bean.name)".dsTitle).lineLimit(1)
          Text("Brew this bean".dsTitle).lineLimit(1)
        }
        .font(DS.Font.din(22, relativeTo: .title2)).tracking(1)
        .frame(maxWidth: .infinity, minHeight: DS.Size.control)
      }
      .buttonStyle(SteelButtonStyle())
      .simultaneousGesture(TapGesture().onEnded { router?.startBeanID = bean.id })
      .padding(DS.Space.md)
      .accessibilityLabel("Brew \(bean.name)")
      .accessibilityIdentifier("explore.brew.\(bean.name)")
    }
    Text("RECIPES YOU'VE BREWED").font(DS.Font.label).foregroundStyle(DS.ink2)
      .padding(.horizontal, DS.Space.md).padding(.top, DS.Space.sm)
      .accessibilityAddTraits(.isHeader)
    if recipes.isEmpty {
      Text("None yet. Brew it once and the recipe shows here.")
        .font(.subheadline).foregroundStyle(DS.ink2)
        .padding(DS.Space.md)
    }
    ForEach(recipes, id: \.recipe.id) { entry in
      NavigationLink(value: DeepLink.recipe(entry.recipe.id)) {
        HStack(spacing: DS.Space.md) {
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.recipe.name).font(DS.Font.headline).foregroundStyle(DS.ink)
              .multilineTextAlignment(.leading)
            Text(detail(entry)).font(.footnote).foregroundStyle(DS.ink2)
          }
          Spacer(minLength: DS.Space.sm)
          if let best = entry.best, best > 0 {
            Text(Rating.text(best)).font(DS.Font.data).foregroundStyle(DS.accent)
              .accessibilityLabel("Best \(Rating.text(best)) out of 10")
          }
          Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            .foregroundStyle(DS.ink2).accessibilityHidden(true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
      }
      .buttonStyle(PressableStyle())
      .simultaneousGesture(TapGesture().onEnded { router?.startBeanID = bean.id })
      .accessibilityHint("Opens Start brew")
      .accessibilityIdentifier("explore.recipe.\(bean.name).\(entry.recipe.name)")
    }
    Hairline()
    if canAsk {
      action("Ask AI about this coffee", "sparkles", id: "explore.insights", onAsk)
      Hairline()
    }
    action("Other ways to brew this bean", "arrow.triangle.branch", id: "explore.otherWays") {
      onOtherWays()
    }
    .accessibilityHint("Asks AI for three brews for this bean")
    Hairline()
    Button(action: onRemove) {
      Text("Put back in the deck").font(.subheadline).foregroundStyle(DS.ink2)
        .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
        .padding(.horizontal, DS.Space.md)
    }
    .accessibilityIdentifier("explore.unkeep.\(bean.name)")
  }

  private func detail(_ entry: (recipe: Recipe, count: Int, best: Int?)) -> String {
    [entry.recipe.method?.name, "brewed \(entry.count) \(entry.count == 1 ? "time" : "times")"]
      .compactMap { $0 }.joined(separator: "  ·  ")
  }

  private func action(
    _ title: String, _ symbol: String, id: String, _ run: @escaping () -> Void
  ) -> some View {
    Button(action: run) {
      HStack(spacing: DS.Space.md) {
        Image(systemName: symbol).foregroundStyle(DS.accent).frame(width: 24)
          .accessibilityHidden(true)
        Text(title.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
      .padding(.horizontal, DS.Space.md)
      .contentShape(Rectangle())
    }
    .accessibilityIdentifier("\(id).\(bean.name)")
  }
}

private struct RecommendationRow: View {
  let item: Recommendation
  let rank: Int?
  let units: UnitPreferences
  var opens = false
  /// The deck card leaves the explanation out so Skip and Keep stay on screen.
  var explains = true

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
      if explains {
        Text(item.explanation).font(.callout).foregroundStyle(DS.ink2)
          .fixedSize(horizontal: false, vertical: true)
      }
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
