import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// S06, the Brew tab: a big title, search, the brew methods as drawings (tap one for its
/// styles), More methods for the ones left out in onboarding, then Your recipes as cards.
/// Searching lists matching recipes by brew style.
struct RecipeLibraryView: View {
  @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
  @Query(filter: #Predicate<BrewMethod> { $0.isHidden }) private var hiddenMethods: [BrewMethod]
  @Query(filter: #Predicate<BrewMethod> { !$0.isHidden }, sort: \BrewMethod.sortOrder)
  private var shownMethods: [BrewMethod]
  @State private var search = ""
  @State private var editor: RecipeEditorTarget?
  @State private var creatingWithAI = false
  /// The recipe "Create with AI" wrote, opened in the editor once its sheet is gone.
  @State private var aiDraft: RecipeDraft?
  /// The recipe waiting on the Delete confirmation.
  @State private var deleting: Recipe?
  @State private var deleteError: String?
  @State private var scrollPosition = ScrollPosition(edge: .top)
  @Environment(AppRouter.self) private var router: AppRouter?
  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  /// Only the methods picked in onboarding (or under More methods); a recipe with no method stays.
  private var recipes: [Recipe] {
    let hidden = Set(hiddenMethods.map(\.id))
    return allRecipes.filter { !hidden.contains($0.method?.id ?? UUID()) }
  }

  private var searching: Bool { !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  private var matches: [Recipe] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return recipes.filter { !$0.isVersion && !$0.isNextCup } }
    return recipes.filter { recipe in
      [recipe.name, recipe.method?.name, recipe.credit, RecipeFormat.groupTitle(for: recipe)]
        .contains { $0?.localizedStandardContains(term) == true }
    }
  }

  /// What the AI made from past brews, pinned on top, even for a method left out of the page.
  private var nextCups: [Recipe] { allRecipes.filter(\.isNextCup) }

  private var groups: [(title: String, recipes: [Recipe])] {
    let grouped = Dictionary(grouping: matches, by: RecipeFormat.groupOrder(for:))
    return grouped.keys.sorted().compactMap { key in
      guard let first = grouped[key]?.first, let members = grouped[key] else { return nil }
      return (RecipeFormat.groupTitle(for: first), members)
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: DS.Space.xl) {
        PageHeader(title: "Brew") {
          SettingsGear(id: "recipes.settings", large: true)
          Menu {
            Button("Create with AI", systemImage: "sparkles") { creatingWithAI = true }
              .accessibilityIdentifier("recipes.add.ai")
            Button("New recipe", systemImage: "square.and.pencil") { editor = .new }
              .accessibilityIdentifier("recipes.add.blank")
          } label: {
            Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(DS.onSignal)
              .frame(width: 52, height: 52).background(DS.signal, in: Circle())
          }
          .accessibilityLabel("Add recipe")
          .accessibilityIdentifier("recipes.add")
        }
        searchField
        if let deleteError {
          StateBanner(kind: .error, message: deleteError, actionTitle: "Dismiss") {
            self.deleteError = nil
          }
        }
        if recipes.isEmpty {
          EmptyState(
            title: "No recipes yet",
            message: "Starter recipes load with the app. Recipes you create will be listed here.",
            actionTitle: "New recipe", action: { editor = .new })
        } else if matches.isEmpty {
          EmptyState(
            title: "No matches", message: "No recipe matches “\(search)”. Try a method or a name.",
            actionTitle: "Clear search", action: { search = "" })
        } else if searching {
          ForEach(groups, id: \.title) { group in section(group.title, group.recipes) }
        } else {
          if !nextCups.isEmpty { section("Recipe to try for your Next Cup", nextCups) }
          methods
          SectionRule("Your recipes")
          ForEach(groups, id: \.title) { group in section(group.title, group.recipes) }
        }
      }
      .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
    }
    .scrollPosition($scrollPosition)
    .onChange(of: router?.brewTopRequests) {
      search = ""
      scrollPosition.scrollTo(edge: .top)
    }
    .background(DS.bg)
    .scrollDismissesKeyboard(.immediately)
    // The page draws its own title and search, so the bar would only be an empty strip.
    .navigationTitle("Brew")
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $editor) { target in
      RecipeEditorView(target: target) { _ in editor = nil }
    }
    .sheet(
      isPresented: $creatingWithAI,
      onDismiss: {
        if let aiDraft { editor = .prepared(aiDraft) }
        aiDraft = nil
      }
    ) {
      RecipeCreateAIView { draft in
        aiDraft = draft
        creatingWithAI = false
      } cancel: {
        creatingWithAI = false
      }
    }
    .confirmationDialog(
      "Delete “\(deleting?.name ?? "")”?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { recipe in
      Button("Delete recipe", role: .destructive) { delete(recipe) }
        .accessibilityIdentifier("recipe.delete.confirm")
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("Brews you logged with it stay in your journal.")
    }
    .accessibilityIdentifier("tab.root.recipes")
  }

  private func delete(_ recipe: Recipe) {
    deleting = nil
    let service = RecipeEditorService(store: Store(context: context))
    if case .failure(let failure) = service.delete(recipe) {
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      deleteError = "The recipe was not deleted. \(failure.message)"
    } else {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
  }

  /// Search, drawn on the page under the title rather than in the bar.
  private var searchField: some View {
    HStack(spacing: DS.Space.sm) {
      Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(DS.ink2)
        .accessibilityHidden(true)
      TextField("Search recipes", text: $search).font(.body).foregroundStyle(DS.ink)
        .submitLabel(.search).autocorrectionDisabled()
        .accessibilityIdentifier("recipes.search")
      if !search.isEmpty {
        Button {
          search = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(DS.ink2)
            .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        }
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, DS.Space.md)
    .frame(minHeight: DS.Size.control)
    .background(DS.ink.opacity(0.06), in: Capsule())
  }

  /// The brewers in use on a colour block, each opening its styles, with the pull-down
  /// for the rest in its corner.
  private var methods: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline) {
        Text("Explore by method").font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: DS.Space.sm)
        moreMethods
      }
      .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.md)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: DS.Space.lg) {
          ForEach(shownMethods) { method in
            NavigationLink(value: DeepLink.method(method.id)) { methodTile(method) }
              .buttonStyle(.plain)
              .accessibilityIdentifier("brew.method.\(method.name)")
          }
        }
        .padding(.horizontal, DS.Space.lg).padding(.bottom, DS.Space.lg)
      }
    }
    .colorBlock()
  }

  private func methodTile(_ method: BrewMethod) -> some View {
    let count = method.builtInKey == NespressoJokeView.methodKey ? 1 : method.recipes?.count ?? 0
    let side: CGFloat = dts.isAccessibilitySize ? 120 : 88
    return VStack(spacing: DS.Space.xs) {
      BrewGlyphView(glyph: method.glyph).frame(width: side, height: side)
      Text(method.shortName).font(.footnote.weight(.semibold)).foregroundStyle(DS.ink)
        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
      Text(count == 1 ? "1 style" : "\(count) styles").font(.caption).foregroundStyle(DS.ink2)
    }
    .frame(width: dts.isAccessibilitySize ? 132 : 100)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// The pull-down for methods left out in onboarding; a sheet keeps the row tidy.
  private var moreMethods: some View {
    NavigationLink {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          Text("Tap a brewer to show or hide it on the Brew page.").font(.subheadline)
            .foregroundStyle(DS.ink2)
          MethodChips()
        }
        .padding(DS.Space.lg)
      }
      .background(DS.bg)
      .navigationTitle("Methods")
      .navigationBarTitleDisplayMode(.inline)
    } label: {
      HStack(spacing: DS.Space.xs) {
        Text(hiddenMethods.isEmpty ? "All methods" : "More methods (\(hiddenMethods.count))")
          .font(.subheadline.weight(.semibold))
        Image(systemName: "chevron.right").font(.caption.weight(.bold))
      }
      .foregroundStyle(DS.accent).frame(minHeight: DS.Size.minTap)
    }
    .accessibilityIdentifier("recipes.moreMethods")
  }

  private func section(_ title: String, _ members: [Recipe]) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      Kicker(title, color: DS.ink2).accessibilityAddTraits(.isHeader)
      ForEach(members) { recipe in
        NavigationLink(value: DeepLink.recipe(recipe.id)) { card(recipe) }
          .buttonStyle(.plain)
          .contextMenu {
            if recipe.builtInKey == nil {
              Button("Edit", systemImage: "pencil") { editor = .edit(recipe.id) }
            }
            Button(
              recipe.builtInKey == nil ? "Duplicate" : "Customize",
              systemImage: recipe.builtInKey == nil
                ? "plus.square.on.square" : "slider.horizontal.3"
            ) { editor = .copy(recipe.id) }
            if recipe.builtInKey == nil {
              Button("Delete", systemImage: "trash", role: .destructive) { deleting = recipe }
                .accessibilityIdentifier("recipe.delete")
            }
          }
          .accessibilityIdentifier("recipe.row.\(recipe.id.uuidString)")
      }
    }
  }

  /// A recipe card: its brewer on a colour block, then the name, method and numbers.
  private func card(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if heroPhoto(methodKey: recipe.method?.builtInKey, role: .card) != nil {
        HeroBanner(methodKey: recipe.method?.builtInKey, role: .card)
      } else {
        HStack {
          Spacer(minLength: 0)
          BrewHero(glyph: recipe.method?.glyph ?? .cup, size: 170)
          Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Space.xl)
        .frame(maxWidth: .infinity)
        .background(DS.kraft)
      }
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        HStack(alignment: .firstTextBaseline) {
          Text(recipe.name.dsTitle).font(DS.Font.din(28, relativeTo: .title2))
            .foregroundStyle(DS.ink).lineLimit(2).minimumScaleFactor(0.8)
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.right").font(.footnote.weight(.bold))
            .foregroundStyle(DS.ink2).accessibilityHidden(true)
        }
        if let method = recipe.method?.name {
          Text(method).font(.subheadline).foregroundStyle(DS.ink2)
        }
        Hairline().opacity(0.5).padding(.vertical, DS.Space.xs)
        Text(summary(recipe)).font(DS.Font.mono(.footnote, .semibold)).foregroundStyle(DS.ink)
      }
      .padding(DS.Space.lg)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  private func summary(_ recipe: Recipe) -> String {
    var parts = [
      RecipeFormat.weight(recipe.doseG, units), RecipeFormat.weight(recipe.waterG, units),
    ]
    if let ratio = BrewMath.ratioLabel(
      BrewMath.ratio(
        doseG: recipe.doseG, waterG: recipe.waterG, iceG: recipe.includesIce ? recipe.iceG : nil))
    {
      parts.append(ratio)
    }
    if let seconds = recipe.totalTimeS { parts.append(RecipeFormat.clock(seconds)) }
    return parts.joined(separator: "  ·  ")
  }
}
