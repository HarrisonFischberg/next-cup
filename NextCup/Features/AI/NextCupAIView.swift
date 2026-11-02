import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// The sheet behind "Ask AI for Next Cup" (Past Brews long press and saved brew): the
/// provider's notice if it is due, the cup brewing while the AI works, then the overview and
/// what changed with Save Next Cup, which lands on the Brew tab. Nothing is stored before that
/// tap. A failure changes nothing and offers Try again.
struct NextCupAIView: View {
  let brew: Brew
  let close: () -> Void

  private enum Phase: Equatable {
    case disclosure(AIProvider)
    case unavailable
    case working
    case failed(String)
    case done(NextCupAI.Outcome)
  }

  @Environment(\.modelContext) private var context
  @Environment(AppRouter.self) private var router: AppRouter?
  @State private var phase: Phase?
  @State private var job: Task<Void, Never>?
  @State private var saveError: String?

  var body: some View {
    Group {
      if case .disclosure(let provider) = phase {
        AIDisclosureView(provider: provider) {
          AIPreferences().acceptDisclosure(for: provider)
          start()
        } cancel: {
          close()
        }
      } else {
        NavigationStack {
          content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.bg)
            .navigationTitle(NextCupAI.recipeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(closeTitle) {
                  job?.cancel()
                  close()
                }
                .accessibilityIdentifier("nextcup.close")
              }
            }
        }
      }
    }
    // A finished answer is unsaved, so a stray swipe must not throw it away.
    .interactiveDismissDisabled(phase == .working || isDone)
    .onAppear { if phase == nil { start() } }
    .onDisappear { job?.cancel() }
    .accessibilityIdentifier("nextcup.sheet")
  }

  private var isDone: Bool {
    if case .done = phase { return true }
    return false
  }

  private var closeTitle: String {
    if isDone { return "Discard" }
    return phase == .working ? "Cancel" : "Close"
  }

  @ViewBuilder private var content: some View {
    switch phase {
    case .working: working
    case .failed(let message):
      VStack(spacing: DS.Space.lg) {
        StateBanner(kind: .error, message: message, actionTitle: "Try again", action: start)
          .accessibilityIdentifier("nextcup.error")
        Spacer()
      }
      .padding(DS.Space.lg)
    case .done(let outcome): done(outcome)
    case .unavailable:
      ScrollView {
        EmptyState(
          title: "AI is off",
          message: "Turn on Apple Intelligence, or add a key in Settings > AI, to ask about a brew."
        )
      }
      .accessibilityIdentifier("nextcup.unavailable")
    case .disclosure, .none: EmptyView()
    }
  }

  private var working: some View {
    VStack(spacing: DS.Space.lg) {
      BrewingCupView().frame(maxWidth: 180)
      VStack(spacing: DS.Space.xs) {
        Text("Working out your next cup").font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(
          RecipeReviewAI.cloudProviderTitle.map {
            "Sending this brew and your similar past brews to \($0). It may search coffee sites first."
          } ?? "Reading this brew and your similar past brews on this iPhone."
        )
        .font(.body).foregroundStyle(DS.ink2).multilineTextAlignment(.center)
      }
      .accessibilityElement(children: .combine)
    }
    .padding(DS.Space.lg)
    .accessibilityIdentifier("nextcup.working")
  }

  private func done(_ outcome: NextCupAI.Outcome) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.md) {
        Text("Your Next Cup is ready").font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("nextcup.done")
        if !outcome.summary.isEmpty {
          Text(outcome.summary).font(.body).foregroundStyle(DS.ink2)
        }
        Text(basis(outcome.similarCount))
          .font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("nextcup.basis")
        ForEach(outcome.changes, id: \.self) { change in
          VStack(alignment: .leading, spacing: 2) {
            Text(change.what).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
            if !change.why.isEmpty {
              Text(change.why).font(.subheadline).foregroundStyle(DS.ink2)
            }
          }
          .accessibilityElement(children: .combine)
        }
        if outcome.replacesEarlier {
          Text("Saving replaces your earlier Next Cup for this method.")
            .font(.footnote).foregroundStyle(DS.ink2)
            .accessibilityIdentifier("nextcup.replaces")
        }
        if let saveError {
          StateBanner(kind: .error, message: saveError)
        }
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      SteelButton(title: "Save Next Cup") { save(outcome.draft) }
        .accessibilityIdentifier("nextcup.save")
        .padding(DS.Space.lg)
        .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    }
  }

  private func basis(_ count: Int) -> String {
    switch count {
    case 0: "Based on this brew. You have no similar past brews yet."
    case 1: "Based on this brew and 1 similar past brew."
    default: "Based on this brew and \(count) similar past brews."
    }
  }

  private var fakes: Bool {
    #if DEBUG
      NextCupAI.fakesAnswer
    #else
      false
    #endif
  }

  private func start() {
    if !fakes, let pending = DirectAI.pendingDisclosure {
      phase = .disclosure(pending)
      return
    }
    guard fakes || RecipeReviewAI.isAvailable else {
      phase = .unavailable
      return
    }
    phase = .working
    job = Task {
      do {
        let outcome = try await ask()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phase = .done(outcome)
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        phase = .failed(Self.message(for: error))
      }
    }
  }

  private func ask() async throws -> NextCupAI.Outcome {
    let store = Store(context: context)
    #if DEBUG
      if fakes {
        let answer = NextCupAI.fakeAnswer(for: NextCupAI.base(for: brew, store: store))
        return try await NextCupAI.ask(
          about: brew, store: store, research: { _ in nil },
          send: { _ in
            try await Task.sleep(for: .seconds(1))
            return (answer, "Test answer")
          })
      }
    #endif
    return try await NextCupAI.ask(about: brew, store: store)
  }

  private func save(_ draft: RecipeDraft) {
    switch NextCupAI.save(draft, store: Store(context: context)) {
    case .success:
      router?.showBrewTop()
      close()
    case .failure(let failure):
      saveError = failure.message
    }
  }

  /// Why nothing was saved. An answer that fails the recipe checks gets its own words.
  static func message(for error: Error) -> String {
    if let failure = error as? RecipeEditorError { return failure.message }
    if case AIError.invalidResponse = error {
      return "The AI's answer did not make a recipe that adds up, so nothing was changed."
    }
    return (error as? LocalizedError)?.errorDescription
      ?? "The AI could not answer. Nothing was changed."
  }
}
