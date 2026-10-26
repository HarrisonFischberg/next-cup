import NextCupKit
import SwiftData
import SwiftUI

/// First run: three short steps, each skippable, then a finish that points at the
/// first brew. Nothing behind it is locked, and it asks nothing the app already knows.
struct OnboardingView: View {
  static let doneKey = "onboarding.done"

  /// Called with the tab to land on.
  let finish: (AppTab) -> Void

  @Environment(\.modelContext) private var context
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Query private var beans: [Bean]
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = OnboardingView
    .regionTemperature.rawValue
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var step = 1
  @State private var grinder = ""
  @State private var addingBean = false
  @State private var error: String?

  private static let steps = 3

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
              default: firstBag
              }
            }
          }
          .scrollDismissesKeyboard(.interactively)
          SteelButton(title: step == Self.steps ? "Scan the bag" : "Next", action: next)
            .accessibilityIdentifier("onboarding.next")
          if step == Self.steps {
            Button("Add a bag later") { advance() }
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
            primaryTitle: beans.isEmpty ? "Browse recipes" : "Log my first brew",
            primary: { done(beans.isEmpty ? .recipes : .journal) },
            playsHaptic: true)
          Spacer()
        }
      }
      .padding(DS.Space.lg)
      .background(DS.bg)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: step)
      .toolbar {
        if step <= Self.steps {
          ToolbarItem(placement: .cancellationAction) {
            Button("Skip") { done(.journal) }.accessibilityIdentifier("onboarding.skip")
          }
        }
      }
      .sheet(isPresented: $addingBean, onDismiss: advance) {
        BeanEditorView(target: .new) { addingBean = false }
      }
    }
    .accessibilityIdentifier("onboarding")
  }

  // MARK: Steps

  private var brewer: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      title("What do you brew with?", "Pick the methods you use. The rest stay out of the way.")
      FlowChips(items: methods.map { ($0.id, $0.name, !$0.isHidden) }) { id in
        guard let method = methods.first(where: { $0.id == id }) else { return }
        // Keep at least one method, so the brew form always has one to start from.
        if !method.isHidden && methods.filter({ !$0.isHidden }).count == 1 { return }
        if case .failure(let failure) = MethodsService(store: Store(context: context))
          .setHidden(method, !method.isHidden)
        {
          error = failure.localizedDescription
        }
      }
      TextField("Grinder (optional)", text: $grinder)
        .textInputAutocapitalization(.words).submitLabel(.done)
        .padding(.horizontal, DS.Space.md).frame(minHeight: DS.Size.control)
        .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.controlRadius))
        .accessibilityIdentifier("onboarding.grinder")
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

  private var firstBag: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      title(
        "Your first bag",
        "Scan its barcode or label and Next Cup fills in the details. You check every field before it is saved."
      )
      Image(systemName: "barcode.viewfinder").font(.system(size: 64)).foregroundStyle(DS.crema)
        .frame(maxWidth: .infinity).padding(.vertical, DS.Space.lg)
        .accessibilityHidden(true)
    }
  }

  private func title(_ text: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Text(text.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
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
    case Self.steps:
      addingBean = true
    default:
      advance()
    }
  }

  private func advance() { step += 1 }

  /// A typed grinder is saved and remembered, so the first brew form picks it.
  private func saveGrinder() -> Bool {
    let name = grinder.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return true }
    let store = Store(context: context)
    let grinder = Grinder(name: name)
    context.insert(grinder)
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

/// Wrapping toggle chips, for picking a few from a short list.
private struct FlowChips: View {
  let items: [(id: UUID, title: String, on: Bool)]
  let toggle: (UUID) -> Void

  var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 130), spacing: DS.Space.sm)], spacing: DS.Space.sm
    ) {
      ForEach(items, id: \.id) { item in
        Button {
          toggle(item.id)
        } label: {
          Label(item.title, systemImage: item.on ? "checkmark.circle.fill" : "circle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(item.on ? DS.ink : DS.ink2)
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap)
            .background(item.on ? DS.crema.opacity(0.15) : DS.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(item.on ? DS.crema : DS.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.on ? [.isButton, .isSelected] : .isButton)
      }
    }
  }
}
