import NextCupKit
import SwiftData
import SwiftUI

/// S06, the Brew tab: the brew types the user brews with (Cone dripper, Press pot…), each
/// opening its styles, then More methods. Searching lists matching recipes by brew style.
struct RecipeLibraryView: View {
  @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
  @Query(filter: #Predicate<BrewMethod> { $0.isHidden }) private var hiddenMethods: [BrewMethod]
  @Query(filter: #Predicate<BrewMethod> { !$0.isHidden }, sort: \BrewMethod.sortOrder)
  private var shownMethods: [BrewMethod]
  @State private var search = ""
  @State private var editor: RecipeEditorTarget?
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

  private var matches: [Recipe] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return recipes.filter { !$0.isVersion } }
    return recipes.filter { recipe in
      [recipe.name, recipe.method?.name, recipe.credit, RecipeFormat.groupTitle(for: recipe)]
        .contains { $0?.localizedStandardContains(term) == true }
    }
  }

  private var groups: [(title: String, recipes: [Recipe])] {
    let grouped = Dictionary(grouping: matches, by: RecipeFormat.groupOrder(for:))
    return grouped.keys.sorted().compactMap { key in
      guard let first = grouped[key]?.first, let members = grouped[key] else { return nil }
      return (RecipeFormat.groupTitle(for: first), members)
    }
  }

  var body: some View {
    ScrollView {
      if recipes.isEmpty {
        EmptyState(
          title: "No recipes yet",
          message: "Starter recipes load with the app. Recipes you create will be listed here.",
          actionTitle: "New recipe", action: { editor = .new })
      } else if matches.isEmpty {
        EmptyState(
          title: "No matches", message: "No recipe matches “\(search)”. Try a method or a name.",
          actionTitle: "Clear search", action: { search = "" })
      } else {
        LazyVStack(alignment: .leading, spacing: DS.Space.xl) {
          if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            brewTypes
            moreMethods
          } else {
            ForEach(groups, id: \.title) { group in
              section(group.title, group.recipes)
            }
          }
        }
        .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
      }
    }
    .background(DS.bg)
    .searchable(text: $search, prompt: "Search recipes")
    .navigationTitle("Brew")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          editor = .new
        } label: {
          Label("New recipe", systemImage: "plus")
        }
        .accessibilityIdentifier("recipes.add")
      }
    }
    .sheet(item: $editor) { target in
      RecipeEditorView(target: target) { _ in editor = nil }
    }
    .accessibilityIdentifier("tab.root.recipes")
  }

  /// One button per brew type, grouped under its brew style.
  private var brewTypes: some View {
    let styles = BrewStyle.allCases.filter { style in shownMethods.contains { $0.style == style } }
    return VStack(alignment: .leading, spacing: DS.Space.lg) {
      ForEach(styles, id: \.self) { style in
        VStack(alignment: .leading, spacing: DS.Space.sm) {
          Text(RecipeFormat.title(style).uppercased()).font(DS.Font.label).tracking(0.5)
            .foregroundStyle(DS.ink2).accessibilityAddTraits(.isHeader)
          LazyVGrid(columns: methodColumns, alignment: .leading, spacing: DS.Space.md) {
            ForEach(shownMethods.filter { $0.style == style }) { method in
              NavigationLink(value: DeepLink.method(method.id)) { methodCard(method) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("brew.method.\(method.name)")
            }
          }
        }
      }
    }
  }

  private var methodColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: DS.Space.lg, alignment: .top),
      count: dts.isAccessibilitySize ? 2 : 3)
  }

  /// A brewer drawing with its name and how many styles it has, like a guide index.
  private func methodCard(_ method: BrewMethod) -> some View {
    let count = method.recipes?.count ?? 0
    return VStack(spacing: DS.Space.xs) {
      BrewMedallion(method.glyph)
      Text(method.shortName).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
      Text(count == 1 ? "1 style" : "\(count) styles").font(.caption).foregroundStyle(DS.ink2)
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    // The full name, since the label under the drawing may be shortened.
    .accessibilityLabel(method.name)
    .accessibilityValue(count == 1 ? "1 style" : "\(count) styles")
  }

  /// The pull-down for methods left out in onboarding.
  private var moreMethods: some View {
    DisclosureGroup {
      MethodChips().padding(.top, DS.Space.sm)
    } label: {
      Text(hiddenMethods.isEmpty ? "Methods" : "More methods (\(hiddenMethods.count))")
        .font(DS.Font.headline).foregroundStyle(DS.ink)
        .frame(minHeight: DS.Size.minTap, alignment: .leading)
    }
    .tint(DS.ink)
    .accessibilityIdentifier("recipes.moreMethods")
  }

  private func section(_ title: String, _ members: [Recipe]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // A quiet label: the recipes, not their group, are what the eye should find.
      Text(title.uppercased()).font(DS.Font.label).tracking(0.5)
        .foregroundStyle(DS.ink2)
        .padding(.horizontal, DS.Space.xs).frame(
          maxWidth: .infinity, minHeight: 32, alignment: .leading
        )
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        VStack(spacing: 0) {
          ForEach(members) { recipe in
            NavigationLink(value: DeepLink.recipe(recipe.id)) { row(recipe) }
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
              }
              .accessibilityIdentifier("recipe.row.\(recipe.id.uuidString)")
            if recipe.id != members.last?.id { Hairline() }
          }
        }
      }
    }
  }

  private func row(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(recipe.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
      Text(summary(recipe)).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
      if let method = recipe.method?.name {
        Text(method).font(.footnote).foregroundStyle(DS.ink2)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  private func summary(_ recipe: Recipe) -> String {
    var parts = [
      "\(RecipeFormat.weight(recipe.doseG, units)) : \(RecipeFormat.weight(recipe.waterG, units))"
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
