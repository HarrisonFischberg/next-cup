import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// Opens after a scanned bag is saved, and from a bean's page: "How do you want it to
/// taste?" with quick picks and free text, or three picks with no goal. The AI then ranks
/// three ways to brew it on the user's brewers, each with Start brew. Nothing is stored
/// until that tap.
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
  @Query private var grinders: [Grinder]
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var phase = Phase.asking
  @State private var goal = ""
  @State private var job: Task<Void, Never>?
  @State private var saveError: String?
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

  private var asking: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text("How do you want it to taste?").font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text("Pick one or describe it. You'll get three ways to brew this bean on your brewers.")
          .font(.body).foregroundStyle(DS.ink2)
        TextField("For example: chocolatey and full-bodied", text: $goal, axis: .vertical)
          .lineLimit(1...4).focused($typing).submitLabel(.go)
          .onSubmit(ask)
          .padding(DS.Space.md).frame(minHeight: DS.Size.control)
          .panel(DS.paper)
          .accessibilityIdentifier("beanbrew.goal")
        chips
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: DS.Space.sm) {
        SteelButton(title: "Get 3 brews for this taste", action: ask)
          .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("beanbrew.ask")
        SteelButton(title: "Just recommend 3", kind: .secondary) {
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

  private var chips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DS.Space.sm) {
        ForEach(BeanBrewAI.goals, id: \.self) { option in
          let chosen = goal == option
          Button(option) { goal = chosen ? "" : option }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(chosen ? DS.onSignal : DS.ink)
            .padding(.horizontal, DS.Space.md).frame(minHeight: DS.Size.control)
            .background(Capsule().fill(chosen ? DS.signal : DS.paper))
            .overlay(Capsule().strokeBorder(DS.line, lineWidth: chosen ? 0 : 1))
            .accessibilityAddTraits(chosen ? .isSelected : [])
        }
      }
    }
    .scrollClipDisabled()
    .sensoryFeedback(.selection, trigger: goal)
    .accessibilityIdentifier("beanbrew.chips")
  }

  // MARK: Working and results

  private var working: some View {
    VStack(spacing: DS.Space.lg) {
      BrewingCupView().frame(maxWidth: 180)
      VStack(spacing: DS.Space.xs) {
        Text("Picking three brews").font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(
          RecipeReviewAI.cloudProviderTitle.map {
            "Sending this bean, what you want and your brewers to \($0)."
          } ?? "Working it out on this iPhone."
        )
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
        Text(goal.isEmpty ? "Three ways to brew it" : "Three ways to get \(goal.lowercased())")
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
        Button("Try a different taste") { phase = .asking }
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
      SteelButton(title: "Start brew", kind: rank == 1 ? .primary : .secondary) { start(pick) }
        .accessibilityIdentifier("beanbrew.start.\(rank)")
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
    let goal = goal
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
          bean: bean, goal: goal, store: store, grinder: grinderName, send: send)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phase = .done(outcome)
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        phase = .failed(NextCupAIView.message(for: error))
      }
    }
  }

  /// Saves the pick as a recipe and opens its Start brew page with this bean chosen.
  private func start(_ pick: BeanBrewAI.Pick) {
    switch BeanBrewAI.save(pick.draft, store: Store(context: context)) {
    case .success(let recipe):
      router?.startBrew(recipe: recipe.id, bean: bean.id)
      close()
    case .failure(let failure):
      saveError = failure.message
    }
  }
}
