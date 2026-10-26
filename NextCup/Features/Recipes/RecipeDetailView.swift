import NextCupKit
import SwiftData
import SwiftUI

/// S07: one recipe with its step timeline and a dose stepper that rescales every
/// water target. Scaling is a view of the recipe; nothing is saved by it.
struct RecipeDetailView: View {
  let link: DeepLink
  @Query private var matches: [Recipe]

  init(link: DeepLink, recipeID: UUID) {
    self.link = link
    _matches = Query(filter: #Predicate<Recipe> { $0.id == recipeID })
  }

  var body: some View {
    Group {
      if let recipe = matches.first {
        RecipeDetailContent(recipe: recipe)
      } else {
        ScrollView {
          EmptyState(
            title: "Recipe not found",
            message: "This recipe is no longer in your library. Open Recipes to pick another.")
        }
      }
    }
    .background(DS.bg)
    .navigationTitle(matches.first?.name ?? "Recipe")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier(link.identifier)
  }
}

private struct RecipeDetailContent: View {
  let recipe: Recipe
  @State private var scaledDoseG: Double?
  @State private var timerSetup: TimerSetup?
  @State private var startFailed = false
  @State private var editor: RecipeEditorTarget?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
  @Query private var grinders: [Grinder]
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""

  /// This recipe and the other built-in versions of it, the original first.
  private var versions: [Recipe] {
    guard let family = recipe.family else { return [] }
    return allRecipes.filter { $0.family == family }.sorted { !$0.isVersion && $1.isVersion }
  }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var doseG: Double { scaledDoseG ?? recipe.doseG }

  /// One tap on the dose stepper: 0.5 g, or 0.05 oz when the units are ounces.
  private var stepG: Double { units.grams(fromDisplayWeight: units.weight == .grams ? 0.5 : 0.05) }

  private var scaled: ScaledRecipe? {
    try? RecipeScaler.scale(recipe.scalable, toDose: doseG)
  }

  var body: some View {
    let steps = recipe.orderedSteps
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        header
        if versions.count > 1 { versionList }
        if startFailed {
          StateBanner(kind: .error, message: "This recipe cannot be timed. Check its steps.")
        }
        doseControls
        specGrid
        grindHint
        if let note = recipe.tuningNote, !note.isEmpty {
          KraftNote { Text(note).font(DS.Font.note).foregroundStyle(DS.onKraft) }
        }
        if let notes = scaled?.notes, scaledDoseG != nil, !notes.isEmpty {
          VStack(alignment: .leading, spacing: DS.Space.xs) {
            ForEach(notes, id: \.self) { Text($0).font(.footnote).foregroundStyle(DS.ink2) }
          }
          .accessibilityElement(children: .combine)
        }
        timeline(steps)
        credit
      }
      .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !steps.isEmpty {
        SteelButton(title: "Start brew", action: startBrew)
          .accessibilityIdentifier("recipe.start")
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
          .background(DS.bg, ignoresSafeAreaEdges: .bottom)
          .overlay(alignment: .top) { Hairline() }
      }
    }
    .navigationDestination(item: $timerSetup) { TimerView(setup: $0) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if recipe.builtInKey == nil {
            Button("Edit", systemImage: "pencil") { editor = .edit(recipe.id) }
          }
          Button(
            recipe.builtInKey == nil ? "Duplicate" : "Customize",
            systemImage: recipe.builtInKey == nil ? "plus.square.on.square" : "slider.horizontal.3"
          ) { editor = .copy(recipe.id) }
        } label: {
          Label("Recipe actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("recipe.menu")
      }
    }
    .sheet(item: $editor) { target in
      RecipeEditorView(target: target) { _ in editor = nil }
    }
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(recipe.name.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      if let method = recipe.method?.name {
        Text(method).font(.subheadline).foregroundStyle(DS.ink2)
      }
    }
  }

  /// Other takes on this recipe from around the web, each with its credit on its own page.
  private var versionList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("PICK A VERSION").font(DS.Font.label).foregroundStyle(DS.ink2)
        .frame(minHeight: 32, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        VStack(spacing: 0) {
          ForEach(versions) { version in
            let row = HStack(spacing: DS.Space.sm) {
              VStack(alignment: .leading, spacing: 2) {
                Text(version.name).font(DS.Font.headline).foregroundStyle(DS.ink)
                Text(
                  RecipeFormat.weight(version.doseG, units) + " : "
                    + RecipeFormat.weight(version.waterG, units)
                    + (version.credit.map { "  ·  \($0)" } ?? "")
                )
                .font(.footnote).foregroundStyle(DS.ink2)
              }
              Spacer(minLength: DS.Space.sm)
              Image(systemName: version.id == recipe.id ? "checkmark" : "chevron.right")
                .font(.footnote.weight(.semibold)).foregroundStyle(DS.ink2)
                .accessibilityHidden(true)
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
            .contentShape(Rectangle())
            if version.id == recipe.id {
              row.accessibilityElement(children: .combine).accessibilityAddTraits(.isSelected)
            } else {
              NavigationLink(value: DeepLink.recipe(version.id)) { row }.buttonStyle(.plain)
                .accessibilityIdentifier("recipe.version.\(version.id.uuidString)")
            }
            if version.id != versions.last?.id { Hairline() }
          }
        }
      }
    }
    .accessibilityIdentifier("recipe.versions")
  }

  /// The last-used grinder's starting range for this method, from the bundled guide.
  @ViewBuilder private var grindHint: some View {
    let grinder = grinders.first { $0.id.uuidString == lastGrinderID }
    if let guide = GrinderGuide.find(grinder?.name),
      let method = GrinderGuide.method(forMethodNamed: recipe.method?.name),
      let range = guide.range(for: method)
    {
      PaperBox {
        SpecCell(
          label: "Grind on your \(guide.name)",
          value: "\(range) \(guide.unitLabel)")
      }
      .accessibilityIdentifier("recipe.grind")
    }
  }

  private var doseControls: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      StepperTile(
        title: "Dose", value: RecipeFormat.weight(doseG, units, withSymbol: false),
        unit: units.weightSymbol, target: RecipeFormat.weight(recipe.doseG, units),
        down: { adjustDose(by: -stepG) }, up: { adjustDose(by: stepG) },
        minusLabel: "Decrease dose", plusLabel: "Increase dose"
      )
      .accessibilityIdentifier("recipe.dose")
      if scaledDoseG != nil {
        Button {
          scaledDoseG = nil
        } label: {
          Text("RESET TO RECIPE DOSE").font(DS.Font.label).foregroundStyle(DS.ink)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
        }
        .accessibilityIdentifier("recipe.dose.reset")
      }
    }
  }

  private var specGrid: some View {
    let current = scaled?.recipe ?? recipe.scalable
    let ratio = BrewMath.ratioLabel(
      BrewMath.ratio(
        doseG: current.doseG, waterG: current.waterG,
        iceG: current.includesIce ? current.iceG : nil))
    let columns =
      dts.isAccessibilitySize
      ? [GridItem(.flexible())]
      : [GridItem(.flexible(), spacing: DS.Space.sm), GridItem(.flexible())]
    return LazyVGrid(columns: columns, spacing: DS.Space.sm) {
      ReadoutTile(
        title: current.includesIce ? "Hot water" : "Water",
        value: RecipeFormat.weight(current.waterG, units)
      )
      .accessibilityIdentifier("recipe.water")
      if current.includesIce, let ice = current.iceG {
        ReadoutTile(title: "Ice", value: RecipeFormat.weight(ice, units))
          .accessibilityIdentifier("recipe.ice")
      }
      if let ratio {
        ReadoutTile(title: "Ratio", value: ratio).accessibilityIdentifier("recipe.ratio")
      }
      if let tempC = recipe.tempC {
        PaperBox { SpecCell(label: "Temperature", value: RecipeFormat.temperature(tempC, units)) }
      }
      if let seconds = recipe.totalTimeS {
        PaperBox { SpecCell(label: "Time", value: RecipeFormat.clock(seconds)) }
      }
    }
  }

  private func timeline(_ steps: [RecipeStep]) -> some View {
    let scaledSteps = scaled?.recipe.steps ?? recipe.scalable.steps
    return VStack(alignment: .leading, spacing: 0) {
      ColumnHeader(leading: "T+", middle: "Step", trailing: "Water")
      PaperBox {
        VStack(spacing: 0) {
          if steps.isEmpty {
            Text("This recipe has no steps yet.").font(.body).foregroundStyle(DS.ink2)
              .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
          }
          ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
            let target = index < scaledSteps.count ? scaledSteps[index].targetCumulativeWaterG : nil
            OperationRow(
              time: RecipeFormat.clock(step.startOffsetS), name: RecipeFormat.title(step.kind),
              instruction: step.instruction.isEmpty ? nil : step.instruction,
              scale: target.map { RecipeFormat.weight($0, units) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
              RecipeFormat.spokenStep(
                kind: step.kind, startOffsetS: step.startOffsetS, targetG: target, units: units)
            )
            .accessibilityHint(step.instruction)
            .accessibilityIdentifier("recipe.step.\(index)")
          }
        }
      }
    }
  }

  @ViewBuilder private var credit: some View {
    if let credit = recipe.credit, !credit.isEmpty {
      if let url = recipe.creditURL {
        Link("Recipe credit: \(credit)", destination: url)
          .font(.footnote).foregroundStyle(DS.ink).frame(minHeight: DS.Size.minTap)
      } else {
        Text("Recipe credit: \(credit)").font(.footnote).foregroundStyle(DS.ink2)
      }
    }
  }

  // MARK: Actions

  /// Starts the guided timer at the dose on screen.
  private func startBrew() {
    do {
      timerSetup = try TimerPlanBuilder.setup(for: recipe, doseG: doseG)
      startFailed = false
    } catch {
      startFailed = true
    }
  }

  private func adjustDose(by delta: Double) {
    let next = ((doseG + delta) * 100).rounded() / 100
    guard next >= stepG else { return }
    scaledDoseG = abs(next - recipe.doseG) < 0.0001 ? nil : next
  }
}

extension Recipe {
  /// Built-in versions share a key prefix: "cone-balanced" and "cone-balanced/strong".
  var family: String? { builtInKey?.split(separator: "/").first.map(String.init) }
  var isVersion: Bool { builtInKey?.contains("/") == true }
}
