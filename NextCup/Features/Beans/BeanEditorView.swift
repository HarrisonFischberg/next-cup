import NextCupKit
import PhotosUI
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
  @State private var scanQueue: AIQueue?
  @State private var scan: AIRequest?
  @State private var scanFeature = AIFeature.bagRecognition
  @State private var pickerShown = false
  @State private var pickedPhoto: PhotosPickerItem?
  @State private var scanMessage: String?
  @State private var matchShown = false
  @State private var matchedRoaster: String?
  @State private var disclosureProvider: AIProvider?
  @State private var deferredLoad: (() async -> Data?)?
  @State private var cameraShown = false
  @State private var scannerShown = false
  @State private var lookingUp = false
  /// Set when a barcode was not found, so the AI photo route is offered next.
  @State private var offerPhotoRoute = false

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
        photoFill
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
      .photosPicker(isPresented: $pickerShown, selection: $pickedPhoto, matching: .images)
      .onChange(of: pickedPhoto) { _, item in
        guard let item else { return }
        pickedPhoto = nil
        startScan { try? await item.loadTransferable(type: Data.self) }
      }
      .fullScreenCover(isPresented: $cameraShown) {
        CameraPicker { data in
          cameraShown = false
          if let data { startScan { data } }
        }
        .ignoresSafeArea()
      }
      .fullScreenCover(isPresented: $scannerShown) {
        BarcodeScannerView(onCode: lookUp, onCancel: { scannerShown = false })
      }
      .onChange(of: scan?.status) { _, status in if status != nil { finishScan() } }
      .sheet(isPresented: $matchShown) {
        RoasterMatchView(
          name: fields.roasterName.trimmingCharacters(in: .whitespaces),
          onPick: { place in
            matchedRoaster = place.name
            fields.roasterName = place.name
            fields.roasterCity = place.city ?? ""
            fields.roasterWebsite = place.website
            matchShown = false
          },
          onSkip: { matchShown = false })
      }
      .sheet(item: $disclosureProvider) { provider in
        AIDisclosureView(provider: provider) {
          AIPreferences().acceptDisclosure(for: provider)
          disclosureProvider = nil
          if let load = deferredLoad { startScan(load) }
          deferredLoad = nil
        } cancel: {
          disclosureProvider = nil
          deferredLoad = nil
        }
      }
      // A request still waiting must not be sent after the user has left.
      .onDisappear { scanQueue?.cancelAll() }
      .interactiveDismissDisabled(hasChanges)
    }
    .accessibilityIdentifier("beans.editor")
  }

  // MARK: Sections

  private var scanning: Bool { scan?.status == .queued || scan?.status == .sending }

  private var photoFill: some View {
    Section {
      if let scan, scanning {
        HStack {
          Text(scan.status == .queued ? "Waiting for a connection" : "Reading the photo")
            .foregroundStyle(DS.ink2)
          Spacer()
          Button("Cancel") { scanQueue?.cancel(scan) }
            .accessibilityIdentifier("beans.editor.scan.cancel")
        }
        .frame(minHeight: DS.Size.control)
      } else if lookingUp {
        HStack(spacing: DS.Space.sm) {
          ProgressView()
          Text("Looking up the barcode").foregroundStyle(DS.ink2)
        }
        .frame(minHeight: DS.Size.control)
      } else {
        Button(action: startBarcode) {
          Label("Scan the barcode", systemImage: "barcode.viewfinder")
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .accessibilityIdentifier("beans.editor.barcode")
        Menu {
          Section("Read the bag label") { sourceButtons(.bagRecognition) }
          Section("Describe a coffee photo") { sourceButtons(.photoInterpretation) }
        } label: {
          Label("Fill from a photo", systemImage: "camera.viewfinder")
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .accessibilityIdentifier("beans.editor.scan")
        if offerPhotoRoute {
          Button {
            chooseScan(.bagRecognition, camera: Camera.isAvailable)
          } label: {
            Label("Read the bag label with AI instead", systemImage: "sparkles")
              .frame(minHeight: DS.Size.control, alignment: .leading)
          }
          .accessibilityIdentifier("beans.editor.photoRoute")
        }
      }
      if let scanMessage {
        StateBanner(kind: .error, message: scanMessage)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
          .accessibilityIdentifier("beans.editor.scan.error")
      }
    } footer: {
      Text(
        "A barcode is looked up in Open Food Facts. Photos go to your AI provider with your key. You review every field before saving."
      )
    }
    .listRowBackground(DS.paper)
  }

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
      .onChange(of: fields.roasterName) { _, name in
        // Typing a different roaster drops the city and website of the matched one.
        if name != (matchedRoaster ?? original.roasterName) {
          fields.roasterCity = ""
          fields.roasterWebsite = nil
        }
      }
      if !fields.roasterName.trimmingCharacters(in: .whitespaces).isEmpty {
        Button {
          matchShown = true
        } label: {
          Label("Find this roaster on the map", systemImage: "mappin.and.ellipse")
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .accessibilityIdentifier("beans.editor.matchRoaster")
        if !fields.roasterCity.isEmpty {
          Text(
            [fields.roasterCity, fields.roasterWebsite?.host()].compactMap { $0 }
              .joined(separator: " · ")
          )
          .font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("beans.editor.roasterMatch")
        }
      }
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

  @ViewBuilder private func sourceButtons(_ feature: AIFeature) -> some View {
    if Camera.isAvailable {
      Button("Take a photo", systemImage: "camera") { chooseScan(feature, camera: true) }
    }
    Button("Choose from library", systemImage: "photo.on.rectangle") {
      chooseScan(feature, camera: false)
    }
  }

  private func chooseScan(_ feature: AIFeature, camera: Bool) {
    scanFeature = feature
    scanMessage = nil
    offerPhotoRoute = false
    if camera { cameraShown = true } else { pickerShown = true }
  }

  private func startBarcode() {
    scanMessage = nil
    offerPhotoRoute = false
    guard BarcodeScanner.isAvailable else {
      scanMessage =
        "Barcode scanning needs the camera on an iPhone that supports it, with camera access allowed. Try a photo of the bag instead."
      offerPhotoRoute = true
      return
    }
    scannerShown = true
  }

  /// Looks a scanned code up once. A match fills name and roaster for review and offers
  /// the map match; anything else offers the AI photo route. Nothing is saved here.
  private func lookUp(_ code: String) {
    scannerShown = false
    lookingUp = true
    Task {
      let result = await BarcodeLookup.lookUp(code) { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
      }
      lookingUp = false
      switch result {
      case .success(let product):
        fields.name = product.name
        if let brand = product.brand {
          fields.roasterName = brand
          matchShown = true
        }
      case .failure(let failure):
        offerPhotoRoute = true
        scanMessage =
          switch failure {
          case .notFound: "That barcode is not in Open Food Facts yet."
          case .offline: "The barcode could not be looked up. Check your connection."
          case .invalidCode: "That does not look like a retail barcode."
          case .unreadable: "Open Food Facts sent an answer that could not be read."
          }
      }
    }
  }

  private func startScan(_ load: @escaping () async -> Data?) {
    let feature = scanFeature
    let preferences = AIPreferences()
    guard let provider = preferences.provider(for: feature),
      let model = preferences.modelID(for: feature)
    else {
      scanMessage = "Choose a provider and model for \(feature.title) in Settings → AI first."
      return
    }
    guard preferences.hasAcceptedDisclosure(for: provider) else {
      deferredLoad = load
      disclosureProvider = provider
      return
    }
    Task {
      guard let raw = await load(),
        let photo = PhotoSanitizer.sanitized(raw)
      else {
        scanMessage = "That photo could not be read."
        return
      }
      let queue = scanQueue ?? AIQueue.live(context: context)
      queue.onDone = nil
      if scanQueue == nil {
        queue.startMonitoring()
        scanQueue = queue
      }
      do {
        scan = try queue.enqueue(
          BagRecognition.payload(photo: photo, feature: feature), feature: feature,
          provider: provider, modelID: model)
      } catch {
        scanMessage = "The request could not be queued. \(error.localizedDescription)"
      }
    }
  }

  /// Fills the form from a finished scan. Nothing is saved: the user reviews and taps Save.
  private func finishScan() {
    guard let scan else { return }
    switch scan.status {
    case .done:
      switch BagRecognition.draft(from: scan) {
      case .success(let draft):
        BagRecognition.fill(&fields, with: draft)
        hasRoastDate = fields.roastDate != nil
        if weightText.isEmpty, let grams = fields.bagWeightG {
          weightText = RecipeFormat.weight(grams, units, withSymbol: false)
        }
      case .failure(let failure):
        scanMessage = failure.errorDescription
      }
      scan.discardResult()
      self.scan = nil
    case .failed:
      scanMessage = scan.errorMessage ?? "The photo could not be read."
      self.scan = nil
    case .cancelled:
      self.scan = nil
    case .queued, .sending:
      break
    }
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
