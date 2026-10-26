import NextCupKit
import SwiftData
import SwiftUI

/// The styles for one brew method: every recipe for it, each with what it is, who it is
/// by and its numbers. Picking one opens its Start brew page.
struct MethodStylesView: View {
  let link: DeepLink
  let methodID: UUID
  @Query private var methods: [BrewMethod]
  @State private var buildingOwn = false
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  init(link: DeepLink, methodID: UUID) {
    self.link = link
    self.methodID = methodID
    _methods = Query(filter: #Predicate<BrewMethod> { $0.id == methodID })
  }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  /// Each family's original first, then its versions, then the user's own recipes.
  static func styles(of method: BrewMethod) -> [Recipe] {
    (method.recipes ?? []).sorted {
      ($0.builtInKey == nil ? 1 : 0, $0.family ?? "", $0.isVersion ? 1 : 0, $0.name)
        < ($1.builtInKey == nil ? 1 : 0, $1.family ?? "", $1.isVersion ? 1 : 0, $1.name)
    }
  }

  var body: some View {
    ScrollView {
      if let method = methods.first {
        let styles = Self.styles(of: method)
        VStack(alignment: .leading, spacing: DS.Space.lg) {
          VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Pick a style").font(DS.Font.display).foregroundStyle(DS.ink)
              .dynamicTypeSize(...DS.displayCap).accessibilityAddTraits(.isHeader)
            Text("\(styles.count) ways to brew on the \(method.name.lowercased())")
              .font(.subheadline).foregroundStyle(DS.ink2)
          }
          if styles.isEmpty {
            EmptyState(
              title: "No styles yet", message: "Recipes you create for this method show here.")
          }
          ForEach(styles) { recipe in
            NavigationLink(value: DeepLink.recipe(recipe.id)) { card(recipe) }
              .buttonStyle(.plain)
              .accessibilityIdentifier("style.\(recipe.id.uuidString)")
          }
          yourStyle
        }
        .padding(DS.Space.lg)
      } else {
        EmptyState(title: "Method not found", message: "This brew method is no longer here.")
      }
    }
    .background(DS.bg)
    .navigationTitle(methods.first?.name ?? link.screenName)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier(link.identifier)
    .sheet(isPresented: $buildingOwn) {
      RecipeEditorView(target: .new, methodID: methodID) { _ in buildingOwn = false }
    }
  }

  /// The last card: build a style from nothing on this method.
  private var yourStyle: some View {
    Button {
      buildingOwn = true
    } label: {
      HStack(spacing: DS.Space.md) {
        Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(DS.signal)
          .frame(width: 44, height: 44).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text("Your Style").font(DS.Font.headline).foregroundStyle(DS.ink)
          Text("Build your own, with nothing pre-set.").font(.subheadline).foregroundStyle(DS.ink2)
        }
        Spacer(minLength: 0)
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .panel(DS.paper, dash: [6, 4])
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("style.yours")
  }

  private func card(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline) {
        Text(recipe.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
        Spacer(minLength: DS.Space.sm)
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
          .foregroundStyle(DS.ink2).accessibilityHidden(true)
      }
      if let credit = recipe.credit, !credit.isEmpty {
        Text("By \(credit)").font(.subheadline.weight(.medium)).foregroundStyle(DS.signal)
      }
      if let note = recipe.tuningNote, !note.isEmpty {
        Text(note).font(.subheadline).foregroundStyle(DS.ink2).lineLimit(3)
      }
      Text(details(recipe)).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink)
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  private func details(_ recipe: Recipe) -> String {
    var parts = [
      "\(RecipeFormat.weight(recipe.doseG, units)) : \(RecipeFormat.weight(recipe.waterG, units))"
    ]
    if let ratio = BrewMath.ratioLabel(
      BrewMath.ratio(
        doseG: recipe.doseG, waterG: recipe.waterG, iceG: recipe.includesIce ? recipe.iceG : nil))
    {
      parts.append(ratio)
    }
    if let tempC = recipe.tempC { parts.append(RecipeFormat.temperature(tempC, units)) }
    if let seconds = recipe.totalTimeS { parts.append(RecipeFormat.clock(seconds)) }
    return parts.joined(separator: "  ·  ")
  }
}
