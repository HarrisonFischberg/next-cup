import NextCupKit
import PhotosUI
import SwiftData
import SwiftUI

/// Paper-journal import: choose a photo of a journal page, read it on this iPhone
/// (or with the user's AI key), check every field, confirm, then save. Fields the
/// reader was unsure of are marked with a label as well as a colour, and Save stays
/// off until the user confirms the page.
struct PaperImportView: View {
  let close: () -> Void

  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Query private var beans: [Bean]
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var model: PaperImportModel
  @State private var picked: PhotosPickerItem?
  @FocusState private var focused: Bool

  init(context: ModelContext, close: @escaping () -> Void) {
    self.close = close
    _model = State(initialValue: PaperImportModel(store: Store(context: context)))
  }

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  var body: some View {
    NavigationStack {
      Group {
        switch model.phase {
        case .choose: choose
        case .reading: reading
        case .review: review
        }
      }
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .background(DS.bg)
      .navigationTitle("Import a page")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: close).accessibilityIdentifier("import.cancel")
        }
        if model.phase == .review {
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { if model.save() { close() } }
              .disabled(!model.canSave).accessibilityIdentifier("import.save")
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = false }
        }
      }
      .onChange(of: picked) { _, item in if let item { load(item) } }
      .onChange(of: model.aiRequest?.status) { _, _ in model.aiStatusChanged() }
      .interactiveDismissDisabled(model.phase != .choose)
    }
    .accessibilityIdentifier("import.sheet")
  }

  // MARK: Choose

  private var aiReady: Bool {
    let preferences = AIPreferences()
    guard let provider = preferences.provider(for: .paperImport),
      preferences.modelID(for: .paperImport) != nil
    else { return false }
    return KeychainStore().hasKey(for: provider)
  }

  private var choose: some View {
    Form {
      if let message = model.errorMessage {
        StateBanner(kind: .error, message: message)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
          .accessibilityIdentifier("import.error")
      }
      Section {
        if let photo = model.photo, let image = UIImage(data: photo) {
          Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Photo of the journal page")
            .accessibilityIdentifier("import.photo")
        }
        let pickTitle =
          model.photo == nil ? "Choose a photo of the page" : "Choose a different photo"
        PhotosPicker(selection: $picked, matching: .images) {
          Label(pickTitle, systemImage: "photo")
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .accessibilityIdentifier("import.pick")
        #if DEBUG
          Button("Use a sample page") {
            Task { await model.choose(photoData: PaperSample.page()) }
          }
          .frame(minHeight: DS.Size.control, alignment: .leading)
          .accessibilityIdentifier("import.sample")
        #endif
      } header: {
        Text("Page")
      } footer: {
        Text(
          "One brew per page, with labels such as Dose, Water, Temp and Time. Photos are never kept until you save."
        )
      }
      .listRowBackground(DS.paper)

      if model.photo != nil {
        Section {
          Button {
            model.readOnDevice()
          } label: {
            Label("Read on this iPhone", systemImage: "iphone")
              .frame(minHeight: DS.Size.control, alignment: .leading)
          }
          .accessibilityIdentifier("import.read.device")
          if aiReady {
            Button {
              model.readWithAI()
            } label: {
              Label("Read with my AI key", systemImage: "sparkles")
                .frame(minHeight: DS.Size.control, alignment: .leading)
            }
            .accessibilityIdentifier("import.read.ai")
          }
        } footer: {
          Text(
            aiReady
              ? "Reading on this iPhone sends nothing anywhere. Reading with AI sends the photo to your provider."
              : "Reading on this iPhone sends nothing anywhere. To read handwriting with AI, add a key and a model for Paper import in Settings → AI."
          )
        }
        .listRowBackground(DS.paper)
      }
    }
  }

  private var reading: some View {
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      SkeletonRow()
      Text(model.isWaitingForConnection ? "Waiting for a connection" : "Reading the page")
        .font(.headline).foregroundStyle(DS.ink)
      SteelButton(title: "Cancel", kind: .secondary) { model.cancelReading() }
        .accessibilityIdentifier("import.reading.cancel")
      Spacer()
    }
    .padding(DS.Space.lg)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("import.reading")
  }

  private func load(_ item: PhotosPickerItem) {
    picked = nil
    Task {
      guard let data = try? await item.loadTransferable(type: Data.self) else { return }
      await model.choose(photoData: data)
    }
  }

  // MARK: Review

  private var review: some View {
    @Bindable var model = model
    return Form {
      reviewBanner
      if let photo = model.photo, let image = UIImage(data: photo) {
        Section {
          Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Photo of the journal page")
        }
        .listRowBackground(DS.paper)
      }
      Section("Brew") {
        DatePicker("Brewed on", selection: $model.date, in: ...Date())
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("import.date")
        flagged(.method) {
          Picker("Method", selection: $model.methodID) {
            Text("None").tag(UUID?.none)
            ForEach(methods.filter { !$0.isHidden || $0.id == model.methodID }) {
              Text($0.name).tag(UUID?.some($0.id))
            }
          }
          .onChange(of: model.methodID) { model.draft.confidence[.method] = nil }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("import.method")
          if !model.draft.method.isEmpty {
            Text(
              model.methodID == nil
                ? "Page says “\(model.draft.method)”. No saved method matches; choose one or leave it blank."
                : "Page says “\(model.draft.method)”."
            )
            .font(.footnote).foregroundStyle(DS.ink2)
          }
        }
        flagged(.bean) {
          TextField("Bean", text: text(\.bean, .bean))
            .textInputAutocapitalization(.words).submitLabel(.next).focused($focused)
            .frame(minHeight: DS.Size.control)
            .accessibilityLabel("Bean")
            .accessibilityIdentifier("import.bean")
          if !model.draft.bean.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(beanNote).font(.footnote).foregroundStyle(DS.ink2)
          }
        }
      }
      .listRowBackground(DS.paper)

      Section("Numbers") {
        flagged(.dose) {
          numberRow(
            "Dose", unit: units.weightSymbol, id: "dose",
            value: weight(\.doseG, .dose))
        }
        flagged(.water) {
          numberRow(
            "Water", unit: units.weightSymbol, id: "water", value: weight(\.waterG, .water))
        }
        flagged(.temperature) {
          numberRow(
            "Temperature", unit: units.temperatureSymbol, id: "temp", value: temperature)
        }
        flagged(.time) {
          numberRow("Time", unit: "seconds", id: "time", value: seconds)
        }
        flagged(.grind) {
          TextField("Grind setting", text: text(\.grind, .grind))
            .focused($focused).frame(minHeight: DS.Size.control)
            .accessibilityLabel("Grind setting")
            .accessibilityIdentifier("import.grind")
        }
      }
      .listRowBackground(DS.paper)

      Section("Grade") {
        flagged(.rating) { GradeScale(halfSteps: grade) }
      }
      .listRowBackground(DS.paper)

      Section("Notes") {
        flagged(.notes) {
          TextField("Notes", text: text(\.notes, .notes), axis: .vertical)
            .lineLimit(2...8).focused($focused)
            .accessibilityLabel("Notes")
            .accessibilityIdentifier("import.notes")
        }
      }
      .listRowBackground(DS.paper)

      Section {
        Toggle("I checked these against the page", isOn: $model.confirmed)
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("import.confirm")
        if let saveError = model.saveError {
          StateBanner(kind: .error, message: saveError)
            .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
            .accessibilityIdentifier("import.saveError")
        }
        Button("Read a different page", role: .destructive) { model.startOver() }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("import.startOver")
      } footer: {
        Text("Save stays off until you confirm. Changing a field asks you to confirm again.")
      }
      .listRowBackground(DS.paper)
    }
    .accessibilityIdentifier("import.review")
  }

  @ViewBuilder private var reviewBanner: some View {
    let count = model.draft.needsCheckCount
    StateBanner(
      kind: count > 0 ? .error : .info,
      message: count > 0
        ? "\(count) \(count == 1 ? "field was" : "fields were") hard to read. They are marked CHECK."
        : "Read from your page. Check every field before saving."
    )
    .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
    .accessibilityIdentifier("import.banner")
  }

  private var beanNote: String {
    model.matchedBean().map {
      "Filed under your saved bean “\($0.name)”. Its stock will drop by the dose."
    }
      ?? "No saved bean has this name. It is kept as written; add the bean in Beans to track stock."
  }

  // MARK: Field plumbing

  /// Marks a field the reader was unsure of: a CHECK label and kraft background, so
  /// the warning never rests on colour alone. Editing the field clears the mark.
  private func flagged<Content: View>(
    _ field: PaperField, @ViewBuilder _ content: () -> Content
  ) -> some View {
    let low = model.draft.needsCheck(field)
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      if low {
        Label("CHECK: hard to read", systemImage: "exclamationmark.triangle.fill")
          .font(DS.Font.label).foregroundStyle(DS.onKraft)
          .accessibilityIdentifier("import.flag.\(field.rawValue)")
      }
      content()
    }
    .listRowBackground(low ? DS.kraft : DS.paper)
    .accessibilityElement(children: .contain)
  }

  private func numberRow(
    _ title: String, unit: String, id: String, value: Binding<Double?>
  ) -> some View {
    HStack {
      TextField(title, value: value, format: .number)
        .keyboardType(.decimalPad).focused($focused)
        .accessibilityLabel("\(title) in \(unit)")
        .accessibilityIdentifier("import.\(id)")
      Text(unit).foregroundStyle(DS.ink2).accessibilityHidden(true)
    }
    .frame(minHeight: DS.Size.control)
  }

  private func text(_ key: WritableKeyPath<PaperBrewDraft, String>, _ field: PaperField)
    -> Binding<String>
  {
    Binding(
      get: { model.draft[keyPath: key] },
      set: {
        model.draft[keyPath: key] = $0
        model.draft.confidence[field] = nil
      })
  }

  private func weight(_ key: WritableKeyPath<PaperBrewDraft, Double?>, _ field: PaperField)
    -> Binding<Double?>
  {
    Binding(
      get: { model.draft[keyPath: key].map(units.displayWeight(grams:)) },
      set: {
        model.draft[keyPath: key] = $0.map(units.grams(fromDisplayWeight:))
        model.draft.confidence[field] = nil
      })
  }

  private var temperature: Binding<Double?> {
    Binding(
      get: { model.draft.tempC.map(units.displayTemperature(celsius:)) },
      set: {
        model.draft.tempC = $0.map(units.celsius(fromDisplayTemperature:))
        model.draft.confidence[.temperature] = nil
      })
  }

  private var seconds: Binding<Double?> {
    Binding(
      get: { model.draft.totalTimeS.map(Double.init) },
      set: {
        model.draft.totalTimeS = $0.map { Int($0.rounded()) }
        model.draft.confidence[.time] = nil
      })
  }

  private var grade: Binding<Int> {
    Binding(
      get: { model.draft.ratingHalfSteps ?? 0 },
      set: {
        model.draft.ratingHalfSteps = $0 == 0 ? nil : $0
        model.draft.confidence[.rating] = nil
      })
  }
}
