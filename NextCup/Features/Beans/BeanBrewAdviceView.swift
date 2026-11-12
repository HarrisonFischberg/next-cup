import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// Opens after a scanned bag is saved, and from a bean's page: "Ways to brew [bean]" with a
/// grid of tastes (up to three, one recipe each, plus free text) or "Recommend 3 recipes".
/// Each recipe is then saved or composted; once all are decided, the Brew tab opens with the
/// saved ones under "Recipe to try for your Next Cup". Nothing is stored until Save.
struct BeanBrewAdviceView: View {
  let bean: Bean
  let close: () -> Void

  private enum Phase: Equatable {
    case asking
    case disclosure(AIProvider)
    case unavailable
    case working
    case failed(String)
    case done(BeanBrewAI.Outcome)
  }

  @Environment(\.modelContext) private var context
  @Environment(AppRouter.self) private var router: AppRouter?
  @Environment(\.dynamicTypeSize) private var dts
  @Query private var grinders: [Grinder]
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var phase = Phase.asking
  @State private var chosen: [String] = []
  @State private var goal = ""
  /// The tastes the last request was made for, for the results heading.
  @State private var asked: [String] = []
  @State private var job: Task<Void, Never>?
  @State private var saveError: String?
  /// What the user did with each pick: true saved, false composted.
  @State private var decided: [UUID: Bool] = [:]
  @FocusState private var typing: Bool

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var grinderName: String? { grinders.first { $0.id.uuidString == lastGrinderID }?.name }

  var body: some View {
    Group {
      if case .disclosure(let provider) = phase {
        AIDisclosureView(provider: provider) {
          AIPreferences().acceptDisclosure(for: provider)
          ask()
        } cancel: {
          phase = .asking
        }
      } else {
        NavigationStack {
          content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.bg)
            .navigationTitle(bean.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(phase == .working ? "Cancel" : "Close") {
                  job?.cancel()
                  close()
                }
                .accessibilityIdentifier("beanbrew.close")
              }
              ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
              }
            }
        }
      }
    }
    .interactiveDismissDisabled(phase == .working)
    .onDisappear { job?.cancel() }
    .accessibilityIdentifier("beanbrew.sheet")
  }

  @ViewBuilder private var content: some View {
    switch phase {
    case .asking: asking
    case .working: working
    case .failed(let message):
      VStack(spacing: DS.Space.lg) {
        StateBanner(kind: .error, message: message, actionTitle: "Try again", action: ask)
          .accessibilityIdentifier("beanbrew.error")
        Button("Change what you want") { phase = .asking }
          .frame(minHeight: DS.Size.control)
        Spacer()
      }
      .padding(DS.Space.lg)
    case .unavailable:
      ScrollView {
        EmptyState(
          title: "AI is off",
          message: "Turn on Apple Intelligence, or add a key in Settings > AI, to get brew advice."
        )
      }
      .accessibilityIdentifier("beanbrew.unavailable")
    case .done(let outcome): done(outcome)
    case .disclosure: EmptyView()
    }
  }

  // MARK: Asking

  /// The tastes to send: the chosen tiles, then the typed one, at most three.
  private var goals: [String] { BeanBrewAI.clean(chosen + [goal]) }

  private var asking: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text("Ways to brew \(bean.name)").font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text("Pick up to 3 tastes and get one recipe for each on your brewers.")
          .font(.body).foregroundStyle(DS.ink2)
        grid
        TextField("Or describe your own", text: $goal, axis: .vertical)
          .lineLimit(1...4).focused($typing).submitLabel(.go)
          .onSubmit { if !goals.isEmpty { ask() } }
          .padding(DS.Space.md).frame(minHeight: DS.Size.control)
          .panel(DS.paper)
          .accessibilityIdentifier("beanbrew.goal")
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: DS.Space.sm) {
        let count = max(goals.count, 1)
        SteelButton(
          title: "\(count) \(count == 1 ? "recipe" : "recipes") for \(bean.name)", action: ask
        )
        .disabled(goals.isEmpty)
        .accessibilityIdentifier("beanbrew.ask")
        SteelButton(title: "Recommend 3 recipes", kind: .secondary) {
          chosen = []
          goal = ""
          ask()
        }
        .accessibilityIdentifier("beanbrew.recommend")
      }
      .padding(DS.Space.lg)
      .background(DS.bg, ignoresSafeAreaEdges: .bottom)
      .hiddenWhileTyping()
    }
  }

  /// Every taste at once, two across (one across at large text sizes).
  private var grid: some View {
    let full = goals.count >= BeanBrewAI.pickCount
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: DS.Space.sm),
      count: dts.isAccessibilitySize ? 1 : 2)
    return LazyVGrid(columns: columns, spacing: DS.Space.sm) {
      ForEach(BeanBrewAI.goals, id: \.self) { option in
        let on = chosen.contains(option)
        Button {
          if on { chosen.removeAll { $0 == option } } else { chosen.append(option) }
        } label: {
          Text(option)
            .font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
            .foregroundStyle(on ? DS.onSignal : DS.ink)
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, minHeight: DS.Size.primary, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.radius).fill(on ? DS.signal : DS.paper))
            .overlay(
              RoundedRectangle(cornerRadius: DS.radius)
                .strokeBorder(DS.line, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(full && !on)
        .opacity(full && !on ? 0.5 : 1)
        .accessibilityAddTraits(on ? .isSelected : [])
      }
    }
    .sensoryFeedback(.selection, trigger: chosen)
    .accessibilityIdentifier("beanbrew.chips")
  }

  // MARK: Working and results

  private var working: some View {
    VStack(spacing: DS.Space.lg) {
      BrewingCupView().frame(maxWidth: 180)
      VStack(spacing: DS.Space.xs) {
        Text("Picking three brews").font(DS.Font.headline).foregroundStyle(DS.ink)
        Text("Research, development and bean magic ahead!")
          .font(.body).foregroundStyle(DS.ink2).multilineTextAlignment(.center)
      }
      .accessibilityElement(children: .combine)
    }
    .padding(DS.Space.lg)
    .accessibilityIdentifier("beanbrew.working")
  }

  private func done(_ outcome: BeanBrewAI.Outcome) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text(
          asked.count > 1
            ? "A recipe for each taste"
            : asked.first.map { "Ways to get \($0.lowercased())" } ?? "Three ways to brew it"
        )
        .font(DS.Font.headline).foregroundStyle(DS.ink)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("beanbrew.done")
        if !outcome.summary.isEmpty {
          Text(outcome.summary).font(.body).foregroundStyle(DS.ink2)
        }
        if let saveError { StateBanner(kind: .error, message: saveError) }
        ForEach(Array(outcome.picks.enumerated()), id: \.element.id) { index, pick in
          card(pick, rank: index + 1)
        }
        Button("Try different tastes") { phase = .asking }
          .frame(maxWidth: .infinity, minHeight: DS.Size.control)
          .accessibilityIdentifier("beanbrew.again")
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func card(_ pick: BeanBrewAI.Pick, rank: Int) -> some View {
    let draft = pick.draft
    let ratio = BrewMath.ratioLabel(BrewMath.ratio(doseG: draft.doseG, waterG: draft.waterG))
    let facts: [(String, String)] = [
      ("Grind", draft.grindSetting ?? (pick.grind.isEmpty ? "—" : pick.grind)),
      ("Ratio", ratio ?? "—"),
      ("Temp", draft.tempC.map { RecipeFormat.temperature($0, units) } ?? "—"),
      ("Time", draft.totalTimeS.map(RecipeFormat.clock) ?? "—"),
    ]
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline) {
        Text("\(rank)").font(.subheadline.weight(.bold).monospacedDigit())
          .foregroundStyle(DS.accent)
        Text(pick.methodName).font(DS.Font.headline).foregroundStyle(DS.ink)
        Spacer()
        Text(draft.name).font(.subheadline).foregroundStyle(DS.ink2).lineLimit(1)
      }
      if !pick.goal.isEmpty {
        Text("For \(pick.goal.lowercased())").font(.subheadline.weight(.semibold))
          .foregroundStyle(DS.accent)
      }
      Text(
        "\(RecipeFormat.weight(draft.doseG, units)) coffee · \(RecipeFormat.weight(draft.waterG, units)) water"
      )
      .font(.subheadline).foregroundStyle(DS.ink2)
      HStack(spacing: DS.Space.md) {
        ForEach(facts, id: \.0) { label, value in
          VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(DS.ink2)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
              .foregroundStyle(DS.ink)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityElement(children: .combine)
        }
      }
      if !pick.why.isEmpty {
        Text(pick.why).font(.subheadline).foregroundStyle(DS.ink2)
      }
      switch decided[pick.id] {
      case true?:
        Label("Saved to try on the Brew tab", systemImage: "checkmark.circle.fill")
          .font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
          .frame(minHeight: DS.Size.minTap)
          .accessibilityIdentifier("beanbrew.saved.\(rank)")
      case false?:
        HStack {
          Label("In the compost bin", systemImage: "leaf")
            .font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink2)
          Spacer()
          Button("Undo") { decided[pick.id] = nil }
            .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
            .accessibilityIdentifier("beanbrew.undo.\(rank)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("beanbrew.composted.\(rank)")
      case nil:
        ViewThatFits(in: .horizontal) {
          HStack(spacing: DS.Space.sm) { actions(pick, rank: rank) }
          VStack(spacing: DS.Space.sm) { actions(pick, rank: rank) }
        }
      }
    }
    .padding(DS.Space.md)
    .panel(DS.paper)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("beanbrew.pick.\(rank)")
  }

  // MARK: Actions

  private var fakes: Bool {
    #if DEBUG
      BeanBrewAI.fakesAnswer
    #else
      false
    #endif
  }

  private func ask() {
    typing = false
    if !fakes, let pending = DirectAI.pendingDisclosure {
      phase = .disclosure(pending)
      return
    }
    guard fakes || RecipeReviewAI.isAvailable else {
      phase = .unavailable
      return
    }
    phase = .working
    saveError = nil
    let goals = goals
    asked = goals
    decided = [:]
    job = Task {
      do {
        let store = Store(context: context)
        var send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
          try await DirectAI.send($0)
        }
        #if DEBUG
          if fakes {
            let answer = BeanBrewAI.fakeAnswer(methods: BeanBrewAI.methods(store: store))
            send = { _ in
              try await Task.sleep(for: .seconds(1))
              return (answer, "Test answer")
            }
          }
        #endif
        let outcome = try await BeanBrewAI.ask(
          bean: bean, goals: goals, store: store, grinder: grinderName, send: send)
        Feedback.success()
        phase = .done(outcome)
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled else { return }
        Feedback.error()
        phase = .failed(NextCupAIView.message(for: error))
      }
    }
  }

  @ViewBuilder private func actions(_ pick: BeanBrewAI.Pick, rank: Int) -> some View {
    SteelButton(title: "Save") { save(pick) }
      .accessibilityHint("Keeps it on the Brew tab under Recipe to try for your Next Cup")
      .accessibilityIdentifier("beanbrew.save.\(rank)")
    SteelButton(title: "Compost bin", kind: .secondary) {
      Feedback.tap()
      decided[pick.id] = false
      finishIfDecided()
    }
    .accessibilityHint("Drops this recipe")
    .accessibilityIdentifier("beanbrew.compost.\(rank)")
  }

  /// Saves the pick as a recipe to try.
  private func save(_ pick: BeanBrewAI.Pick) {
    switch BeanBrewAI.save(pick.draft, bean: bean, store: Store(context: context)) {
    case .success:
      saveError = nil
      decided[pick.id] = true
      Feedback.success()
      finishIfDecided()
    case .failure(let failure):
      saveError = failure.message
    }
  }

  /// Once every recipe is saved or composted, the Brew tab opens on the saved ones (a moment
  /// later, so the last choice and its Undo can be seen).
  private func finishIfDecided() {
    guard case .done(let outcome) = phase,
      outcome.picks.allSatisfy({ decided[$0.id] != nil })
    else { return }
    let snapshot = decided
    Task {
      try? await Task.sleep(for: .seconds(1.2))
      guard decided == snapshot else { return }
      if decided.values.contains(true) { router?.showBrewTop() }
      close()
    }
  }
}
