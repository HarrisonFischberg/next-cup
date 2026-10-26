import NextCupKit
import SwiftData
import SwiftUI
import UIKit

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
  @Query private var grinders: [Grinder]
  @Query(sort: \Bean.name) private var allBeans: [Bean]
  @State private var beanID: UUID?
  @State private var grindSetting = ""
  @State private var doseText = ""
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""

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
        beansPicker
        if startFailed {
          StateBanner(kind: .error, message: "This recipe cannot be timed. Check its steps.")
        }
        doseControls
        specGrid
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
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      // The number pad has no return key; Done puts it away.
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
      }
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

  private var doseControls: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      StepperTile(
        title: "Dose", value: RecipeFormat.weight(doseG, units, withSymbol: false),
        unit: units.weightSymbol, target: RecipeFormat.weight(recipe.doseG, units),
        down: { adjustDose(by: -stepG) }, up: { adjustDose(by: stepG) },
        minusLabel: "Decrease dose", plusLabel: "Increase dose",
        text: $doseText
      )
      .accessibilityIdentifier("recipe.dose")
      .onAppear { doseText = RecipeFormat.weight(doseG, units, withSymbol: false) }
      .onChange(of: doseText) { _, typed in setTypedDose(typed) }
      .onChange(of: doseG) { _, _ in
        // The steppers moved the dose: show it, unless it is what was just typed.
        let shown = RecipeFormat.weight(doseG, units, withSymbol: false)
        if parsedDose(doseText) != parsedDose(shown) { doseText = shown }
      }
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
        PaperBox {
          SpecCell(
            label: "Time",
            value: RecipeFormat.clock(
              RecipeTiming.scaled(seconds, by: recipe.timingFactor(doseG: doseG))))
        }
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
              time: RecipeFormat.clock(
                RecipeTiming.scaled(step.startOffsetS, by: recipe.timingFactor(doseG: doseG))),
              name: RecipeFormat.title(step.kind),
              instruction: step.instruction.isEmpty ? nil : step.instruction,
              scale: target.map { RecipeFormat.weight($0, units) },
              showsDivider: index < steps.count - 1
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
  private var beans: [Bean] { allBeans.filter { $0.status == .inUse } }
  private var grinder: Grinder? { grinders.first { $0.id.uuidString == lastGrinderID } }

  /// The brew starts with which beans, then the guided numbers: grams of beans and water
  /// below, and the grind on the user's grinder (the bean's last grind when it has one).
  private var beansPicker: some View {
    let chosen = beans.first { $0.id == beanID }
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Menu {
        ForEach(beans) { bean in
          Button(bean.roaster.map { "\(bean.name) · \($0.name)" } ?? bean.name) { choose(bean) }
        }
        Button("No beans") {
          beanID = nil
          grindSetting = ""
        }
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("BEANS").font(DS.Font.label).foregroundStyle(DS.ink2)
            Text(
              chosen?.name ?? (beans.isEmpty ? "Add beans in the Beans tab" : "Choose your beans")
            )
            .font(DS.Font.headline).foregroundStyle(chosen == nil ? DS.ink2 : DS.ink)
          }
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink2)
            .accessibilityHidden(true)
        }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .panel(DS.paper)
      }
      .disabled(beans.isEmpty)
      .accessibilityLabel("Beans")
      .accessibilityValue(chosen?.name ?? "None chosen")
      .accessibilityIdentifier("recipe.beans")
      if let grinder {
        let guide = GrinderGuide.find(grinder.name)
        let method = GrinderGuide.method(forMethodNamed: recipe.method?.name)
        let recommended = method.flatMap { guide?.recommended(for: $0) }
        VStack(alignment: .leading, spacing: DS.Space.xs) {
          HStack {
            Text("GRIND ON YOUR \(grinder.name.uppercased())").font(DS.Font.label)
              .foregroundStyle(DS.ink2)
            Spacer(minLength: DS.Space.sm)
            TextField(recommended ?? "Setting", text: $grindSetting)
              .multilineTextAlignment(.trailing)
              .font(DS.Font.mono(.title3, .bold)).frame(maxWidth: 120)
              .accessibilityLabel("Grind setting")
              .accessibilityIdentifier("recipe.grindSetting")
          }
          if let recommended, let guide {
            Text(
              "Start at \(recommended) \(guide.unitLabel). Go finer if it tastes sour, coarser if bitter."
            )
            .font(.footnote).foregroundStyle(DS.ink2)
            .accessibilityIdentifier("recipe.grindRecommended")
          }
        }
        .padding(DS.Space.md)
        .panel(DS.paper)
        .onAppear { if grindSetting.isEmpty, let recommended { grindSetting = recommended } }
      }
    }
    .onAppear {
      if beanID == nil, let first = beans.first { choose(first) }
    }
  }

  /// A typed dose in the user's unit; anything not a positive number is ignored.
  private func parsedDose(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
  }

  private func setTypedDose(_ text: String) {
    guard let shown = parsedDose(text) else { return }
    let grams = units.grams(fromDisplayWeight: shown)
    scaledDoseG = abs(grams - recipe.doseG) < 0.0001 ? nil : grams
  }

  /// Picks a bean and brings back its last grind, so the setup starts where it left off.
  private func choose(_ bean: Bean) {
    beanID = bean.id
    let last = (bean.brewUses ?? []).compactMap(\.brew)
      .filter { !$0.isDraft && !($0.grindSetting ?? "").isEmpty }
      .max { $0.date < $1.date }
    grindSetting = last?.grindSetting ?? grindSetting
  }

  private func startBrew() {
    do {
      var setup = try TimerPlanBuilder.setup(for: recipe, doseG: doseG)
      if let bean = beans.first(where: { $0.id == beanID }) {
        setup.beanID = bean.id
        setup.beanName = bean.name
      }
      setup.grinderID = grinder?.id
      setup.grindSetting = grindSetting.trimmingCharacters(in: .whitespaces)
      timerSetup = setup
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
