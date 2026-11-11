import NextCupKit
import SwiftData
import SwiftUI

/// First run: four short steps, each skippable, then a finish that points at the
/// first brew. Nothing behind it is locked, and it asks nothing the app already knows.
struct OnboardingView: View {
  static let doneKey = "onboarding.done"

  /// Called with the tab to land on.
  let finish: (AppTab) -> Void

  @Environment(\.modelContext) private var context
  @Query private var beans: [Bean]
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = OnboardingView
    .regionTemperature.rawValue
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var step = 1
  @State private var grinder = ""
  @State private var typesGrinder = false
  @State private var capture: BeanCaptureStart?
  @State private var picked = Set<PopularBeans.Entry.ID>()
  @State private var beanSearch = ""
  @AppStorage(BeanDetailsAI.enabledKey) private var fillsBeans = true
  @State private var error: String?

  private static let steps = 4
  private static let aiStepNumber = 3
  private static let bagStep = 4

  /// Fahrenheit where the region uses it; grams everywhere, as coffee scales do.
  static var regionTemperature: TemperatureUnit {
    Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        if step <= Self.steps {
          StepProgress(step: step, total: Self.steps)
          ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
              if let error {
                StateBanner(kind: .error, message: error)
              }
              switch step {
              case 1: brewer
              case 2: units
              case Self.aiStepNumber: aiStep
              default: firstBag
              }
            }
          }
          .scrollDismissesKeyboard(.interactively)
          SteelButton(title: nextTitle, action: next)
            .disabled(step == Self.bagStep && picked.isEmpty)
            .accessibilityIdentifier("onboarding.next")
          if step == Self.bagStep {
            Button("Skip for now") { advance() }
              .font(.body.weight(.semibold)).foregroundStyle(DS.ink)
              .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
              .accessibilityIdentifier("onboarding.later")
          }
        } else {
          Spacer()
          SuccessView(
            title: "You're set",
            message: "Your next cup starts here.",
            rings: [(1, DS.crema), (0.75, DS.espresso), (0.6, DS.sage)],
            primaryTitle: "Start brewing",
            primary: { done(.recipes) },
            playsHaptic: true)
          Spacer()
        }
      }
      .padding(DS.Space.lg)
      .background(DS.bg)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: step)
      .toolbar {
        // Every step after the first, and the finish, can go back one; nothing typed is lost.
        if step > 1 {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              step -= 1
            } label: {
              Label("Back", systemImage: "chevron.left").labelStyle(.titleAndIcon)
            }
            .accessibilityIdentifier("onboarding.back")
          }
        }
        if step <= Self.steps {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Skip") { done(.journal) }.accessibilityIdentifier("onboarding.skip")
          }
        }
      }
      .sheet(item: $capture, onDismiss: advance) { start in
        BeanEditorView(target: .new, start: start) { capture = nil }
      }
    }
    // A cover does not inherit the tab view's toggle style.
    .toggleStyle(SwitchToggleStyle(tint: DS.accent))
    .accessibilityIdentifier("onboarding")
  }

  // MARK: Steps

  private var brewer: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      title("What do you brew with?", "Pick the methods you use. The rest stay out of the way.")
      MethodChips()
      Menu {
        Button("None") {
          grinder = ""
          typesGrinder = false
        }
        Button("Other…") {
          grinder = ""
          typesGrinder = true
        }
        Section("Popular grinders") {
          ForEach(GrinderGuide.all) { guide in
            Button(guide.name) {
              grinder = guide.name
              typesGrinder = false  // a listed grinder needs no typed name
            }
          }
        }
      } label: {
        HStack {
          Text(typesGrinder ? "Other grinder" : (grinder.isEmpty ? "Grinder (optional)" : grinder))
            .foregroundStyle(grinder.isEmpty && !typesGrinder ? DS.ink2 : DS.ink)
          Spacer()
          Image(systemName: "chevron.up.chevron.down").foregroundStyle(DS.ink2)
        }
        .padding(.horizontal, DS.Space.md).frame(minHeight: DS.Size.control)
        .glassEffect(
          .regular.tint(DS.paper.opacity(0.6)), in: RoundedRectangle(cornerRadius: DS.controlRadius)
        )
      }
      .accessibilityIdentifier("onboarding.grinder")
      if typesGrinder {
        TextField("Grinder name", text: $grinder)
          .textInputAutocapitalization(.words).submitLabel(.done)
          .padding(.horizontal, DS.Space.md).frame(minHeight: DS.Size.control)
          .glassEffect(
            .regular.tint(DS.paper.opacity(0.6)),
            in: RoundedRectangle(cornerRadius: DS.controlRadius)
          )
          .accessibilityIdentifier("onboarding.grinder.name")
      }
      Text("Your grinder's starting setting then shows on each recipe.")
        .font(.footnote).foregroundStyle(DS.ink2)
    }
  }

  private var units: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      title("Your units", "Set from your region. Change them any time in Settings.")
      Picker("Weight", selection: $weightUnit) {
        Text("Grams (g)").tag(WeightUnit.grams.rawValue)
        Text("Ounces (oz)").tag(WeightUnit.ounces.rawValue)
      }
      .pickerStyle(.segmented).frame(minHeight: DS.Size.control)
      Picker("Temperature", selection: $temperatureUnit) {
        Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
      }
      .pickerStyle(.segmented).frame(minHeight: DS.Size.control)
    }
  }

  private var nextTitle: String {
    guard step == Self.bagStep else { return "Next" }
    return picked.count == 1 ? "Add 1 bean" : "Add \(picked.count) beans"
  }

  /// Three equal ways in: scan the barcode or QR code, photograph the bag, or pick from a list of
  /// popular coffees (typing is a quiet fallback). Every route ends in a bean the user can edit.
  private var firstBag: some View {
    let shown = PopularBeans.search(beanSearch)
    return VStack(alignment: .leading, spacing: DS.Space.md) {
      title(
        "Your beans",
        "Scan the barcode or QR code, take a photo of the bag, or pick from the list.")
      GlassEffectContainer(spacing: DS.Space.sm) {
        HStack(spacing: DS.Space.sm) {
          captureButton("Scan the bag", "qrcode.viewfinder", .barcode)
          captureButton("Take a photo", "camera", .photo)
        }
      }
      Text("Or pick from the list").font(DS.Font.headline).foregroundStyle(DS.ink)
        .padding(.top, DS.Space.sm)
      TextField("Search roasters and coffees", text: $beanSearch)
        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
        .padding(.horizontal, DS.Space.md).frame(minHeight: DS.Size.control)
        .glassEffect(
          .regular.tint(DS.paper.opacity(0.6)), in: RoundedRectangle(cornerRadius: DS.controlRadius)
        )
        .accessibilityIdentifier("onboarding.beans.search")
      LazyVStack(spacing: 0) {
        ForEach(shown) { entry in
          let on = picked.contains(entry.id)
          Button {
            if on { picked.remove(entry.id) } else { picked.insert(entry.id) }
          } label: {
            HStack(spacing: DS.Space.md) {
              VStack(alignment: .leading, spacing: 2) {
                Text(entry.coffee).font(.body.weight(on ? .semibold : .regular))
                  .foregroundStyle(DS.ink)
                Text(entry.roaster).font(.footnote).foregroundStyle(DS.ink2)
              }
              Spacer(minLength: DS.Space.sm)
              Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3)
                .foregroundStyle(on ? DS.signal : DS.line)
            }
            .padding(.horizontal, DS.Space.md).frame(minHeight: 56).contentShape(Rectangle())
          }
          .buttonStyle(PressableStyle())
          .accessibilityAddTraits(on ? .isSelected : [])
          .accessibilityIdentifier("onboarding.bean.\(entry.coffee)")
          .sensoryFeedback(.selection, trigger: on)
          if entry.id != shown.last?.id {
            Rectangle().fill(DS.line.opacity(0.3)).frame(height: 1).padding(.leading, DS.Space.md)
          }
        }
      }
      .panel(DS.paper)
      Button("Not listed? Type it in") { capture = .manual }
        .font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
        .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
        .accessibilityIdentifier("onboarding.beans.manual")
    }
  }

  private func captureButton(_ label: String, _ symbol: String, _ start: BeanCaptureStart)
    -> some View
  {
    Button {
      capture = start
    } label: {
      VStack(spacing: DS.Space.xs) {
        Image(systemName: symbol).font(.title2)
        Text(label).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
      }
      .foregroundStyle(DS.ink)
      .frame(maxWidth: .infinity, minHeight: 76).padding(.horizontal, DS.Space.xs)
      .glassEffect(
        .regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(PressableStyle())
    .accessibilityIdentifier("onboarding.beans.\(start.rawValue)")
  }

  private var aiStep: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      if AppleIntelligence.isAvailable {
        title(
          "Apple Intelligence",
          "Next Cup uses Apple's on-device AI: nothing leaves your iPhone and no key is needed."
        )
        Toggle(isOn: $fillsBeans) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Bean me up, Scotty").font(.body.weight(.semibold)).foregroundStyle(DS.ink)
            Text(
              "When you add a coffee, Apple AI suggests the roast, origin and process it knows of. It works from what it already knows, not the bag or a web search, so you accept or dismiss each suggestion on the bean."
            )
            .font(.footnote).foregroundStyle(DS.ink2)
          }
        }
        .padding(DS.Space.md).panel(DS.paper)
        .accessibilityIdentifier("onboarding.ai.fill")
        Text("To use Claude or ChatGPT instead, add a key later in Settings on the Journal page.")
          .font(.footnote).foregroundStyle(DS.ink2)
      } else {
        title(
          "Turn on Apple Intelligence",
          "Next Cup uses Apple's on-device AI to read bags and fill in your beans. Turn it on in the Settings app under Apple Intelligence & Siri, then it works here with no key. Or add a Claude or ChatGPT key later in Settings on the Journal page."
        )
      }
      Image(systemName: "apple.intelligence").font(.system(size: 64)).foregroundStyle(DS.crema)
        .frame(maxWidth: .infinity).padding(.vertical, DS.Space.lg)
        .accessibilityHidden(true)
    }
    .accessibilityIdentifier("onboarding.ai")
  }

  private func title(_ text: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Kicker("Next Cup")
      Text(text.dsTitle).font(DS.Font.instruction).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap)
        .accessibilityAddTraits(.isHeader)
      Text(detail).font(.body).foregroundStyle(DS.ink2)
    }
  }

  // MARK: Actions

  private func next() {
    switch step {
    case 1:
      if saveGrinder() { advance() }
    case Self.bagStep:
      if addPicked() { advance() }
    default:
      advance()
    }
  }

  private func advance() { step += 1 }

  /// Saves each picked coffee as a bean with its roaster; one already saved is reused.
  private func addPicked() -> Bool {
    let entries = PopularBeans.all.filter { picked.contains($0.id) }
    let store = Store(context: context)
    var added: [Bean] = []
    for entry in entries {
      if beans.contains(where: {
        $0.name.caseInsensitiveCompare(entry.coffee) == .orderedSame
          && $0.roaster?.name.caseInsensitiveCompare(entry.roaster) == .orderedSame
      }) {
        continue
      }
      var fields = BeanFields()
      fields.name = entry.coffee
      fields.roasterName = entry.roaster
      switch BeanService(store: store).save(fields) {
      case .success(let bean): added.append(bean)
      case .failure(let failure):
        error = "\(entry.coffee) was not saved. \(failure.message)"
        return false
      }
    }
    BeanDetailsAI.fill(added, in: context)
    error = nil
    return true
  }

  /// A typed grinder is saved and remembered, so the first brew form picks it.
  private func saveGrinder() -> Bool {
    let name = grinder.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return true }
    let store = Store(context: context)
    // Back then Next runs this again: reuse the grinder it saved the first time.
    let existing = ((try? context.fetch(FetchDescriptor<Grinder>())) ?? []).first {
      $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
    let grinder = existing ?? Grinder(name: name)
    if existing == nil { context.insert(grinder) }
    if case .failure(.saveFailed(let message)) = store.save() {
      context.rollback()
      error = "The grinder was not saved. \(message)"
      return false
    }
    UserDefaults.standard.set(grinder.id.uuidString, forKey: BrewFormModel.lastGrinderKey)
    error = nil
    return true
  }

  private func done(_ tab: AppTab) {
    // The region's units count as chosen even when the user skipped that step.
    temperatureUnit = temperatureUnit
    UserDefaults.standard.set(true, forKey: Self.doneKey)
    finish(tab)
  }
}

/// The brewers as a grid of drawings: tap to show or hide a method. Picked ones get the
/// accent ring and a check; the rest dim. At least one stays shown, so the brew form
/// always has one to start from.
struct MethodChips: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var error: String?

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: DS.Space.lg, alignment: .top),
      count: dts.isAccessibilitySize ? 2 : 3)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      if let error { StateBanner(kind: .error, message: error) }
      LazyVGrid(columns: columns, spacing: DS.Space.md) {
        ForEach(methods) { method in
          let on = !method.isHidden
          Button {
            toggle(method)
          } label: {
            VStack(spacing: DS.Space.xs) {
              BrewMedallion(method.glyph, selected: on, dimmed: !on)
              Text(method.shortName)
                .font(.footnote.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? DS.ink : DS.ink2)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
            }
            .padding(.top, 4)
            .contentShape(Rectangle())
          }
          .buttonStyle(PressableStyle())
          .sensoryFeedback(.selection, trigger: on)
          .accessibilityLabel(method.name)
          .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        }
      }
      // Room for the picked ring and check, which sit just outside each medallion.
      .padding(.horizontal, 6)
    }
  }

  private func toggle(_ method: BrewMethod) {
    if !method.isHidden && methods.filter({ !$0.isHidden }).count == 1 { return }
    if case .failure(let failure) = MethodsService(store: Store(context: context))
      .setHidden(method, !method.isHidden)
    {
      error = failure.message
    } else {
      error = nil
    }
  }
}
