import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// S07, Recipe setup: the recipe's brewer as a hero, then beans, grinder, the editable
/// dose, the numbers calculated from it, a compact step preview and Start brew.
/// Scaling is a view of the recipe; nothing is saved by it.
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
    .toolbar(removing: .title)
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
  /// A recipe saved from "Change steps", opened on top so the user brews it next.
  @State private var savedCopy: UUID?
  @State private var showsInstructions = false
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @Environment(\.dynamicTypeSize) private var dts
  @Environment(\.modelContext) private var modelContext
  @Query private var grinders: [Grinder]
  @Query(sort: \Bean.name) private var allBeans: [Bean]
  @State private var beanID: UUID?
  @State private var addingBean = false
  @State private var grindSetting = ""
  @State private var doseText = ""
  @FocusState private var typingDose: Bool
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""
  @AppStorage(BrewYield.unitKey) private var yieldUnit = BrewYield.defaultUnit.rawValue
  /// The amount turned to on the wheel, in `yieldUnit`; nil keeps the recipe's dose.
  @State private var yieldAmount: Double?
  /// The dose the amount set; typing another dose lets the amount go.
  @State private var yieldDoseG: Double?
  @State private var tuning: BrewSizeAI.Tuning?
  @State private var tuningFailed = false
  /// A keyed cloud provider gets the batch only after this tap; Apple's model needs none.
  @State private var tuningRequested = false

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var doseG: Double { scaledDoseG ?? recipe.doseG }

  /// The finished coffee asked for, in grams (1 ml of coffee weighs about 1 g).
  private var yieldG: Double? {
    yieldAmount.map { $0 * yieldMeasure.millilitres }
  }

  private var yieldMeasure: BrewYield { BrewYield(rawValue: yieldUnit) ?? .ml }

  /// The amount wheel: the amount picked, or the stop nearest what the recipe makes
  /// (its water less what the grounds keep).
  private var shownYield: Binding<Double> {
    Binding(
      get: {
        yieldAmount
          ?? yieldMeasure.nearest(
            toMillilitres: recipe.waterG - BrewMath.absorption * recipe.doseG)
          ?? yieldMeasure.options[0]
      },
      set: { yieldAmount = $0 })
  }

  /// One tap on the dose stepper: 0.5 g, or 0.05 oz when the units are ounces.
  private var stepG: Double { units.grams(fromDisplayWeight: units.weight == .grams ? 0.5 : 0.05) }

  private var scaled: ScaledRecipe? {
    try? RecipeScaler.scale(recipe.scalable, toDose: doseG)
  }

  var body: some View {
    let steps = recipe.orderedSteps
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        hero
        if startFailed {
          StateBanner(kind: .error, message: "This recipe cannot be timed. Check its steps.")
        }
        VStack(spacing: 0) {
          beansRow
          Hairline().opacity(0.5).padding(.horizontal, DS.Space.md)
          grinderRow
        }
        .panel(DS.paper)
        yieldControls
        doseControls
        calculated
        if let notes = scaled?.notes, scaledDoseG != nil, !notes.isEmpty {
          VStack(alignment: .leading, spacing: DS.Space.xs) {
            ForEach(notes, id: \.self) { Text($0).font(.footnote).foregroundStyle(DS.ink2) }
          }
          .accessibilityElement(children: .combine)
        }
        stepPreview(steps)
        credit
      }
      .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.lg)
      .dialPopups()
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !steps.isEmpty {
        SteelButton(title: "Start brew", action: startBrew)
          .accessibilityIdentifier("recipe.start")
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
          .background(DS.bg, ignoresSafeAreaEdges: .bottom)
          .overlay(alignment: .top) { Hairline().opacity(0.5) }
          .hiddenWhileTyping()
      }
    }
    .navigationDestination(item: $timerSetup) { TimerView(setup: $0) }
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      // The number pad has no return key; Done puts it away.
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { typingDose = false }
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
      RecipeEditorView(target: target) { saved in
        editor = nil
        // Only a "Change steps" copy opens on top; Customize keeps the user where they were.
        if case .prepared = target, let saved { savedCopy = saved.id }
      }
    }
    .navigationDestination(item: $savedCopy) { id in
      RecipeDetailView(link: .recipe(id), recipeID: id)
    }
  }

  // MARK: Sections

  /// The title and method beside the brewer on a colour block.
  private var hero: some View {
    let stacked = dts.isAccessibilitySize
    let layout =
      stacked
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.md))
      : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Space.md))
    return layout {
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        Text(recipe.name.dsTitle).font(DS.Font.instruction).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap).minimumScaleFactor(0.7)
          .accessibilityAddTraits(.isHeader)
        if let method = recipe.method?.name {
          Text(method).font(.subheadline.weight(.medium)).foregroundStyle(DS.ink2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if !stacked {
        BrewHero(
          glyph: recipe.method?.glyph ?? .cup, methodKey: recipe.method?.builtInKey, role: .setup,
          size: 132)
      }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .colorBlock()
  }

  private var beans: [Bean] { allBeans.filter { $0.status == .inUse } }
  private var grinder: Grinder? { grinders.first { $0.id.uuidString == lastGrinderID } }

  /// Which beans; the bean's last grind comes back with it.
  private var beansRow: some View {
    let chosen = beans.first { $0.id == beanID }
    return Menu {
      ForEach(beans) { bean in
        Button(bean.roaster.map { "\(bean.name) · \($0.name)" } ?? bean.name) { choose(bean) }
      }
      Button("No beans") {
        beanID = nil
        grindSetting = ""
      }
      Divider()
      Button("Add new beans", systemImage: "plus") { addingBean = true }
        .accessibilityIdentifier("recipe.addBean")
    } label: {
      LabeledRow(
        symbol: "leaf.fill", label: "Beans",
        value: chosen?.name ?? (beans.isEmpty ? "Add your beans" : "Choose your beans"),
        valueColor: chosen == nil ? DS.ink2 : DS.ink
      ) {
        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(DS.ink2)
          .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
    }
    .accessibilityLabel("Beans")
    .accessibilityValue(chosen?.name ?? "None chosen")
    .accessibilityIdentifier("recipe.beans")
    // Same sheet as the Beans tab +; Cancel leaves the current pick alone.
    .sheet(isPresented: $addingBean) {
      BeanEditorView(target: .new, onSaved: { choose($0) }) { addingBean = false }
    }
    .onAppear {
      if beanID == nil, let first = beans.first { choose(first) }
    }
  }

  /// The grind on the user's grinder, with the guide's starting point and the short tuning rule.
  @ViewBuilder private var grinderRow: some View {
    if let grinder {
      let guide = GrinderGuide.find(grinder.name)
      let method = GrinderGuide.method(forMethodNamed: recipe.method?.name)
      let recommended = method.flatMap { guide?.recommended(for: $0) }
      VStack(alignment: .leading, spacing: 0) {
        LabeledRow(symbol: "dial.low.fill", label: "Grinder setting", value: grinder.name) {
          EmptyView()
        }
        GrindWheel(
          setting: $grindSetting, grinderName: grinder.name, identifier: "recipe.grindSetting",
          dial: true)
        if let recommended, let guide {
          Text(
            "Start at \(recommended) \(guide.unitLabel)  ·  Finer if sour  ·  Coarser if bitter"
          )
          .font(.footnote).foregroundStyle(DS.ink2)
          .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.md)
          .accessibilityIdentifier("recipe.grindRecommended")
        }
      }
      .onAppear { if grindSetting.isEmpty, let recommended { grindSetting = recommended } }
    } else {
      LabeledRow(symbol: "dial.low.fill", label: "Grinder", value: "Set in Settings") {
        EmptyView()
      }
    }
  }

  /// "How much coffee?": an amount in oz, cups or ml sets the dose at the recipe's ratio,
  /// then the AI in Settings tunes temperature, time and grind for that batch.
  private var yieldControls: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: DS.Space.sm) {
        Image(systemName: "cup.and.saucer.fill").font(.body.weight(.semibold))
          .foregroundStyle(DS.accent).frame(width: 28).accessibilityHidden(true)
        Text("How much coffee?").font(.footnote).foregroundStyle(DS.ink2)
        Spacer(minLength: DS.Space.sm)
        // Tap buttons, not a wheel: a scroll past the card cannot change the unit.
        Picker("Unit", selection: $yieldUnit) {
          ForEach(BrewYield.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
        }
        .pickerStyle(.segmented).fixedSize()
        .accessibilityIdentifier("recipe.yield.unit")
      }
      .padding([.horizontal, .top], DS.Space.md)
      // Until it is stepped, the amount rests on what the recipe makes and the recipe's
      // dose stands.
      let amounts = yieldMeasure.options
      let names = amounts.map { $0.formatted(.number.precision(.fractionLength(0...1))) }
      DialStepper(
        title: "How much coffee", hint: "Hold for the dial", options: names,
        selection: Binding(
          get: { names[amounts.firstIndex(of: shownYield.wrappedValue) ?? 0] },
          set: { shownYield.wrappedValue = amounts[names.firstIndex(of: $0) ?? 0] }),
        unit: yieldMeasure.title, identifier: "recipe.yield")
      if yieldG != nil, let current = scaled?.recipe { pourLine(current) }
      if yieldG != nil { tuningRow }
    }
    .panel(DS.paper)
    .onChange(of: yieldAmount) { applyYield() }
    .onChange(of: yieldUnit) { old, new in
      // The amount carries over to the new unit, to the wheel's nearest stop.
      let ml = yieldAmount.map { $0 * (BrewYield(rawValue: old) ?? .ml).millilitres }
      yieldAmount = ml.flatMap { (BrewYield(rawValue: new) ?? .ml).nearest(toMillilitres: $0) }
      applyYield()
    }
    .onChange(of: doseG) { _, dose in
      // A dose typed or stepped by hand lets the amount (and its tuning) go.
      if let yieldDoseG, abs(dose - yieldDoseG) > 0.01 {
        self.yieldDoseG = nil
        yieldAmount = nil
      }
    }
    .task(id: TuningTrigger(doseG: yieldDoseG, requested: tuningRequested)) { await tune() }
  }

  /// The amount is what ends up in the cup, so say how much to pour for it and why it is more.
  @ViewBuilder private func pourLine(_ current: ScalableRecipe) -> some View {
    if let cup = BrewMath.cupG(waterG: current.totalWaterG, doseG: current.doseG) {
      let kept = current.totalWaterG - cup
      Text(
        kept > 0.5
          ? "Pour \(RecipeFormat.weight(current.totalWaterG, units)) of water. The grounds keep "
            + "about \(RecipeFormat.weight(kept, units)), so the rest is what reaches your cup."
          : "Pour \(RecipeFormat.weight(current.totalWaterG, units)); that is what reaches your cup."
      )
      .font(.footnote).foregroundStyle(DS.ink2)
      .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.sm)
      .accessibilityIdentifier("recipe.yield.pour")
    }
  }

  @ViewBuilder private var tuningRow: some View {
    let symbol =
      tuning == nil ? (tuningFailed ? "info.circle" : "sparkles") : "checkmark.seal.fill"
    HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
      Image(systemName: symbol).foregroundStyle(DS.accent).frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        if let tuning {
          Text(
            "\(tuning.source) tuned it: \(RecipeFormat.temperature(tuning.tempC, units))  ·  "
              + "\(RecipeFormat.clock(tuning.totalTimeS))  ·  grind \(tuning.grind)"
          )
          .font(.footnote.weight(.semibold)).foregroundStyle(DS.ink)
          if !tuning.note.isEmpty {
            Text(tuning.note).font(.footnote).foregroundStyle(DS.ink2)
          }
        } else if let provider = BrewSizeAI.cloudProviderTitle, !tuningRequested, !tuningFailed {
          Text("Dose and water follow the recipe's ratio.")
            .font(.footnote).foregroundStyle(DS.ink2)
          Button("Tune time, temperature and grind with \(provider)") {
            tuningRequested = true
          }
          .font(.footnote.weight(.semibold)).foregroundStyle(DS.accent)
          .accessibilityHint("Sends the recipe name, brewer and these numbers to \(provider)")
          .accessibilityIdentifier("recipe.yield.tune")
        } else if tuningFailed || !BrewSizeAI.isAvailable {
          Text(
            "Dose and water follow the recipe's ratio. Add a key in Settings > AI to tune time, "
              + "temperature and grind too."
          )
          .font(.footnote).foregroundStyle(DS.ink2)
        } else {
          Text("Tuning time, temperature and grind…").font(.footnote).foregroundStyle(DS.ink2)
        }
      }
      Spacer(minLength: 0)
      if tuning == nil, !tuningFailed, BrewSizeAI.isAvailable,
        BrewSizeAI.cloudProviderTitle == nil || tuningRequested
      {
        ProgressView()
      }
    }
    .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.md)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("recipe.yield.tuning")
  }

  /// Sets the dose that makes the amount asked for; water and steps follow it.
  private func applyYield() {
    tuning = nil
    tuningFailed = false
    tuningRequested = false
    let ratio = BrewMath.ratio(
      doseG: recipe.doseG, waterG: recipe.waterG,
      iceG: recipe.includesIce ? recipe.iceG : nil)
    guard let yieldG, let dose = BrewMath.dose(forYieldG: yieldG, ratio: ratio) else {
      yieldDoseG = nil
      return
    }
    let rounded = (dose * 10).rounded() / 10
    yieldDoseG = rounded
    scaledDoseG = abs(rounded - recipe.doseG) < 0.0001 ? nil : rounded
  }

  /// Waits for the wheel to settle, then asks the AI; a failure keeps the ratio's numbers.
  /// A keyed cloud provider is asked only after the tap (`tuningRequested`).
  private func tune() async {
    guard let yieldDoseG, let yieldG, BrewSizeAI.isAvailable else { return }
    let needsTap = BrewSizeAI.cloudProviderTitle != nil
    guard !needsTap || tuningRequested else { return }
    if !needsTap { try? await Task.sleep(for: .milliseconds(800)) }
    guard !Task.isCancelled, let scaled else { return }
    let payload = BrewSizeAI.payload(
      recipe: recipe.name, method: recipe.method?.name, recipeDoseG: recipe.doseG,
      doseG: yieldDoseG, waterG: scaled.recipe.totalWaterG, yieldG: yieldG,
      tempC: recipe.tempC, totalTimeS: recipe.totalTimeS)
    do {
      let answer = try await BrewSizeAI.tune(payload)
      guard !Task.isCancelled else { return }
      tuning = answer
    } catch {
      if !Task.isCancelled { tuningFailed = true }
    }
  }

  /// Dose: minus, the value (tap to type), plus. Water and ratio follow it below.
  private var doseControls: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: DS.Space.sm) {
        Image(systemName: "scalemass.fill").font(.body.weight(.semibold))
          .foregroundStyle(DS.accent).frame(width: 28).accessibilityHidden(true)
        Text("Dose").font(.footnote).foregroundStyle(DS.ink2).fixedSize()
        Spacer(minLength: DS.Space.sm)
        stepButton("minus", label: "Decrease dose") { adjustDose(by: -stepG) }
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          TextField("Dose", text: $doseText).font(DS.Font.dataLarge).keyboardType(.decimalPad)
            .multilineTextAlignment(.center).fixedSize().focused($typingDose)
            .accessibilityLabel("Dose").accessibilityHint("Type a value")
            .accessibilityIdentifier("stepper.dose.value")
          Text(units.weightSymbol).font(DS.Font.mono(.callout))
        }
        .foregroundStyle(DS.ink).frame(minWidth: 84)
        stepButton("plus", label: "Increase dose") { adjustDose(by: stepG) }
        Button {
          typingDose = true
        } label: {
          Image(systemName: "pencil").font(.body.weight(.semibold)).foregroundStyle(DS.accent)
            .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        }
        .accessibilityLabel("Type the dose")
      }
      .padding(DS.Space.md)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("recipe.dose")
      if scaledDoseG != nil {
        Button {
          scaledDoseG = nil
        } label: {
          Text("Reset to recipe \(RecipeFormat.weight(recipe.doseG, units))".dsTitle).font(
            .footnote.weight(.semibold)
          )
          .foregroundStyle(DS.signal)
          .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
          .padding(.horizontal, DS.Space.md)
        }
        .accessibilityIdentifier("recipe.dose.reset")
      }
    }
    .panel(DS.paper, border: DS.signal.opacity(0.5))
    .onAppear { doseText = RecipeFormat.weight(doseG, units, withSymbol: false) }
    .onChange(of: doseText) { _, typed in setTypedDose(typed) }
    .onChange(of: doseG) { _, _ in
      // The steppers moved the dose: show it, unless it is what was just typed.
      let shown = RecipeFormat.weight(doseG, units, withSymbol: false)
      if parsedDose(doseText) != parsedDose(shown) { doseText = shown }
    }
  }

  private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.body.weight(.heavy)).foregroundStyle(DS.accent)
        .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        .overlay(Circle().strokeBorder(DS.accent, lineWidth: 1.5))
    }
    .accessibilityLabel(label)
  }

  /// The numbers that follow from the dose, two by two on rules; editing happens above.
  private var calculated: some View {
    let current = scaled?.recipe ?? recipe.scalable
    let ratio = BrewMath.ratioLabel(
      BrewMath.ratio(
        doseG: current.doseG, waterG: current.waterG,
        iceG: current.includesIce ? current.iceG : nil))
    var figures: [(id: String, symbol: String, label: String, value: String)] = [
      (
        "recipe.water", "drop.fill", current.includesIce ? "Hot water" : "Water",
        RecipeFormat.weight(current.waterG, units)
      )
    ]
    if current.includesIce, let ice = current.iceG {
      figures.append(("recipe.ice", "snowflake", "Ice", RecipeFormat.weight(ice, units)))
    }
    if let ratio { figures.append(("recipe.ratio", "circle.grid.2x1.fill", "Ratio", ratio)) }
    if let tempC = tuning?.tempC ?? recipe.tempC {
      figures.append(
        (
          "recipe.temperature", "thermometer.medium", "Temperature",
          RecipeFormat.temperature(tempC, units)
        ))
    }
    if let seconds = recipe.totalTimeS {
      figures.append(
        (
          "recipe.time", "clock", "Time",
          RecipeFormat.clock(
            RecipeTiming.scaled(seconds, by: recipe.timingFactor(doseG: doseG, tuning: tuning)))
        ))
    }
    let columns =
      dts.isAccessibilitySize
      ? [GridItem(.flexible())]
      : [GridItem(.flexible(), spacing: DS.Space.md), GridItem(.flexible())]
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Kicker("Calculated from dose", color: DS.ink2)
      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(figures, id: \.id) { figure in
          Figure(symbol: figure.symbol, label: figure.label, value: figure.value)
            .overlay(alignment: .bottom) { Hairline().opacity(0.4) }
            .accessibilityIdentifier(figure.id)
        }
      }
    }
    .padding(DS.Space.md)
    .colorBlock(DS.kraft.opacity(0.6))
  }

  /// The steps as a timeline: time and name, and the full instructions on request.
  private func stepPreview(_ steps: [RecipeStep]) -> some View {
    let scaledSteps = scaled?.recipe.steps ?? recipe.scalable.steps
    let factor = recipe.timingFactor(doseG: doseG, tuning: tuning)
    return VStack(alignment: .leading, spacing: DS.Space.md) {
      SectionRule(title: "Brew steps") {
        if steps.contains(where: { !$0.instruction.isEmpty }) {
          Button(showsInstructions ? "Hide instructions" : "Show instructions") {
            showsInstructions.toggle()
          }
          .font(.subheadline.weight(.semibold)).foregroundStyle(DS.accent)
          .frame(minHeight: DS.Size.minTap)
          .accessibilityIdentifier("recipe.steps.instructions")
        }
      }
      if steps.isEmpty {
        Text("This recipe has no steps yet.").font(.body).foregroundStyle(DS.ink2)
      }
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
          let target = index < scaledSteps.count ? scaledSteps[index].targetCumulativeWaterG : nil
          TimelineRow(
            time: RecipeFormat.clock(RecipeTiming.scaled(step.startOffsetS, by: factor)),
            name: RecipeFormat.title(step.kind),
            detail: showsInstructions && !step.instruction.isEmpty ? step.instruction : nil,
            trailing: target.map { RecipeFormat.weight($0, units) },
            state: .upcoming, isLast: index == steps.count - 1
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
      SteelButton(title: "Change steps", kind: .secondary, action: changeSteps)
        .accessibilityHint("Add or change steps, with optional AI suggestions")
        .accessibilityIdentifier("recipe.steps.change")
      Text(
        editsInPlace
          ? "Add a step, change a pour or let AI suggest better steps."
          : "Add a step, change a pour or let AI suggest better steps. It saves as your own "
            + "recipe at this size; this one stays as it is."
      )
      .font(.footnote).foregroundStyle(DS.ink2)
    }
  }

  /// One of the user's own recipes at its own size is changed in place; anything else
  /// (a built-in, or a different size) becomes a new recipe.
  private var editsInPlace: Bool { recipe.builtInKey == nil && scaledDoseG == nil }

  private func changeSteps() {
    if editsInPlace {
      editor = .edit(recipe.id)
      return
    }
    let size =
      yieldAmount.map {
        "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(yieldMeasure.title)"
      } ?? (scaledDoseG == nil ? "mine" : "\(RecipeFormat.weight(doseG, units)) dose")
    let service = RecipeEditorService(store: Store(context: modelContext))
    editor = .prepared(
      service.draft(
        from: recipe, scaledTo: doseG, tuning: tuning, name: "\(recipe.name) (\(size))"))
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
      .filter { !($0.grindSetting ?? "").isEmpty }
      .max { $0.date < $1.date }
    grindSetting = last?.grindSetting ?? grindSetting
  }

  private func startBrew() {
    do {
      var setup = try TimerPlanBuilder.setup(for: recipe, doseG: doseG, tuning: tuning)
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

/// One step on a vertical timeline: a dot on a line, the time, the name, an optional
/// detail and an optional value on the right. Live steps fill the dot in the accent;
/// past ones dim.
struct TimelineRow: View {
  let time: String
  let name: String
  var detail: String?
  var trailing: String?
  var state: RowState = .upcoming
  var isLast = false
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    let live = state == .live
    let dim = state == .done
    HStack(alignment: .top, spacing: DS.Space.md) {
      VStack(spacing: 0) {
        Circle().strokeBorder(live || dim ? DS.signal : DS.line, lineWidth: 2)
          .background(Circle().fill(live ? DS.signal : (dim ? DS.signal.opacity(0.35) : .clear)))
          .frame(width: 12, height: 12).padding(.top, 5)
        if !isLast {
          Rectangle().fill(DS.line.opacity(0.5)).frame(width: 1.5).frame(maxHeight: .infinity)
        }
      }
      .accessibilityHidden(true)
      let layout =
        dts.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Space.md))
      layout {
        Text(time).font(DS.Font.mono(.subheadline, .semibold))
          .foregroundStyle(dim ? DS.ink2 : DS.ink).frame(minWidth: 44, alignment: .leading)
        VStack(alignment: .leading, spacing: 2) {
          Text(name).font(live ? .body.weight(.bold) : .body.weight(.semibold))
            .foregroundStyle(dim ? DS.ink2 : DS.ink)
          if let detail {
            Text(detail).font(.subheadline).foregroundStyle(DS.ink2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        if !dts.isAccessibilitySize { Spacer(minLength: DS.Space.sm) }
        if let trailing {
          Text(trailing).font(DS.Font.mono(.subheadline, .semibold))
            .foregroundStyle(dim ? DS.ink2 : DS.ink)
        }
      }
      .padding(.bottom, isLast ? 0 : DS.Space.md)
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(live ? .isSelected : [])
  }
}

extension Recipe {
  /// Built-in versions share a key prefix: "cone-balanced" and "cone-balanced/strong".
  var family: String? { builtInKey?.split(separator: "/").first.map(String.init) }
  var isVersion: Bool { builtInKey?.contains("/") == true }
}

/// What restarts the batch tuning: a new dose from the wheel, or the tap that sends it.
private struct TuningTrigger: Equatable {
  var doseG: Double?
  var requested: Bool
}
