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
  /// A bean to start a new blank brew with (Bean detail's Brew this bean).
  var startingBean: Bean?
  /// An unsaved brew reopened from the Journal: the form picks up its draft file.
  var resuming: DraftStore?

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  /// The app's tabs; with them, a save lands straight on the Journal.
  @Environment(AppRouter.self) private var router: AppRouter?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Query(sort: \Bean.name) private var allBeans: [Bean]
  @Query(sort: \Grinder.name) private var grinders: [Grinder]
  @Query(sort: \WaterProfile.name) private var waters: [WaterProfile]
  @State private var askingNextCup = false
  @State private var addingWater = false
  @State private var newWaterName = ""
  @State private var newWaterHardness = ""
  @State private var waterError: String?
  @State private var addingGrinder = false
  @State private var newGrinderName = ""
  @State private var grinderError: String?
  @State private var addingBean = false
  @State private var model: BrewFormModel?
  @State private var pickedPhoto: PhotosPickerItem?
  @State private var libraryShown = false
  @State private var cameraShown = false
  @State private var detailsShown: Bool?
  /// Set by Edit and Cancel. A saved brew opens locked, so a stray swipe can't
  /// change it; an unsaved edit reopened from the Journal opens unlocked.
  @State private var unlocked: Bool?
  @FocusState private var focused: Field?
  @AppStorage(BrewYield.unitKey) private var yieldUnit = BrewYield.defaultUnit.rawValue
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private enum Field: Hashable { case notes }

  private var locked: Bool { editing != nil && !(unlocked ?? (resuming != nil)) }

  private var title: String {
    if editing != nil { return locked ? "Saved brew" : "Edit brew" }
    return repeating != nil ? "Brew again" : "New brew"
  }

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
        VStack(spacing: DS.Space.md) {
          SkeletonRow()
          SkeletonRow()
        }.padding(DS.Space.lg)
          .frame(maxHeight: .infinity, alignment: .top)
      }
    }
    .background(DS.bg)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard model == nil else { return }
      model = BrewFormModel(
        seed: seed, editing: editing, repeating: repeating, store: Store(context: context),
        draftStore: resuming ?? seed.flatMap(Self.draft(for:)) ?? editing.map { .editing($0.id) }
          ?? repeating.map { .repeating($0.id) } ?? .newBrew(),
        resuming: resuming != nil, simulatesSaveFailure: Self.simulatesSaveFailure)
      if let startingBean, editing == nil, repeating == nil, model?.draft.beans?.isEmpty ?? true {
        model?.addBean(startingBean)
        model?.treatAsOpened()
      }
    }
  }

  /// The draft file this timer run's form wrote earlier, so reopening it keeps typing.
  static func draft(for seed: BrewFormSeed) -> DraftStore? {
    DraftStore.all().first { $0.kind == .newBrew && $0.draft.sourceKey == seed.sessionKey }?
      .store
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
      if model.savedBrewID != nil, router == nil {
        savedState
      } else {
        form(Bindable(model), model)
      }
    }
    .onChange(of: model.draft) { _, _ in model.draftChanged() }
    // Once the save completes, back to the Journal, where the new cup sits at the top.
    .onChange(of: model.savedBrewID) { _, id in
      if let id, model.reviewChanged {
        NextCupAuto.shared.brewReviewed(id, store: Store(context: context))
      }
      guard id != nil, let router else { return }
      onSaved?()
      router.showJournal()
    }
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

  /// The app's main win: the cup is in the journal and the next change to try is
  /// the largest thing on screen. The save already fired the success haptic.
  @ViewBuilder private var savedContent: some View {
    if let model {
      let draft = model.draft
      let ratio = BrewMath.ratio(doseG: draft.doseG, waterG: draft.waterG)
      SuccessView(
        title: model.newBest != nil ? "New best cup" : "In your journal",
        message: savedMessage(model),
        rings: [
          (Double(draft.ratingTenths) / 100, DS.crema),
          (Double(draft.totalTimeS ?? 0) / 300, DS.espresso),
          (((ratio ?? 10) - 10) / 10, DS.sage),
        ],
        primaryTitle: "Done",
        primary: {
          onSaved?()
          dismiss()
        }
      ) {
        if let made = model.madeSuggestion {
          KraftNote {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
              Text("TRY THIS NEXT TIME").font(DS.Font.label).foregroundStyle(DS.ink)
              Text(SuggestionFormat.headline(made, units))
                .font(DS.Font.mono(.title2, .bold)).foregroundStyle(DS.ink)
                .accessibilityIdentifier("brewform.saved.suggestion")
              Text(made.rationale).font(.footnote).foregroundStyle(DS.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
          }
        } else if let note = model.dialInNote {
          Text(note).font(.footnote).foregroundStyle(DS.ink2)
            .accessibilityIdentifier("brewform.saved.dialin")
        }
      }
      .accessibilityIdentifier("brewform.saved")
    }
  }

  private func savedMessage(_ model: BrewFormModel) -> String {
    if let best = model.newBest {
      return
        "Best cup of \(best.bean) so far: \(gradeText(best.tenths)), up from \(gradeText(best.previous))."
    }
    if editing != nil { return "Your changes are saved." }
    return [model.draft.doseG.map { RecipeFormat.weight($0, units) + " dose" }, model.ratioLabel]
      .compactMap { $0 }.joined(separator: " · ")
  }

  private func gradeText(_ tenths: Int) -> String {
    Rating.text(tenths)
  }

  private func form(_ binding: Bindable<BrewFormModel>, _ model: BrewFormModel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        header(model)
        if locked {
          SteelButton(title: "Ask AI for Next Cup", kind: .secondary) { askingNextCup = true }
            .accessibilityHint("Puts an improved recipe called Next Cup on the Brew tab")
            .accessibilityIdentifier("brewform.askNextCup")
          if let editing { BrewRecipeSection(brew: editing) }
        }
        brewedRow(binding.draft.date).disabled(locked)
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
        let fields = shownFields(for: model.draft.methodID)
        Group {
          methodPicker(binding.draft, model)
          beansSection(model)
          if fields.contains(.grind) { grinderPicker(model) }
          if let amount = (BrewYield(rawValue: yieldUnit) ?? .ml).amountText(
            doseG: model.draft.doseG, waterG: model.draft.waterG)
          {
            Label("Makes about \(amount)", systemImage: "cup.and.saucer.fill")
              .font(.subheadline).foregroundStyle(DS.ink2)
              .accessibilityIdentifier("brewform.amount")
          }
          tiles(model, fields)
          if fields.contains(.grind) {
            grindField(model, binding.draft.grindSetting)
            grindHint(model)
          }
          verdictRow(binding.draft.verdict)
          if model.draft.verdict == nil, !model.isEditing {
            Text("Not tasted yet? Save without it. We'll remind you to taste in 20 minutes.")
              .font(.footnote).foregroundStyle(DS.ink2)
              .accessibilityIdentifier("brewform.tasteLater")
          }
          if fields.contains(.rating) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
              Text("RATING").font(DS.Font.label).foregroundStyle(DS.ink2)
              GradeScale(tenths: binding.draft.ratingTenths)
            }
          }
          if fields.contains(.notes) { notesField(binding.draft.notes) }
          if fields.contains(.photo) { photoRow(model) }
          // Water is rarely changed, so it folds away; a value already set keeps it open.
          DisclosureGroup(isExpanded: detailsBinding(model)) {
            waterPicker(model)
              .padding(.top, DS.Space.md)
          } label: {
            Text("Water Profile").font(DS.Font.headline).foregroundStyle(DS.ink)
              .frame(minHeight: DS.Size.minTap, alignment: .leading)
          }
          .tint(DS.ink2)
          .accessibilityIdentifier("brewform.details")
        }
        .disabled(locked)
        if let editing {
          SuggestionHistory(brew: editing, units: units)
        }
      }
      .padding(DS.Space.lg)
      .dialPopups()
      // Behind the fields, so a tap on empty space dismisses the keyboard
      // without stealing the tap from a field.
      .background {
        Color.clear.contentShape(Rectangle()).onTapGesture { focused = nil }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .sheet(isPresented: $askingNextCup) {
      if let editing {
        NextCupAIView(brew: editing) { askingNextCup = false }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !locked { saveBar(model).hiddenWhileTyping() }
    }
    .toolbar {
      if editing != nil {
        ToolbarItem(placement: .topBarTrailing) {
          if locked {
            Button("Edit") { unlocked = true }
              .accessibilityIdentifier("brewform.unlock")
          } else {
            Button("Cancel") {
              focused = nil
              model.revert()
              unlocked = false
            }
            .accessibilityHint("Discards your changes")
            .accessibilityIdentifier("brewform.cancel")
          }
        }
      }
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
      Text(title.dsTitle)
        .font(DS.Font.display).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      if let seed {
        Text([seed.recipeName, seed.methodName].compactMap { $0 }.joined(separator: " · "))
          .font(.subheadline).foregroundStyle(DS.ink2)
      }
      if locked {
        Text("Saved in your journal. Tap Edit to change it.")
          .font(.subheadline).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("brewform.locked")
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
        if !locked {
          Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
            .accessibilityHidden(true)
        }
      }
      .padding(DS.Space.md).frame(minHeight: DS.Size.control)
      .tile()
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
      if !locked {
        Menu {
          ForEach(available) { bean in
            Button(bean.name) { model.addBean(bean) }
          }
          if !available.isEmpty { Divider() }
          Button("New bean…", systemImage: "plus") { addingBean = true }
            .accessibilityIdentifier("brewform.beans.new")
        } label: {
          Text((chosen.isEmpty ? "Add a bean" : "Add another bean").dsTitle)
            .font(DS.Font.din(22, relativeTo: .title3))
            .frame(maxWidth: .infinity, minHeight: DS.Size.control)
            .foregroundStyle(DS.ink)
            .panel(DS.paper)
        }
        .accessibilityLabel(chosen.isEmpty ? "Add a bean" : "Add another bean")
        .accessibilityIdentifier("brewform.beans.add")
      }
    }
    // The full bean screen (photo, barcode, every field); Save comes back here with it chosen.
    .sheet(isPresented: $addingBean) {
      BeanEditorView(target: .new, onSaved: { model.addBean($0) }) { addingBean = false }
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
      if !locked {
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

  private func grinderPicker(_ model: BrewFormModel) -> some View {
    let current = grinders.first { $0.id == model.draft.grinderID }
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      Menu {
        Button("None") { model.setGrinder(nil) }
        ForEach(grinders) { grinder in
          Button(grinder.name) { model.setGrinder(grinder.id) }
        }
        let known = Set(grinders.compactMap { GrinderGuide.find($0.name)?.name })
        let popular = GrinderGuide.all.filter { !known.contains($0.name) }
        if !popular.isEmpty {
          Menu("Popular grinders") {
            ForEach(popular) { guide in
              Button(guide.name) {
                grinderError =
                  model.addGrinder(named: guide.name) ? nil : "The grinder could not be added."
              }
            }
          }
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
          if !locked {
            Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
              .accessibilityHidden(true)
          }
        }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .tile()
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
      // Holding - or + repeats, so a 30 g / 500 g brew is a hold, not hundreds of taps.
      .buttonRepeatBehavior(.enabled)
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
      .buttonRepeatBehavior(.enabled)
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
          if !locked {
            Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink)
              .accessibilityHidden(true)
          }
        }
        .padding(DS.Space.md).frame(minHeight: DS.Size.control)
        .tile()
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

  private func grindField(_ model: BrewFormModel, _ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text("GRIND SETTING").font(DS.Font.label).foregroundStyle(DS.ink2)
      GrindWheel(
        setting: text, grinderName: grinders.first { $0.id == model.draft.grinderID }?.name,
        identifier: "brewform.grind"
      )
      .tile()
    }
  }

  /// The chosen grinder's starting range for this method, from the bundled guide.
  /// Says plainly that it is a starting point; nothing shows for an unknown grinder.
  @ViewBuilder private func grindHint(_ model: BrewFormModel) -> some View {
    let grinder = grinders.first { $0.id == model.draft.grinderID }
    let methodName = methods.first { $0.id == model.draft.methodID }?.name
    if let guide = GrinderGuide.find(grinder?.name),
      let method = GrinderGuide.method(forMethodNamed: methodName)
    {
      let range = guide.range(for: method)
      VStack(alignment: .leading, spacing: 2) {
        Text(
          range.map {
            "\(guide.name): start between \($0) \(guide.unitLabel) for \(methodName?.lowercased() ?? "this method"). A starting point; dial in by taste."
          }
            ?? "\(guide.name) is made for brewed coffee, not \(methodName?.lowercased() ?? "this method")."
        )
        .font(.footnote).foregroundStyle(DS.ink2)
        if let url = URL(string: guide.source) {
          Link("Source: Honest Coffee Guide", destination: url).font(.footnote).tint(DS.signal)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("brewform.grindHint")
    }
  }

  private func verdictRow(_ verdict: Binding<String?>) -> some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: DS.Space.xs))
      : AnyLayout(HStackLayout(spacing: DS.Space.xs))
    let picked = Verdict.picked(verdict.wrappedValue)
    // The tastes share a row; Balanced gets a row of its own, so its name fits.
    let rows: [[Verdict]] = [[.sour, .bitter, .weak, .bright, .strong], [.balanced]]
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("HOW IT TASTED").font(DS.Font.label).foregroundStyle(DS.ink2)
      Text("Pick all that apply.").font(.footnote).foregroundStyle(DS.ink2)
      ForEach(rows, id: \.self) { row in
        layout {
          ForEach(row, id: \.self) { option in
            ChoiceButton(title: option.rawValue.capitalized, isSelected: picked.contains(option)) {
              verdict.wrappedValue = Verdict.toggled(option, in: verdict.wrappedValue)
            }
            .accessibilityIdentifier("brewform.verdict.\(option.rawValue)")
          }
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
        if !locked {
          SteelButton(title: "Remove photo", kind: .secondary) { model.removePhoto() }
        }
      } else if !locked {
        Menu {
          if Camera.isAvailable {
            Button("Take a photo", systemImage: "camera") { cameraShown = true }
          }
          Button("Choose from library", systemImage: "photo.on.rectangle") { libraryShown = true }
        } label: {
          Text("Add a photo".dsTitle).font(DS.Font.din(22, relativeTo: .title3))
            .frame(maxWidth: .infinity, minHeight: DS.Size.control)
            .foregroundStyle(DS.ink)
            .glassEffect(
              .regular.tint(DS.paper.opacity(0.6)), in: RoundedRectangle(cornerRadius: DS.radius)
            )
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
    .photosPicker(isPresented: $libraryShown, selection: $pickedPhoto, matching: .images)
    .fullScreenCover(isPresented: $cameraShown) {
      CameraPicker { data in
        cameraShown = false
        if let data { Task { await model.attachPhoto(data) } }
      }
      .ignoresSafeArea()
    }
  }

  private func notesField(_ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("NOTES").font(DS.Font.label).foregroundStyle(DS.ink2)
      if locked {
        // A saved note is plain text at its full height, so the page scrolls through all of it.
        KraftNote {
          Text(text.wrappedValue.isEmpty ? "No notes." : text.wrappedValue)
            .font(DS.Font.note).foregroundStyle(DS.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityIdentifier("brewform.notes")
        }
      } else {
        KraftNote {
          TextEditor(text: text)
            .font(DS.Font.note).foregroundStyle(DS.ink)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .focused($focused, equals: .notes)
            .accessibilityLabel("Notes")
            .accessibilityIdentifier("brewform.notes")
        }
      }
    }
  }

  /// Open by default only when a water profile is already set (a repeat or an edit).
  private func detailsBinding(_ model: BrewFormModel) -> Binding<Bool> {
    Binding(
      get: {
        detailsShown
          ?? (model.draft.waterProfileID != nil || model.isEditing)
      },
      set: { detailsShown = $0 })
  }

  private func saveBar(_ model: BrewFormModel) -> some View {
    VStack(spacing: DS.Space.xs) {
      SteelButton(title: "Save brew", isLoading: model.isSaving) { model.save() }
        .disabled(!model.canSave)
        .accessibilityHint(model.draft.canSave ? "" : "Set dose and water to save")
        .accessibilityIdentifier("brewform.save")
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
    .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) { Hairline() }
  }
}
