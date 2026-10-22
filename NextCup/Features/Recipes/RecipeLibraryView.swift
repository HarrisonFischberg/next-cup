import NextCupKit
import SwiftData
import SwiftUI

/// S06: recipes grouped by brew style, searchable by recipe, method and credit.
struct RecipeLibraryView: View {
  @Query(sort: \Recipe.name) private var recipes: [Recipe]
  @State private var search = ""
  @State private var editor: RecipeEditorTarget?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var matches: [Recipe] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return recipes }
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
          message: "Starter recipes load with the app. Recipes you create will be listed here.")
      } else if matches.isEmpty {
        EmptyState(
          title: "No matches", message: "No recipe matches “\(search)”. Try a method or a name.",
          actionTitle: "Clear search", action: { search = "" })
      } else {
        LazyVStack(alignment: .leading, spacing: DS.Space.xl) {
          ForEach(groups, id: \.title) { group in
            section(group.title, group.recipes)
          }
        }
        .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
      }
    }
    .background(DS.bg)
    .searchable(text: $search, prompt: "Search recipes")
    .navigationTitle("Recipes")
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

  private func section(_ title: String, _ members: [Recipe]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title.uppercased()).font(DS.Font.label).tracking(0.5)
        .foregroundStyle(DS.onSteel)
        .padding(.horizontal, DS.Space.md).frame(
          maxWidth: .infinity, minHeight: 32, alignment: .leading
        )
        .background(DS.steel, ignoresSafeAreaEdges: [])
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
      Text(recipe.name.uppercased()).font(DS.Font.headline).foregroundStyle(DS.ink)
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
