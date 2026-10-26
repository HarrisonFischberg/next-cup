import NextCupKit
import SwiftData
import SwiftUI

/// What the recipe editor sheet opens for.
enum RecipeEditorTarget: Identifiable, Hashable {
  case new
  /// Edit one of the user's own recipes in place.
  case edit(UUID)
  /// Save a changed copy; the original (a built-in, or a recipe being duplicated) stays.
  case copy(UUID)

  var id: String {
    switch self {
    case .new: "new"
    case .edit(let id): "edit-\(id.uuidString)"
    case .copy(let id): "copy-\(id.uuidString)"
    }
  }
}

/// S08: create or change a recipe, with every step kind. Weights and temperature
/// are typed in the user's units. Removing a step offers Undo.
struct RecipeEditorView: View {
  let target: RecipeEditorTarget
  /// A new recipe starts on this method (Your Style on a method's styles page).
  var methodID: UUID?
  let close: (Recipe?) -> Void

  @Environment(\.modelContext) private var context
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var fields = RecipeEditorFields()
  @State private var original = RecipeEditorFields()
  @State private var loaded = false
  @State private var error: String?
  @State private var saving = false
  @State private var removed: (index: Int, step: RecipeEditorFields.StepFields)?
  @FocusState private var focused: Bool

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var service: RecipeEditorService { RecipeEditorService(store: Store(context: context)) }
  private var hasChanges: Bool { loaded && fields != original }
  private var canSave: Bool {
    !fields.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !saving
  }

  private var title: String {
    switch target {
    case .new: "New recipe"
    case .edit: "Edit recipe"
    case .copy: "Customize recipe"
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        if let error {
          StateBanner(kind: .error, message: error)
            .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
            .accessibilityIdentifier("recipe.editor.error")
        }
        if case .copy = target {
          Text("Your changes are saved as a new recipe. The original stays as it is.")
            .font(.footnote).foregroundStyle(DS.ink2)
            .listRowBackground(DS.bg)
        }
        basics
        numbers
        stepsSection
        notes
      }
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .background(DS.bg)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { close(nil) }.accessibilityIdentifier("recipe.editor.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save).disabled(!canSave)
            .accessibilityIdentifier("recipe.editor.save")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = false }
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if let removed {
          SteelToast(message: "Step removed", actionTitle: "Undo") { undoRemove(removed) }
            .accessibilityIdentifier("recipe.editor.undo")
        }
      }
      .task { load() }
      .interactiveDismissDisabled(hasChanges)
    }
    .accessibilityIdentifier("recipe.editor")
  }

  // MARK: Sections

  private var basics: some View {
    Section("Recipe") {
      TextField("Name", text: $fields.name)
        .textInputAutocapitalization(.words).submitLabel(.next).focused($focused)
        .frame(minHeight: DS.Size.control)
        .accessibilityLabel("Recipe name")
        .accessibilityIdentifier("recipe.editor.name")
      Picker("Method", selection: $fields.methodID) {
        Text("No method").tag(UUID?.none)
        ForEach(methods) { method in
          Text(method.name + (method.isHidden ? " (hidden)" : "")).tag(UUID?.some(method.id))
        }
      }
      .frame(minHeight: DS.Size.control)
      .accessibilityIdentifier("recipe.editor.method")
    }
    .listRowBackground(DS.paper)
  }

  private var numbers: some View {
    Section {
      numberField("Dose", unit: units.weightSymbol, text: $fields.dose, id: "dose")
      numberField("Water", unit: units.weightSymbol, text: $fields.water, id: "water")
      numberField(
        "Temperature", unit: units.temperatureSymbol, text: $fields.temperature, id: "temperature")
      HStack {
        Text("Total time")
        Spacer()
        TextField("m:ss", text: $fields.time)
          .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
          .font(DS.Font.data).focused($focused).frame(maxWidth: 120)
          .accessibilityLabel("Total time, minutes and seconds")
          .accessibilityIdentifier("recipe.editor.time")
      }
      .frame(minHeight: DS.Size.control)
      Toggle("Poured over ice", isOn: $fields.includesIce)
        .frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("recipe.editor.ice.toggle")
      if fields.includesIce {
        numberField("Ice", unit: units.weightSymbol, text: $fields.ice, id: "ice")
      }
    } header: {
      Text("Numbers")
    } footer: {
      Text("Water is the hot water. Step targets are running totals of water poured.")
    }
    .listRowBackground(DS.paper)
  }

  private func numberField(_ label: String, unit: String, text: Binding<String>, id: String)
    -> some View
  {
    HStack {
      Text(label)
      Spacer()
      TextField("0", text: text)
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        .font(DS.Font.data).focused($focused).frame(maxWidth: 120)
        .accessibilityLabel("\(label), \(unit)")
        .accessibilityIdentifier("recipe.editor.\(id)")
      Text(unit).font(DS.Font.mono(.callout)).foregroundStyle(DS.ink2).accessibilityHidden(true)
    }
    .frame(minHeight: DS.Size.control)
  }

  private var stepsSection: some View {
    Section {
      ForEach($fields.steps) { $step in
        stepEditor($step)
      }
      Button {
        addStep()
      } label: {
        Label("Add step", systemImage: "plus").frame(
          minHeight: DS.Size.control, alignment: .leading)
      }
      .accessibilityIdentifier("recipe.editor.step.add")
    } header: {
      Text("Steps")
    } footer: {
      Text("Steps run in time order. Leave water empty for steps that pour nothing.")
    }
    .listRowBackground(DS.paper)
  }

  private func stepEditor(_ step: Binding<RecipeEditorFields.StepFields>) -> some View {
    let index = fields.steps.firstIndex { $0.id == step.wrappedValue.id } ?? 0
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack {
        Text("STEP \(index + 1)").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityHidden(true)
        Spacer()
        Menu {
          Button("Move up", systemImage: "arrow.up") { moveStep(index, by: -1) }
            .disabled(index == 0)
          Button("Move down", systemImage: "arrow.down") { moveStep(index, by: 1) }
            .disabled(index >= fields.steps.count - 1)
          Button("Remove step", systemImage: "trash", role: .destructive) { removeStep(index) }
        } label: {
          Image(systemName: "ellipsis.circle").font(.title3)
            .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
        }
        .accessibilityLabel("Step \(index + 1) actions")
        .accessibilityIdentifier("recipe.editor.step.\(index).menu")
      }
      Picker("Kind", selection: step.kind) {
        ForEach(StepKind.allCases, id: \.self) { Text(RecipeFormat.title($0)).tag($0) }
      }
      .accessibilityLabel("Step \(index + 1) kind")
      .accessibilityIdentifier("recipe.editor.step.\(index).kind")
      HStack(spacing: DS.Space.md) {
        labelledField("At", placeholder: "m:ss", text: step.time, keyboard: .numbersAndPunctuation)
          .accessibilityLabel("Step \(index + 1) start time, minutes and seconds")
          .accessibilityIdentifier("recipe.editor.step.\(index).time")
        labelledField(
          "Water", placeholder: units.weightSymbol, text: step.water, keyboard: .decimalPad
        )
        .accessibilityLabel("Step \(index + 1) running water, \(units.weightSymbol)")
        .accessibilityIdentifier("recipe.editor.step.\(index).water")
      }
      TextField("Instruction", text: step.instruction, axis: .vertical)
        .font(.subheadline).focused($focused).frame(minHeight: DS.Size.minTap)
        .accessibilityLabel("Step \(index + 1) instruction")
        .accessibilityIdentifier("recipe.editor.step.\(index).instruction")
    }
    .padding(.vertical, DS.Space.xs)
  }

  private func labelledField(
    _ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType
  ) -> some View {
    HStack {
      Text(label).font(.footnote).foregroundStyle(DS.ink2).accessibilityHidden(true)
      TextField(placeholder, text: text).keyboardType(keyboard).font(DS.Font.data)
        .focused($focused).frame(minHeight: DS.Size.minTap)
    }
  }

  private var notes: some View {
    Section("Notes") {
      TextField("Tuning note", text: $fields.tuningNote, axis: .vertical)
        .focused($focused).frame(minHeight: DS.Size.control, alignment: .top)
        .accessibilityIdentifier("recipe.editor.note")
      TextField("Credit (who wrote this recipe)", text: $fields.credit)
        .textInputAutocapitalization(.words).focused($focused)
        .frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("recipe.editor.credit")
    }
    .listRowBackground(DS.paper)
  }

  // MARK: Actions

  private func load() {
    guard !loaded else { return }
    var loadedFields = RecipeEditorFields()
    switch target {
    case .new:
      loadedFields.methodID = methodID ?? methods.first { !$0.isHidden }?.id
      loadedFields.steps = [RecipeEditorFields.StepFields()]
    case .edit(let id), .copy(let id):
      guard let recipe = try? Store(context: context).find(Recipe.self, id: id) else {
        error = RecipeEditorError.notFound.message
        loaded = true
        return
      }
      var isCopy = false
      if case .copy = target { isCopy = true }
      loadedFields = RecipeEditorFields(
        draft: service.draft(from: recipe, asCopy: isCopy), units: units)
    }
    fields = loadedFields
    original = loadedFields
    loaded = true
  }

  private func addStep() {
    var step = RecipeEditorFields.StepFields()
    if let last = fields.steps.last, let seconds = RecipeEditorFields.parseClock(last.time) {
      step.time = RecipeFormat.clock(seconds + 30)
    } else {
      step.time = RecipeFormat.clock(0)
    }
    fields.steps.append(step)
  }

  private func moveStep(_ index: Int, by offset: Int) {
    let target = index + offset
    guard fields.steps.indices.contains(index), fields.steps.indices.contains(target) else {
      return
    }
    fields.steps.swapAt(index, target)
  }

  private func removeStep(_ index: Int) {
    guard fields.steps.indices.contains(index) else { return }
    removed = (index, fields.steps.remove(at: index))
    Task {
      try? await Task.sleep(for: .seconds(6))
      removed = nil
    }
  }

  private func undoRemove(_ item: (index: Int, step: RecipeEditorFields.StepFields)) {
    fields.steps.insert(item.step, at: min(item.index, fields.steps.count))
    removed = nil
  }

  private func save() {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    switch fields.draft(units: units) {
    case .failure(let failure):
      error = failure.message
    case .success(let draft):
      switch service.save(draft) {
      case .success(let recipe): close(recipe)
      case .failure(let failure): error = failure.message
      }
    }
  }
}
