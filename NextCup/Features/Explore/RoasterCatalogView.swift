import NextCupKit
import SwiftData
import SwiftUI

/// Explore > Roaster catalog: roasters, then their coffees, then starting recipes.
struct RoasterCatalogView: View {
  let catalog: RoasterCatalog

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
        Text("Facts checked \(catalog.checkedOn). \(catalog.note)").font(.footnote)
          .foregroundStyle(DS.ink2)
          .accessibilityIdentifier("catalog.note")
        SavedRoasters()
        ForEach(catalog.roasters) { roaster in
          NavigationLink {
            CatalogRoasterView(roaster: roaster, checkedOn: catalog.checkedOn)
          } label: {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
              Text(roaster.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
              Text("\(roaster.place)  ·  \(roaster.coffees.count) coffees")
                .font(.footnote).foregroundStyle(DS.ink2)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
            .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
          }
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("catalog.roaster.\(roaster.key)")
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("Roaster catalog")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("catalog.list")
  }
}

/// Roasters saved from Find roasters near me, on the Explore home and in the catalog.
struct SavedRoasters: View {
  @Query(filter: #Predicate<Roaster> { $0.savedFromMap }, sort: \Roaster.name)
  private var saved: [Roaster]

  var body: some View {
    if !saved.isEmpty {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("SAVED ROASTERS").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        PaperBox {
          VStack(spacing: 0) {
            ForEach(saved) { roaster in
              if let website = roaster.website {
                Link(destination: website) { row(roaster, linked: true) }
              } else {
                row(roaster, linked: false)
              }
              if roaster.id != saved.last?.id { Hairline() }
            }
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("explore.savedRoasters")
    }
  }

  private func row(_ roaster: Roaster, linked: Bool) -> some View {
    HStack(spacing: DS.Space.md) {
      Image(systemName: "mappin.and.ellipse").foregroundStyle(DS.ink2).frame(width: 24)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(roaster.name).font(DS.Font.headline).foregroundStyle(DS.ink)
        if let city = roaster.city { Text(city).font(.footnote).foregroundStyle(DS.ink2) }
      }
      Spacer(minLength: DS.Space.sm)
      if linked {
        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold))
          .foregroundStyle(DS.ink2).accessibilityHidden(true)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("explore.savedRoaster.\(roaster.name)")
  }
}

private struct CatalogRoasterView: View {
  let roaster: RoasterCatalog.Roaster
  let checkedOn: String

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
        Text(roaster.place + ", " + roaster.country).font(.subheadline).foregroundStyle(DS.ink2)
        Link(destination: roaster.website) {
          Label("Roaster website", systemImage: "safari").font(DS.Font.headline)
            .foregroundStyle(DS.ink)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
        }
        .accessibilityIdentifier("catalog.website")
        Text("COFFEES (CHECKED \(checkedOn))").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        ForEach(roaster.coffees) { coffee in
          NavigationLink {
            CatalogCoffeeView(coffee: coffee, roaster: roaster)
          } label: {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
              Text(coffee.name).font(DS.Font.headline).foregroundStyle(DS.ink)
              Text(CatalogText.facts(coffee)).font(.footnote).foregroundStyle(DS.ink2)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
            .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
          }
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("catalog.coffee.\(coffee.key)")
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle(roaster.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct CatalogCoffeeView: View {
  let coffee: RoasterCatalog.Coffee
  let roaster: RoasterCatalog.Roaster
  @Environment(\.modelContext) private var context
  @State private var message: (text: String, isError: Bool)?
  @State private var timerSetup: TimerSetup?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var service: CatalogService { CatalogService(store: Store(context: context)) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        Text(coffee.name.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap)
          .accessibilityAddTraits(.isHeader)
        Text("\(roaster.name)  ·  \(CatalogText.facts(coffee))").font(.subheadline)
          .foregroundStyle(DS.ink2)
        if let notes = coffee.flavorNotes, !notes.isEmpty {
          Text("Tasting notes: " + notes.joined(separator: ", ")).font(.callout)
            .foregroundStyle(DS.ink2)
        }
        if let message {
          StateBanner(kind: message.isError ? .error : .info, message: message.text)
            .accessibilityIdentifier("catalog.message")
        }
        SteelButton(title: "Add to my beans", kind: .secondary, action: addBean)
          .accessibilityIdentifier("catalog.add")
        Text("NEXT CUP STARTING RECIPES").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        Text(
          "Generated by Next Cup from the roast level and process. They are not the roaster's recipes."
        )
        .font(.footnote).foregroundStyle(DS.ink2)
        ForEach(coffee.starterRecipes, id: \.style) { starter in
          StarterCard(starter: starter, units: units) { brew(starter) }
        }
        if let source = coffee.source {
          Link("Source page", destination: source).font(.footnote)
            .frame(minHeight: DS.Size.minTap)
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle(coffee.name)
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $timerSetup) { TimerView(setup: $0) }
    .accessibilityIdentifier("catalog.coffee")
  }

  private func addBean() {
    switch service.addBean(coffee, from: roaster) {
    case .success(let result):
      message = (
        result.created
          ? "Added \(coffee.name) to your beans." : "\(coffee.name) is already in your beans.",
        false
      )
    case .failure(let error):
      message = (error.message, true)
    }
  }

  private func brew(_ starter: StarterRecipe) {
    switch service.recipe(for: starter, coffee: coffee) {
    case .success(let recipe):
      if let setup = try? TimerPlanBuilder.setup(for: recipe, doseG: recipe.doseG) {
        message = nil
        timerSetup = setup
      } else {
        message = ("This recipe cannot be timed.", true)
      }
    case .failure(let error):
      message = (error.message, true)
    }
  }
}

private struct StarterCard: View {
  let starter: StarterRecipe
  let units: UnitPreferences
  let brew: () -> Void

  private var values: [(String, String)] {
    var rows = [
      (starter.style == .espresso ? "Yield" : "Water", RecipeFormat.weight(starter.waterG, units)),
      ("Dose", RecipeFormat.weight(starter.doseG, units)),
    ]
    if let temp = starter.tempC {
      rows.append(("Temperature", RecipeFormat.temperature(temp, units)))
    }
    rows.append(("Time", CatalogText.duration(starter.totalTimeS)))
    return rows
  }

  var body: some View {
    PaperBox {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text(starter.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        ForEach(values, id: \.0) { row in
          HStack(alignment: .firstTextBaseline) {
            Text(row.0.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
            Spacer(minLength: DS.Space.sm)
            Text(row.1).font(DS.Font.data).foregroundStyle(DS.ink)
          }
          .accessibilityElement(children: .combine)
        }
        Text(starter.note).font(.footnote).foregroundStyle(DS.ink2)
          .fixedSize(horizontal: false, vertical: true)
        SteelButton(title: "Brew", action: brew)
          .accessibilityLabel("Brew \(starter.name)")
          .accessibilityIdentifier("catalog.brew.\(starter.style.rawValue)")
      }
      .padding(DS.Space.md)
    }
  }
}

/// Words for catalog rows and starter recipes.
enum CatalogText {
  /// "Ethiopia · natural · light roast", leaving out what the catalog does not list.
  static func facts(_ coffee: RoasterCatalog.Coffee) -> String {
    [
      coffee.originCountry, coffee.process,
      coffee.roastLevel.map { $0.title.lowercased() + " roast" },
      coffee.isBlend ? "blend" : nil, coffee.isDecaf ? "decaf" : nil,
    ].compactMap { $0 }.joined(separator: "  ·  ")
  }

  /// Minutes and seconds, or hours for a cold-brew steep.
  static func duration(_ seconds: Int) -> String {
    seconds >= 3600 ? "\(seconds / 3600) h" : RecipeFormat.clock(seconds)
  }
}
