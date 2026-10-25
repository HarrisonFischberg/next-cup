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
  @Query(sort: \Bean.name) private var allBeans: [Bean]
  @Query(sort: \Grinder.name) private var grinders: [Grinder]
  @Query(sort: \Suggestion.createdAt, order: .reverse) private var suggestions: [Suggestion]
  @Query(sort: \WaterProfile.name) private var waters: [WaterProfile]
  @State private var askingAI = false
  @State private var addingWater = false
  @State private var newWaterName = ""
  @State private var newWaterHardness = ""
  @State private var waterError: String?
  @State private var addingGrinder = false
  @State private var newGrinderName = ""
  @State private var grinderError: String?
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
      VStack(alignment: .leading, spacing: DS.Space.md) {
        savedContent
      }
    }
  }

  @ViewBuilder private var savedContent: some View {
    Group {
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
      if let model, let made = model.madeSuggestion {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
          Text("TRY THIS NEXT TIME").font(DS.Font.label).foregroundStyle(DS.ink2)
          Text(SuggestionFormat.headline(made, units))
            .font(DS.Font.mono(.title3, .bold)).foregroundStyle(DS.ink)
            .accessibilityIdentifier("brewform.saved.suggestion")
          Text(made.rationale).font(.footnote).foregroundStyle(DS.ink2)
        }
        .padding(.horizontal, DS.Space.xl).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      } else if let note = model?.dialInNote {
        Text(note).font(.footnote).foregroundStyle(DS.ink2)
          .padding(.horizontal, DS.Space.xl).frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("brewform.saved.dialin")
      }
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
        beansSection(model)
        suggestionSection(model)
        brewedRow(binding.draft.date)
        let fields = shownFields(for: model.draft.methodID)
        tiles(model, fields)
        if fields.contains(.grind) {
          grindField(binding.draft.grindSetting)
          grinderPicker(model)
        }
        waterPicker(model)
        verdictRow(binding.draft.verdict)
        if fields.contains(.rating) {
          VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("GRADE").font(DS.Font.label).foregroundStyle(DS.ink2)
            GradeScale(halfSteps: binding.draft.ratingHalfSteps)
          }
        }
        if fields.contains(.photo) { photoRow(model) }
        if fields.contains(.notes) { notesField(binding.draft.notes) }
        if let editing {
          SuggestionHistory(brew: editing, units: units)
          SteelButton(title: "Ask AI about this brew", kind: .secondary) { askingAI = true }
            .accessibilityIdentifier("brewform.ai")
        }
      }
      .padding(DS.Space.lg)
      // Behind the fields, so a tap on empty space dismisses the keyboard
      // without stealing the tap from a field.
      .background {
        Color.clear.contentShape(Rectangle()).onTapGesture { focused = nil }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .sheet(isPresented: $askingAI) {
      if let editing {
        AIAskView(
          model: AIAskModel(feature: .diagnosis, brews: [editing], context: context),
          close: { askingAI = false })
      }
    }
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
      Text(
        (model.isEditing ? "Edit brew" : (model.repeatingID != nil ? "Brew again" : "New brew"))
          .dsTitle
      )
      .font(DS.Font.display).foregroundStyle(DS.ink)
      .dynamicTypeSize(...DS.displayCap)
      .accessibilityAddTraits(.isHeader)
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
      .panel(DS.paper)
    }
    .accessibilityLabel("Method")
    .accessibilityValue(current?.name ?? "None chosen")
    .accessibilityIdentifier("brewform.method")
  }

  // MARK: Beans and grinder

  /// The beans in this brew. One bean takes the whole dose; two or more are a
  /// blend, each with a share, and each bag loses its own part of the dose.
  private func beansSection(_ model: BrewFormModel) -> some View {
    let chosen = model.draft.beans ?? []
    let shares = model.beanShares
    let grams = model.beanGrams
    let chosenIDs = Set(chosen.compactMap(\.beanID))
    let available = allBeans.filter { !chosenIDs.contains($0.id) && $0.status != .finished }
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("BEANS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      if chosen.isEmpty {
        Text("No beans chosen. Add one bean, or several for a blend.")
          .font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("brewform.beans.empty")
      } else {
        PaperBox {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chosen.enumerated()), id: \.offset) { index, entry in
              if index > 0 { Hairline() }
              beanRow(
                model, index: index, entry: entry, share: shares[index], grams: grams[index],
                isBlend: chosen.count > 1)
            }
          }
        }
        .accessibilityIdentifier("brewform.beans")
        if chosen.count > 1 {
          Text("A blend. Each bean's amount comes off its own bag.")
            .font(.footnote).foregroundStyle(DS.ink2)
        }
      }
      Menu {
        ForEach(available) { bean in
          Button(bean.name) { model.addBean(bean) }
        }
      } label: {
        Text((chosen.isEmpty ? "Add a bean" : "Add another bean").dsTitle)
          .font(DS.Font.din(22, relativeTo: .title3))
          .frame(maxWidth: .infinity, minHeight: DS.Size.control)
          .foregroundStyle(DS.ink)
          .panel(DS.paper)
      }
      .disabled(available.isEmpty)
      .accessibilityLabel(chosen.isEmpty ? "Add a bean" : "Add another bean")
      .accessibilityIdentifier("brewform.beans.add")
      if available.isEmpty && chosen.isEmpty {
        Text("Add beans on the Beans tab, then choose them here.")
          .font(.footnote).foregroundStyle(DS.ink2)
      }
    }
  }

  private func beanRow(
    _ model: BrewFormModel, index: Int, entry: DraftBean, share: Double, grams: Double,
    isBlend: Bool
  ) -> some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Space.sm))
    let isDecaf = allBeans.first { $0.id == entry.beanID }?.isDecaf == true
    let amount =
      RecipeFormat.weight(grams, units)
      + (isBlend ? "  ·  " + String(format: "%.0f%%", share) : "")
    return layout {
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
        HStack(spacing: DS.Space.sm) {
          Text(amount).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
          if isDecaf { Tag(text: "Decaf") }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      HStack(spacing: 0) {
        if isBlend {
          shareButton("minus", label: "Decrease \(entry.name) share") {
            model.stepShare(at: index, by: -5)
          }
          shareButton("plus", label: "Increase \(entry.name) share") {
            model.stepShare(at: index, by: 5)
          }
        }
        shareButton("xmark", label: "Remove \(entry.name)") { model.removeBean(at: index) }
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
    .accessibilityIdentifier("brewform.bean.\(index)")
  }

  private func shareButton(_ symbol: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.body.weight(.heavy)).foregroundStyle(DS.ink)
        // Capped so the glyph never outgrows its 44 pt target and overlaps its neighbor.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(label)
  }

  /// The dial-in card from the last brew of these beans. Only a new brew shows
  /// it; an answered card stays, with Undo, until the form is closed.
  @ViewBuilder
  private func suggestionSection(_ model: BrewFormModel) -> some View {
    if !model.isEditing {
      let handled = suggestions.first { $0.id == model.handledSuggestionID }
      let waiting = SuggestionService.match(
        in: suggestions, beanIDs: Set((model.draft.beans ?? []).compactMap(\.beanID)),
        methodID: model.draft.methodID, excluding: model.draft.id)
      if let suggestion = handled ?? waiting {
        SuggestionCard(
          suggestion: suggestion, units: units, error: model.suggestionError,
          onAccept: { model.applySuggestion(suggestion) },
          onEdit: { typed in
            if let value = SuggestionFormat.canonical(typed, for: suggestion.field, units) {
              model.applySuggestion(suggestion, editedTo: value)
            } else {
              model.applySuggestion(suggestion, editedTo: "")
            }
          },
          onDismiss: { model.dismissSuggestion(suggestion) },
          onUndo: { model.undoSuggestionAnswer(suggestion) })
      }
    }
  }

  private func grinderPicker(_ model: BrewFormModel) -> some View {
    let current = grinders.first { $0.id == model.draft.grinderID }
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      Menu {
        Button("None") { model.setGrinder(nil) }
        ForEach(grinders) { grinder in
          Button(grinder.name) { model.setGrinder(grinder.id) }
        }
        Button("New grinder…") {
          newGrinderName = ""
          addingGrinder = true
        }
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("GRINDER").font(DS.Font.label).foregroundStyle(DS.ink2)
            Text(current?.name ?? "None chosen").font(DS.Font.headline).foregroundStyle(DS.ink)
              .multilineTextAlignment(.leading)
          }
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
            .accessibilityHidden(true)
        }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .panel(DS.paper)
      }
      .accessibilityLabel("Grinder")
      .accessibilityValue(current?.name ?? "None chosen")
      .accessibilityIdentifier("brewform.grinder")
      if let grinderError {
        StateBanner(kind: .error, message: grinderError, actionTitle: "Dismiss") {
          self.grinderError = nil
        }
      }
    }
    .alert("New grinder", isPresented: $addingGrinder) {
      TextField("Grinder name", text: $newGrinderName)
      Button("Cancel", role: .cancel) {}
      Button("Add") {
        grinderError =
          model.addGrinder(named: newGrinderName) ? nil : "The grinder could not be added."
      }
    } message: {
      Text("Its name is kept so grind settings can be compared by grinder.")
    }
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

  /// The fields the chosen method tracks. With no method chosen, every field shows.
  private func shownFields(for methodID: UUID?) -> Set<BrewParameter> {
    guard let method = methods.first(where: { $0.id == methodID }) else {
      return Set(BrewParameter.allCases)
    }
    return MethodParameters.shown(tracked: method.trackedParameters)
  }

  private func tiles(_ model: BrewFormModel, _ fields: Set<BrewParameter>) -> some View {
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
      if fields.contains(.temperature) {
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
      }
      if fields.contains(.time) {
        StepperTile(
          title: "Time", value: model.draft.totalTimeS.map(RecipeFormat.clock) ?? "—",
          target: targets?.totalTimeS.map(RecipeFormat.clock),
          down: { model.stepTime(direction: -1) }, up: { model.stepTime(direction: 1) },
          minusLabel: "Decrease Time by 5 seconds", plusLabel: "Increase Time by 5 seconds"
        )
        .accessibilityIdentifier("brewform.time")
      }
      ReadoutTile(title: "Ratio", value: model.ratioLabel ?? "—")
        .accessibilityIdentifier("brewform.ratio")
      if fields.contains(.tds) {
        StepperTile(
          title: "TDS", value: model.draft.tds.map { String(format: "%.2f", $0) } ?? "—",
          unit: model.draft.tds == nil ? "" : "%",
          down: { model.stepTds(direction: -1) }, up: { model.stepTds(direction: 1) },
          minusLabel: "Decrease TDS by 0.05", plusLabel: "Increase TDS by 0.05"
        )
        .accessibilityIdentifier("brewform.tds")
        ReadoutTile(title: "Extraction", value: model.extractionLabel ?? "—")
          .accessibilityIdentifier("brewform.extraction")
      }
    }
  }

  private func waterPicker(_ model: BrewFormModel) -> some View {
    let current = waters.first { $0.id == model.draft.waterProfileID }
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      Menu {
        Button("None") { model.setWaterProfile(nil) }
        ForEach(waters) { water in
          Button(water.name) { model.setWaterProfile(water.id) }
        }
        Button("New water profile…") {
          newWaterName = ""
          newWaterHardness = ""
          addingWater = true
        }
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("WATER").font(DS.Font.label).foregroundStyle(DS.ink2)
            Text(current?.name ?? "None chosen").font(DS.Font.headline).foregroundStyle(DS.ink)
              .multilineTextAlignment(.leading)
          }
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
            .accessibilityHidden(true)
        }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .panel(DS.paper)
      }
      .accessibilityLabel("Water")
      .accessibilityValue(current?.name ?? "None chosen")
      .accessibilityIdentifier("brewform.waterprofile")
      if let waterError {
        StateBanner(kind: .error, message: waterError, actionTitle: "Dismiss") {
          self.waterError = nil
        }
      }
    }
    .alert("New water profile", isPresented: $addingWater) {
      TextField("Name", text: $newWaterName)
      TextField("Hardness in ppm (optional)", text: $newWaterHardness)
        .keyboardType(.decimalPad)
      Button("Cancel", role: .cancel) {}
      Button("Add") {
        waterError =
          model.addWaterProfile(named: newWaterName, hardnessPPM: newWaterHardness)
          ? nil : "The water profile could not be added. Check the name and hardness."
      }
    } message: {
      Text("Its name is kept so brews can be compared by water.")
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
        .panel(DS.paper)
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
          Text("Add a photo".dsTitle).font(DS.Font.din(22, relativeTo: .title3))
            .frame(maxWidth: .infinity, minHeight: DS.Size.control)
            .foregroundStyle(DS.ink)
            .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius))
            .overlay(
              RoundedRectangle(cornerRadius: DS.radius).strokeBorder(DS.line, lineWidth: DS.rule))
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
