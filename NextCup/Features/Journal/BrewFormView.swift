import NextCupKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// S02: the brew form. Opens blank, or prefilled from a finished timer run with
/// the recipe's targets shown beside each value. Every value is the user's: a
/// target never locks a field. Save sits in the bottom inset, so the keyboard
/// pushes it up instead of covering it.
struct BrewFormView: View {
  let seed: BrewFormSeed?
  /// A saved brew to change. Its values open in the form and Save updates it.
  var editing: Brew?
  /// A saved brew to repeat: its method, beans, amounts and grind open in a new
  /// brew, with the time reset.
  var repeating: Brew?
  var onSaved: (() -> Void)?

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var model: BrewFormModel?
  @State private var pickedPhoto: PhotosPickerItem?
  @FocusState private var focused: Field?
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private enum Field: Hashable { case grind, notes }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  var body: some View {
    Group {
      if let model {
        content(model)
      } else {
        Color.clear
      }
    }
    .background(DS.bg)
    .navigationTitle(editing != nil ? "Edit brew" : (repeating != nil ? "Brew again" : "New brew"))
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard model == nil else { return }
      model = BrewFormModel(
        seed: seed, editing: editing, repeating: repeating, store: Store(context: context),
        draftStore: editing.map { .editing($0.id) } ?? repeating.map { .repeating($0.id) }
          ?? .standard(),
        simulatesSaveFailure: Self.simulatesSaveFailure)
    }
  }

  private static var simulatesSaveFailure: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("-failBrewSave")
    #else
      false
    #endif
  }

  // MARK: Content

  @ViewBuilder
  private func content(_ model: BrewFormModel) -> some View {
    Group {
      if model.savedBrewID != nil {
        savedState
      } else {
        form(Bindable(model), model)
      }
    }
    .onChange(of: model.draft) { _, _ in model.draftChanged() }
    .onChange(of: scenePhase) { _, phase in if phase != .active { model.flushDraft() } }
    .onDisappear { model.flushDraft() }
    .onChange(of: pickedPhoto) { _, item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self) {
          await model.attachPhoto(data)
        }
        pickedPhoto = nil
      }
    }
  }

  private var savedState: some View {
    ScrollView {
      EmptyState(
        title: "Brew saved",
        message: editing != nil
          ? "Your changes are in your journal."
          : "It is in your journal. The draft has been cleared.",
        actionTitle: "Done",
        action: {
          onSaved?()
          dismiss()
        }
      )
      .accessibilityIdentifier("brewform.saved")
    }
  }

  private func form(_ binding: Bindable<BrewFormModel>, _ model: BrewFormModel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        header(model)
        if let notice = model.notice { noticeBanner(notice, model) }
        if let error = model.saveError {
          StateBanner(
            kind: .error, message: error, actionTitle: "Try again", action: { model.save() }
          )
          .accessibilityIdentifier("brewform.error")
        }
        if model.draft.endedEarly {
          StateBanner(
            kind: .info, message: "You ended this brew early. The time is what it reached.")
        }
        methodPicker(binding.draft, model)
        brewedRow(binding.draft.date)
        tiles(model)
        grindField(binding.draft.grindSetting)
        verdictRow(binding.draft.verdict)
        VStack(alignment: .leading, spacing: DS.Space.sm) {
          Text("GRADE").font(DS.Font.label).foregroundStyle(DS.ink2)
          GradeScale(halfSteps: binding.draft.ratingHalfSteps)
        }
        photoRow(model)
        notesField(binding.draft.notes)
      }
      .padding(DS.Space.lg)
      // Behind the fields, so a tap on empty space dismisses the keyboard
      // without stealing the tap from a field.
      .background {
        Color.clear.contentShape(Rectangle()).onTapGesture { focused = nil }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom, spacing: 0) { saveBar(model) }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focused = nil }
      }
    }
    // A marker, not an identifier on the scroll view: that would replace the
    // identifiers of every element inside it.
    .background {
      Color.clear.accessibilityElement()
        .accessibilityIdentifier(
          model.isEditing
            ? "brewform.edit"
            : (model.repeatingID != nil
              ? "brewform.again" : (seed == nil ? "brewform.blank" : "brewform.prefilled")))
    }
  }

  // MARK: Sections

  private func header(_ model: BrewFormModel) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(model.isEditing ? "EDIT BREW" : (model.repeatingID != nil ? "BREW AGAIN" : "NEW BREW"))
        .font(DS.Font.display).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      if let beans = model.draft.beans, !beans.isEmpty {
        Text("Same beans: " + beans.map(\.name).joined(separator: ", "))
          .font(.subheadline).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("brewform.beans")
      }
      if let seed {
        Text([seed.recipeName, seed.methodName].compactMap { $0 }.joined(separator: " · "))
          .font(.subheadline).foregroundStyle(DS.ink2)
      }
    }
  }

  private func noticeBanner(_ notice: FormNotice, _ model: BrewFormModel) -> some View {
    StateBanner(
      kind: notice.kind == .error ? .error : .info, message: notice.message,
      actionTitle: notice.kind == .info ? "Dismiss" : nil,
      action: notice.kind == .info ? { model.dismissNotice() } : nil
    )
    .accessibilityIdentifier("brewform.notice")
  }

  private func methodPicker(_ draft: Binding<BrewDraft>, _ model: BrewFormModel) -> some View {
    let visible = methods.filter { !$0.isHidden || $0.id == draft.wrappedValue.methodID }
    let current = visible.first { $0.id == draft.wrappedValue.methodID }
    return Menu {
      ForEach(visible) { method in
        Button(method.name) { draft.wrappedValue.methodID = method.id }
      }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("METHOD").font(DS.Font.label).foregroundStyle(DS.ink2)
          Text(current?.name ?? "Choose a method").font(DS.Font.headline).foregroundStyle(DS.ink)
            .multilineTextAlignment(.leading)
        }
        Spacer(minLength: DS.Space.sm)
        Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
          .accessibilityHidden(true)
      }
      .padding(DS.Space.md).frame(minHeight: DS.Size.control)
      .background(DS.paper, ignoresSafeAreaEdges: [])
      .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
    }
    .accessibilityLabel("Method")
    .accessibilityValue(current?.name ?? "None chosen")
    .accessibilityIdentifier("brewform.method")
  }

  /// The label stacks above the picker at accessibility sizes, so it never wraps
  /// letter by letter beside the date.
  private func brewedRow(_ date: Binding<Date>) -> some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
      : AnyLayout(HStackLayout(spacing: DS.Space.sm))
    return layout {
      Text("BREWED").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityHidden(true)
      if !dts.isAccessibilitySize { Spacer(minLength: 0) }
      DatePicker("Brewed", selection: date, in: ...Date())
        .labelsHidden().foregroundStyle(DS.ink)
    }
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
    .accessibilityElement(children: .contain)
  }

  private func tiles(_ model: BrewFormModel) -> some View {
    let targets = model.draft.targets
    let columns =
      dts.isAccessibilitySize
      ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    return LazyVGrid(columns: columns, spacing: DS.Space.md) {
      StepperTile(
        title: "Dose", value: weightText(model.draft.doseG), unit: unitText(model.draft.doseG),
        target: targets?.doseG.map { RecipeFormat.weight($0, units) },
        down: {
          model.stepWeight(
            \.doseG, direction: -1, units: units, gramStep: 0.1, ounceStep: 0.01,
            start: BrewFormModel.defaultDoseG)
        },
        up: {
          model.stepWeight(
            \.doseG, direction: 1, units: units, gramStep: 0.1, ounceStep: 0.01,
            start: BrewFormModel.defaultDoseG)
        }
      )
      .accessibilityIdentifier("brewform.dose")
      StepperTile(
        title: "Water", value: weightText(model.draft.waterG), unit: unitText(model.draft.waterG),
        target: targets?.waterG.map { RecipeFormat.weight($0, units) },
        down: {
          model.stepWeight(
            \.waterG, direction: -1, units: units, gramStep: 1, ounceStep: 0.05,
            start: BrewFormModel.defaultWaterG)
        },
        up: {
          model.stepWeight(
            \.waterG, direction: 1, units: units, gramStep: 1, ounceStep: 0.05,
            start: BrewFormModel.defaultWaterG)
        }
      )
      .accessibilityIdentifier("brewform.water")
      StepperTile(
        title: "Temperature",
        value: model.draft.tempC.map {
          String(format: "%.0f", units.displayTemperature(celsius: $0))
        }
          ?? "—",
        unit: model.draft.tempC == nil ? "" : units.temperatureSymbol,
        target: targets?.tempC.map { RecipeFormat.temperature($0, units) },
        down: { model.stepTemperature(direction: -1, units: units) },
        up: { model.stepTemperature(direction: 1, units: units) }
      )
      .accessibilityIdentifier("brewform.temperature")
      StepperTile(
        title: "Time", value: model.draft.totalTimeS.map(RecipeFormat.clock) ?? "—",
        target: targets?.totalTimeS.map(RecipeFormat.clock),
        down: { model.stepTime(direction: -1) }, up: { model.stepTime(direction: 1) },
        minusLabel: "Decrease Time by 5 seconds", plusLabel: "Increase Time by 5 seconds"
      )
      .accessibilityIdentifier("brewform.time")
      ReadoutTile(title: "Ratio", value: model.ratioLabel ?? "—")
        .accessibilityIdentifier("brewform.ratio")
    }
  }

  private func weightText(_ grams: Double?) -> String {
    grams.map { RecipeFormat.weight($0, units, withSymbol: false) } ?? "—"
  }

  private func unitText(_ grams: Double?) -> String {
    grams == nil ? "" : units.weightSymbol
  }

  private func grindField(_ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text("GRIND SETTING").font(DS.Font.label).foregroundStyle(DS.ink2)
      TextField("e.g. 21 clicks", text: text)
        .font(DS.Font.mono(.body, .bold)).foregroundStyle(DS.ink)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .submitLabel(.done).focused($focused, equals: .grind)
        .onSubmit { focused = nil }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .background(DS.paper, ignoresSafeAreaEdges: [])
        .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        .accessibilityLabel("Grind setting")
        .accessibilityIdentifier("brewform.grind")
    }
  }

  private func verdictRow(_ verdict: Binding<String?>) -> some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: DS.Space.xs))
      : AnyLayout(HStackLayout(spacing: DS.Space.xs))
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("HOW IT TASTED").font(DS.Font.label).foregroundStyle(DS.ink2)
      layout {
        ForEach(Verdict.allCases, id: \.self) { option in
          ChoiceButton(
            title: option.rawValue.capitalized, isSelected: verdict.wrappedValue == option.rawValue
          ) {
            verdict.wrappedValue = verdict.wrappedValue == option.rawValue ? nil : option.rawValue
          }
          .accessibilityIdentifier("brewform.verdict.\(option.rawValue)")
        }
      }
    }
  }

  private func photoRow(_ model: BrewFormModel) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("PHOTO").font(DS.Font.label).foregroundStyle(DS.ink2)
      if let data = model.draft.photo, let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: 220)
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
          .accessibilityLabel("Photo of this brew")
        SteelButton(title: "Remove photo", kind: .secondary) { model.removePhoto() }
      } else {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
          Text("ADD A PHOTO").font(DS.Font.din(22, relativeTo: .title3))
            .frame(maxWidth: .infinity, minHeight: DS.Size.control)
            .foregroundStyle(DS.ink)
            .background(DS.paper, ignoresSafeAreaEdges: [])
            .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        }
        .accessibilityLabel("Add a photo")
        .accessibilityIdentifier("brewform.photo")
      }
      if let error = model.photoError { StateBanner(kind: .error, message: error) }
      Text("Location and camera details are removed from photos before they are kept.")
        .font(.footnote).foregroundStyle(DS.ink2)
    }
  }

  private func notesField(_ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("NOTES").font(DS.Font.label).foregroundStyle(DS.ink2)
      KraftNote {
        TextEditor(text: text)
          .font(DS.Font.note).foregroundStyle(DS.onKraft)
          .scrollContentBackground(.hidden)
          .frame(minHeight: 120)
          .focused($focused, equals: .notes)
          .accessibilityLabel("Notes")
          .accessibilityIdentifier("brewform.notes")
      }
    }
  }

  private func saveBar(_ model: BrewFormModel) -> some View {
    VStack(spacing: DS.Space.xs) {
      if !model.draft.canSave {
        Text("Set dose and water to save.").font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("brewform.save.hint")
      }
      SteelButton(title: "Save brew", isLoading: model.isSaving) { model.save() }
        .disabled(!model.canSave)
        .accessibilityIdentifier("brewform.save")
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
    .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) { Hairline() }
  }
}
