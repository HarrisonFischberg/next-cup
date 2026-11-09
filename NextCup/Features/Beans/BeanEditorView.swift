import NextCupKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

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
/// How the editor starts: straight into a bag photo or a barcode or QR scan (set-up offers both).
enum BeanCaptureStart: String, Identifiable {
  case photo, barcode, manual, aiFlow
  var id: String { rawValue }
}

/// The guided AI flow for the fullest read of a bag: both codes, both sides, then one request
/// to the user's keyed provider.
enum BeanFlowStep: Int, CaseIterable, Identifiable {
  case barcode, qr, front, back, reading
  var id: Int { rawValue }

  var title: String {
    switch self {
    case .barcode: "Scan the barcode"
    case .qr: "Scan the QR code, if the bag has one"
    case .front: "Photo of the front of the bag"
    case .back: "Photo of the back of the bag"
    case .reading: "Read everything with AI"
    }
  }

  var action: String {
    switch self {
    case .barcode, .qr: "Scan"
    case .front, .back: "Take photo"
    case .reading: "Read the bag"
    }
  }
}

struct BeanEditorView: View {
  let target: BeanEditorTarget
  var start: BeanCaptureStart?
  /// Hears about the bean once it is saved, e.g. so a brew being logged can use it.
  var onSaved: ((Bean) -> Void)?
  /// Hears about a new bean saved after a photo, barcode or QR scan filled it, so the Beans
  /// tab can ask how the user wants it to taste.
  var afterScan: ((Bean) -> Void)?
  let close: () -> Void

  init(
    target: BeanEditorTarget, start: BeanCaptureStart? = nil, onSaved: ((Bean) -> Void)? = nil,
    afterScan: ((Bean) -> Void)? = nil, close: @escaping () -> Void
  ) {
    self.target = target
    self.start = start
    self.onSaved = onSaved
    self.afterScan = afterScan
    self.close = close
    // Opened for the AI flow: its steps are on screen from the first frame, never the plain form.
    _flow = State(initialValue: start == .aiFlow ? .barcode : nil)
  }

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
  @State private var lookupStages: [String] = []
  /// The link from a scanned QR code, kept in view so it can be opened whatever was read.
  @State private var scannedLink: URL?
  /// The site the QR link ended on, used as the roaster's website on save if it has none.
  @State private var linkSite: URL?
  /// The last two stages of a scan, shown while the result goes into the fields.
  @State private var fillStages: [String]?
  @State private var fillStage = 0
  @State private var filledMessage: String?
  @State private var filledByScan = false
  @State private var flow: BeanFlowStep?
  /// Front, then back, already stripped of metadata.
  @State private var flowPhotos: [Data] = []
  @State private var flowJob: Task<Void, Never>?
  @State private var flowWaitingForNotice = false
  /// The step whose "what to do next" card is up; its Continue opens the scanner or camera.
  @State private var flowPrompt: BeanFlowStep?

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
      .task {
        load()
        switch start {
        case .photo:
          chooseScan(
            .bagRecognition, camera: UIImagePickerController.isSourceTypeAvailable(.camera))
        case .barcode: startBarcode()
        case .aiFlow:
          // The step card can only come up once this sheet has finished sliding in.
          try? await Task.sleep(for: .milliseconds(450))
          if flow == .barcode { flowPrompt = .barcode }
        case .manual, nil: break
        }
      }
      .photosPicker(isPresented: $pickerShown, selection: $pickedPhoto, matching: .images)
      .onChange(of: pickedPhoto) { _, item in
        guard let item else { return }
        pickedPhoto = nil
        if flow == .front || flow == .back {
          Task { photoForFlow(try? await item.loadTransferable(type: Data.self)) }
        } else {
          startScan { try? await item.loadTransferable(type: Data.self) }
        }
      }
      .fullScreenCover(isPresented: $cameraShown) {
        CameraPicker { data in
          cameraShown = false
          if flow == .front || flow == .back {
            if data != nil { photoForFlow(data) } else { flowPrompt = flow }
          } else if let data {
            startScan { data }
          }
        }
        .ignoresSafeArea()
      }
      .fullScreenCover(isPresented: $scannerShown) {
        BarcodeScannerView(
          onCode: scanned,
          onCancel: {
            scannerShown = false
            // Back to the step's card, to try again or skip.
            if flow == .barcode || flow == .qr { flowPrompt = flow }
          })
      }
      .onChange(of: scan?.status) { _, status in if status != nil { finishScan() } }
      .sheet(item: $flowPrompt) { step in
        FlowPromptView(
          step: step,
          onContinue: {
            flowPrompt = nil
            Task {
              // The card's dismissal has to finish before the camera can come up.
              try? await Task.sleep(for: .milliseconds(500))
              launch(step)
            }
          },
          onSkip: {
            flowPrompt = nil
            advanceFlow()
          },
          onStop: {
            flowPrompt = nil
            stopFlow()
          })
      }
      .fullScreenCover(isPresented: .constant(flowJob != nil)) {
        BrewingBeansView { flowJob?.cancel() }
      }
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
          if flowWaitingForNotice { readFlow() }
          flowWaitingForNotice = false
        } cancel: {
          disclosureProvider = nil
          deferredLoad = nil
          flowWaitingForNotice = false
        }
      }
      // A request still waiting must not be sent after the user has left.
      .onDisappear {
        scanQueue?.cancelAll()
        flowJob?.cancel()
      }
      .interactiveDismissDisabled(hasChanges)
    }
    .accessibilityIdentifier("beans.editor")
  }

  // MARK: Sections

  private var scanning: Bool { scan?.status == .queued || scan?.status == .sending }

  private var photoFill: some View {
    Section {
      if let scan, scanning {
        StagedProgress(
          stages: [
            "Photo prepared",
            scan.status == .queued ? "Waiting for a connection" : "Reading the label with AI",
            "Filling the fields",
          ], current: 1)
        Button("Cancel") { scanQueue?.cancel(scan) }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("beans.editor.scan.cancel")
      } else if let stages = fillStages {
        StagedProgress(stages: stages, current: fillStage)
      } else if lookingUp {
        StagedProgress(stages: lookupStages, current: 0)
      } else {
        if let flow {
          flowPanel(flow)
        } else {
          Button(action: startBarcode) {
            Label("Scan a barcode or QR code", systemImage: "qrcode.viewfinder")
              .frame(minHeight: DS.Size.control, alignment: .leading)
          }
          .accessibilityIdentifier("beans.editor.barcode")
          Menu {
            Section("Read the bag label") { sourceButtons(.bagRecognition) }
            Section("Describe a coffee photo") { sourceButtons(.photoInterpretation) }
          } label: {
            Label(
              filledByScan ? "Photo of the bag, to fill the rest" : "Photo of the bag",
              systemImage: "camera.viewfinder"
            )
            .frame(minHeight: DS.Size.control, alignment: .leading)
          }
          .accessibilityIdentifier("beans.editor.scan")
        }
      }
      if let scannedLink {
        Link(destination: scannedLink) {
          Label("Open the link on the bag (\(scannedLink.host() ?? "web"))", systemImage: "link")
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .accessibilityIdentifier("beans.editor.qrLink")
      }
      if let filledMessage {
        StateBanner(kind: .info, message: filledMessage)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
          .accessibilityIdentifier("beans.editor.scan.filled")
      }
      if let scanMessage {
        StateBanner(kind: .error, message: scanMessage)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
          .accessibilityIdentifier("beans.editor.scan.error")
      }
    } footer: {
      Text(
        "A barcode is looked up in Open Food Facts. A QR code's link is opened once to read the coffee's page. Photos go to your AI provider with your key. You review every field before saving."
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
      if let data = fields.photo, let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: 160)
          .accessibilityLabel("Photo of the bag")
          .accessibilityIdentifier("beans.editor.photo")
        Button("Remove photo", role: .destructive) { fields.photo = nil }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("beans.editor.removePhoto")
      }
    } header: {
      Text("Bag")
    } footer: {
      Text(
        "Separate flavor notes with commas. The amount left drops with each brew. A bag photo you read is kept on this bean, on this iPhone."
      )
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

  // MARK: AI flow

  @ViewBuilder private func flowPanel(_ current: BeanFlowStep) -> some View {
    ForEach(BeanFlowStep.allCases) { step in
      let done = step.rawValue < current.rawValue
      Label {
        Text(step.title).foregroundStyle(step == current ? DS.ink : DS.ink2)
          .fontWeight(step == current ? .semibold : .regular)
      } icon: {
        Image(
          systemName: done
            ? "checkmark.circle.fill" : step == current ? "arrow.right.circle" : "circle"
        )
        .foregroundStyle(done || step == current ? DS.signal : DS.ink2)
      }
      .frame(minHeight: DS.Size.minTap, alignment: .leading)
      .accessibilityValue(done ? "Done" : step == current ? "Now" : "")
    }
    .accessibilityIdentifier("beans.editor.flow")
    if flowJob != nil {
      StagedProgress(
        stages: [
          "\(flowPhotos.count == 1 ? "Photo" : "Photos") ready",
          "Reading the bag with \(DirectAI.cloudProviderTitle ?? "AI")", "Filling the fields",
        ], current: 1)
    } else {
      // The app's own button, so it reads in every look and in dark mode.
      SteelButton(title: current.action) { launch(current) }
        .accessibilityIdentifier("beans.editor.flow.go")
      HStack {
        if current != .reading {
          Button("Skip", action: advanceFlow).accessibilityIdentifier("beans.editor.flow.skip")
        }
        Spacer()
        Button("Stop the AI flow", role: .cancel) { stopFlow() }
          .accessibilityIdentifier("beans.editor.flow.stop")
      }
      // Borderless, so a tap on the row does not fire both buttons.
      .buttonStyle(.borderless).foregroundStyle(DS.ink)
      .frame(minHeight: DS.Size.control)
    }
  }

  /// A barcode or QR code was read (or failed): the AI flow moves on.
  private func codeDone() {
    if flow == .barcode || flow == .qr { advanceFlow() }
  }

  private func startFlow() {
    scanMessage = nil
    flowPhotos = []
    flow = .barcode
    flowPrompt = .barcode
  }

  private func stopFlow() {
    flowJob?.cancel()
    flowJob = nil
    flow = nil
    flowPhotos = []
  }

  /// The next step's card comes up a moment later, once the last screen has gone; after the
  /// back of the bag, the read starts on its own.
  private func advanceFlow() {
    guard let current = flow, let next = BeanFlowStep(rawValue: current.rawValue + 1) else {
      return
    }
    flow = next
    Task {
      try? await Task.sleep(for: .milliseconds(600))
      guard flow == next, !scannerShown, !cameraShown, !pickerShown else { return }
      if next == .reading { readFlow() } else { flowPrompt = next }
    }
  }

  private func launch(_ step: BeanFlowStep) {
    scanMessage = nil
    switch step {
    case .barcode, .qr: startBarcode()
    case .front, .back: if Camera.isAvailable { cameraShown = true } else { pickerShown = true }
    case .reading: readFlow()
    }
  }

  private func photoForFlow(_ raw: Data?) {
    guard let raw, let photo = PhotoSanitizer.sanitized(raw) else {
      scanMessage = "That photo could not be read. Try again or skip it."
      return
    }
    if flow == .back, flowPhotos.count > 1 { flowPhotos.removeLast() }
    if flow == .front, !flowPhotos.isEmpty { flowPhotos.removeFirst() }
    flow == .front ? flowPhotos.insert(photo, at: 0) : flowPhotos.append(photo)
    advanceFlow()
  }

  /// Sends both sides as one picture to the keyed provider (the best read), or to Apple's
  /// model on this iPhone when there is no key.
  private func readFlow() {
    guard !flowPhotos.isEmpty else {
      scanMessage = "Take a photo of the front or back of the bag first."
      flow = .front
      return
    }
    if let pending = DirectAI.pendingDisclosure {
      flowWaitingForNotice = true
      disclosureProvider = pending
      return
    }
    // A keyed provider reads best; without one, Apple's model on this iPhone reads the label.
    guard DirectAI.route != nil else {
      scanMessage =
        "Turn on Apple Intelligence, or add an Anthropic or OpenAI key in Settings → AI, then tap Read the bag."
      return
    }
    guard let photo = BeanEditorView.stacked(flowPhotos) else {
      scanMessage = "The photos could not be prepared."
      return
    }
    let sides = flowPhotos.count
    if fields.photo == nil { fields.photo = flowPhotos.first }
    flowJob = Task {
      let started = Date()
      do {
        let (answer, _) = try await DirectAI.send(
          BagRecognition.payload(photo: photo, feature: .bagRecognition, sides: sides))
        try Task.checkCancellation()
        flowJob = nil
        switch BagRecognition.draft(answer: answer) {
        case .success(let draft):
          await showFilling(["Bag read", "Filling the fields"], since: started) {
            fill(with: draft)
          }
          flow = nil
          flowPhotos = []
        case .failure(let failure):
          scanMessage = failure.errorDescription
        }
      } catch is CancellationError {
      } catch {
        if !Task.isCancelled { scanMessage = NextCupAIView.message(for: error) }
      }
      flowJob = nil
    }
  }

  /// The photos one above the other in one JPEG (front on top), so any provider reads both
  /// sides in a single request.
  static func stacked(_ photos: [Data]) -> Data? {
    let images = photos.compactMap(UIImage.init(data:))
    guard images.count > 1 else { return photos.first }
    let width: CGFloat = 1600
    let sizes = images.map {
      CGSize(width: width, height: ($0.size.height * width / max($0.size.width, 1)).rounded())
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: width, height: sizes.map(\.height).reduce(0, +)), format: format)
    return renderer.jpegData(withCompressionQuality: 0.8) { _ in
      var top: CGFloat = 0
      for (image, size) in zip(images, sizes) {
        image.draw(in: CGRect(origin: CGPoint(x: 0, y: top), size: size))
        top += size.height
      }
    }
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
    if camera { cameraShown = true } else { pickerShown = true }
  }

  private func startBarcode() {
    scanMessage = nil
    Task {
      guard await BarcodeScanner.requestIfNeeded() else {
        scanMessage =
          "Scanning needs the camera on an iPhone that supports it, with camera access allowed. Try a photo of the bag instead."
        // The AI flow goes on to the photos.
        if flow == .barcode || flow == .qr {
          flow = .qr
          advanceFlow()
        }
        return
      }
      scannerShown = true
    }
  }

  private func scanned(_ code: ScannedCode) {
    // A QR code scanned at the barcode step counts for the QR step too.
    if flow == .barcode, case .qr = code { flow = .qr }
    switch code {
    case .barcode(let digits): lookUp(digits)
    case .qr(let payload): readQR(payload)
    }
  }

  /// Reads a QR code once. A link is fetched (no cookies, nothing sent but the request)
  /// and the page fills blanks for review; plain text is read as "Label: value" lines.
  /// Whatever happens, the link stays on screen so the user can open it and type the rest.
  private func readQR(_ payload: String) {
    scannerShown = false
    guard let link = QRBeanLink.link(from: payload) else {
      let draft = QRBeanLink.parse(text: payload)
      if draft.isEmpty {
        scanMessage = "That QR code has no web link or coffee details to read."
        codeDone()
        return
      }
      Task {
        await showFilling(["QR code read", "Filling the fields"], since: Date()) {
          fill(with: QRBeanLink.fields(draft))
        }
        codeDone()
      }
      return
    }
    scannedLink = link
    lookupStages = ["Opening \(link.host() ?? "the link")", "Filling the fields"]
    lookingUp = true
    Task {
      let started = Date()
      let result = await QRBeanLink.lookUp(link) { request in
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        return (
          data, (response as? HTTPURLResponse)?.statusCode ?? 0, response.url, response.mimeType
        )
      }
      lookingUp = false
      switch result {
      case .success(let draft):
        linkSite = draft.website
        await showFilling(["Page read", "Filling the fields"], since: started) {
          fill(with: QRBeanLink.fields(draft))
        }
        if flow == nil, !draft.roaster.isEmpty, fields.roasterCity.isEmpty { matchShown = true }
      case .failure(let failure):
        scanMessage =
          switch failure {
          case .nothingFound:
            "The page did not list the coffee's details. Open the link to read it and fill in the rest."
          case .offline: "The link could not be opened. Check your connection, or open it below."
          case .unreadable: "The link is not a page that can be read. Open it below to check."
          }
      }
      codeDone()
    }
  }

  /// Looks a scanned code up once. A match fills name and roaster for review and offers
  /// the map match; anything else offers the AI photo route. Nothing is saved here.
  private func lookUp(_ code: String) {
    scannerShown = false
    lookupStages = ["Looking up the barcode", "Filling the fields"]
    lookingUp = true
    Task {
      let started = Date()
      let result = await BarcodeLookup.lookUp(code) { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
      }
      lookingUp = false
      switch result {
      case .success(let product):
        // Fills blanks only, like a photo: a late answer never replaces what was typed.
        await showFilling(["Barcode found", "Filling the fields"], since: started) {
          BagRecognition.fill(&fields, with: BarcodeLookup.draft(product))
        }
        if flow == nil, product.brand != nil { matchShown = true }
      case .failure(let failure):
        scanMessage =
          switch failure {
          case .notFound: "That barcode is not in Open Food Facts yet."
          case .offline: "The barcode could not be looked up. Check your connection."
          case .invalidCode: "That does not look like a retail barcode."
          case .unreadable: "Open Food Facts sent an answer that could not be read."
          }
      }
      codeDone()
    }
  }

  private func startScan(_ load: @escaping () async -> Data?) {
    let feature = scanFeature
    let preferences = AIPreferences()
    guard let provider = preferences.provider(for: feature),
      let model = preferences.modelID(for: feature)
    else {
      if feature == .bagRecognition { return readLabelWithoutAI(load) }
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
      if feature == .bagRecognition { fields.photo = photo }
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

  /// With no AI model (Apple Intelligence off or unsupported, no key set), the label is still
  /// read on this iPhone with Vision, and only what the label states plainly (roast date,
  /// roast, weight, tasting notes) is filled for review. Nothing leaves the device.
  private func readLabelWithoutAI(_ load: @escaping () async -> Data?) {
    Task {
      let started = Date()
      guard let raw = await load(), let photo = PhotoSanitizer.sanitized(raw),
        let lines = try? await PaperScanner.lines(in: photo).map(\.text)
      else {
        scanMessage = "That photo could not be read."
        return
      }
      fields.photo = photo
      var draft = BeanFields()
      draft.roastDate = LabelEvidence.roastDate(in: lines).flatMap(BagRecognition.date)
      draft.bagWeightG = LabelEvidence.bagWeightGrams(in: lines)
      draft.roastLevel = BagRecognition.roastLevel(in: lines)
      draft.flavorNotes = BagRecognition.flavorNotes(in: lines, taxonomy: ExploreModel.taxonomy)
      await showFilling(["Label read on this iPhone", "Filling the fields"], since: started) {
        fill(with: draft)
      }
      filledMessage =
        (filledMessage ?? "")
        + " Without an AI model only the roast date, roast, weight and tasting notes are read; choose one in Settings → AI to read more."
    }
  }

  private func fill(with draft: BeanFields) {
    BagRecognition.fill(&fields, with: draft)
    hasRoastDate = fields.roastDate != nil
    if weightText.isEmpty, let grams = fields.bagWeightG {
      weightText = RecipeFormat.weight(grams, units, withSymbol: false)
    }
  }

  /// Fills the form from a finished scan. Nothing is saved: the user reviews and taps Save.
  private func finishScan() {
    guard let scan else { return }
    switch scan.status {
    case .done:
      switch BagRecognition.draft(from: scan) {
      case .success(let draft):
        Task {
          await showFilling(["Label read", "Filling the fields"], since: Date()) {
            fill(with: draft)
          }
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

  /// Shows the fill as its own stage, fills, then says how many fields changed.
  /// The hold only keeps a stage readable (see `StagedProgress.hold`).
  private func showFilling(_ stages: [String], since start: Date, fill: () -> Void) async {
    filledMessage = nil
    fillStages = stages
    fillStage = 1
    await StagedProgress.hold(since: start)
    let before = fields
    fill()
    filledByScan = true
    let count = before.changedCount(to: fields)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    await StagedProgress.hold(since: Date())
    fillStages = nil
    filledMessage =
      count == 0
      ? "Nothing new was found to fill. Check the fields before saving."
      : "Filled \(count) \(count == 1 ? "field" : "fields"). Check them before saving."
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
    // A QR page's site becomes the roaster's website only when it has none yet.
    if fields.roasterWebsite == nil, let linkSite,
      roasters.first(where: { $0.name == fields.roasterName })?.website == nil
    {
      fields.roasterWebsite = linkSite
    }
    switch service.save(fields, editing: bean) {
    case .success(let saved):
      if bean == nil { BeanDetailsAI.fill([saved], in: context) }
      onSaved?(saved)
      if bean == nil, filledByScan { afterScan?(saved) }
      close()
    case .failure(let failure): error = failure.message
    }
  }
}
