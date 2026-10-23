import NextCupKit
import SwiftData
import SwiftUI

/// What the bean editor sheet opens for.
enum BeanEditorTarget: Identifiable, Hashable {
  case new
  case edit(UUID)

  var id: String {
    switch self {
    case .new: "new"
    case .edit(let id): id.uuidString
    }
  }
}

/// Add a bean, or change one. Weight is typed in the user's unit and stored in
/// grams. An unsaved change blocks swipe-to-dismiss; Cancel discards it.
struct BeanEditorView: View {
  let target: BeanEditorTarget
  let close: () -> Void

  @Environment(\.modelContext) private var context
  @Query(sort: \Roaster.name) private var roasters: [Roaster]
  @Query private var beans: [Bean]
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var fields = BeanFields()
  @State private var original = BeanFields()
  @State private var weightText = ""
  @State private var hasRoastDate = false
  @State private var loaded = false
  @State private var error: String?
  @FocusState private var focused: Bool

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var bean: Bean? {
    guard case .edit(let id) = target else { return nil }
    return beans.first { $0.id == id }
  }

  private var service: BeanService { BeanService(store: Store(context: context)) }
  private var canSave: Bool { !fields.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  private var hasChanges: Bool {
    loaded && (fields != original || weightText != originalWeightText)
  }
  @State private var originalWeightText = ""

  /// The weight as typed, in grams; `nil` when blank or not a number.
  private var typedWeightG: Double? {
    let text = weightText.replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    guard let value = Double(text) else { return nil }
    return units.grams(fromDisplayWeight: value)
  }

  var body: some View {
    NavigationStack {
      Form {
        if let error {
          StateBanner(kind: .error, message: error)
            .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
            .accessibilityIdentifier("beans.editor.error")
        }
        basics
        origin
        roast
        bag
      }
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .background(DS.bg)
      .navigationTitle(bean == nil ? "New bean" : "Edit bean")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: close).accessibilityIdentifier("beans.editor.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save).disabled(!canSave)
            .accessibilityIdentifier("beans.editor.save")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = false }
        }
      }
      .task { load() }
      .interactiveDismissDisabled(hasChanges)
    }
    .accessibilityIdentifier("beans.editor")
  }

  // MARK: Sections

  private var basics: some View {
    Section("Bean") {
      TextField("Name", text: $fields.name)
        .textInputAutocapitalization(.words).submitLabel(.next).focused($focused)
        .frame(minHeight: DS.Size.control)
        .accessibilityLabel("Bean name")
        .accessibilityIdentifier("beans.editor.name")
      HStack {
        TextField("Roaster", text: $fields.roasterName)
          .textInputAutocapitalization(.words).submitLabel(.next).focused($focused)
          .accessibilityLabel("Roaster")
          .accessibilityIdentifier("beans.editor.roaster")
        if !roasters.isEmpty {
          Menu {
            ForEach(roasters) { roaster in
              Button(roaster.name) { fields.roasterName = roaster.name }
            }
          } label: {
            Image(systemName: "chevron.up.chevron.down")
              .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
          }
          .accessibilityLabel("Choose a saved roaster")
        }
      }
      .frame(minHeight: DS.Size.control)
      Toggle("Decaf", isOn: $fields.isDecaf).frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("beans.editor.decaf")
    }
    .listRowBackground(DS.paper)
  }

  private var origin: some View {
    Section("Origin") {
      field("Country", text: $fields.originCountry, id: "country")
      field("Region", text: $fields.region, id: "region")
      field("Farm or station", text: $fields.farm, id: "farm")
      field("Process", text: $fields.process, id: "process")
      field("Varietal", text: $fields.varietal, id: "varietal")
    }
    .listRowBackground(DS.paper)
  }

  private var roast: some View {
    Section("Roast") {
      Picker("Roast level", selection: $fields.roastLevel) {
        Text("Not set").tag(RoastLevel?.none)
        ForEach(RoastLevel.allCases, id: \.self) { Text($0.title).tag(RoastLevel?.some($0)) }
      }
      .frame(minHeight: DS.Size.control)
      .accessibilityIdentifier("beans.editor.roastLevel")
      Toggle("Roast date", isOn: $hasRoastDate).frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("beans.editor.hasRoastDate")
        .onChange(of: hasRoastDate) { _, isOn in
          fields.roastDate = isOn ? (fields.roastDate ?? Date()) : nil
        }
      if hasRoastDate {
        DatePicker(
          "Roasted on",
          selection: Binding(
            get: { fields.roastDate ?? Date() }, set: { fields.roastDate = $0 }),
          in: ...Date(), displayedComponents: .date
        )
        .frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("beans.editor.roastDate")
      }
    }
    .listRowBackground(DS.paper)
  }

  private var bag: some View {
    Section {
      HStack {
        TextField("Bag weight", text: $weightText)
          .keyboardType(.decimalPad).focused($focused)
          .accessibilityLabel("Bag weight in \(units.weight == .grams ? "grams" : "ounces")")
          .accessibilityIdentifier("beans.editor.bagWeight")
        Text(units.weightSymbol).foregroundStyle(DS.ink2).accessibilityHidden(true)
      }
      .frame(minHeight: DS.Size.control)
      Picker("Status", selection: $fields.status) {
        ForEach(BeanStatus.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      .frame(minHeight: DS.Size.control)
      .accessibilityIdentifier("beans.editor.status")
      TextField("Flavor notes on the bag", text: $fields.flavorNotes, axis: .vertical)
        .lineLimit(1...4).focused($focused)
        .frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("beans.editor.notes")
    } header: {
      Text("Bag")
    } footer: {
      Text("Separate flavor notes with commas. The amount left drops with each brew.")
    }
    .listRowBackground(DS.paper)
  }

  private func field(_ title: String, text: Binding<String>, id: String) -> some View {
    TextField(title, text: text)
      .textInputAutocapitalization(.words).submitLabel(.next).focused($focused)
      .frame(minHeight: DS.Size.control)
      .accessibilityLabel(title)
      .accessibilityIdentifier("beans.editor.\(id)")
  }

  // MARK: Actions

  private func load() {
    guard !loaded else { return }
    if let bean { fields = BeanFields(bean) }
    hasRoastDate = fields.roastDate != nil
    weightText = fields.bagWeightG.map { RecipeFormat.weight($0, units, withSymbol: false) } ?? ""
    original = fields
    originalWeightText = weightText
    loaded = true
  }

  private func save() {
    let trimmed = weightText.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty && typedWeightG == nil {
      error = "The bag weight is not a number."
      return
    }
    // An untouched weight keeps its stored grams: the field shows it rounded.
    if weightText != originalWeightText {
      fields.bagWeightG = trimmed.isEmpty ? nil : typedWeightG
    }
    switch service.save(fields, editing: bean) {
    case .success: close()
    case .failure(let failure): error = failure.message
    }
  }
}
