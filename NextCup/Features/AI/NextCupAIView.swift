import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// The sheet behind "Ask AI for Next Cup" (Past Brews long press) and "Ask AI about this
/// brew" (saved brew): the provider's notice if it is due, the cup brewing while the AI
/// works, then what changed with Open in Brew. A failure changes nothing and offers Try again.
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
  @State private var undoError: String?

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
                Button(phase == .working ? "Cancel" : "Close") {
                  job?.cancel()
                  close()
                }
                .accessibilityIdentifier("nextcup.close")
              }
            }
        }
      }
    }
    .interactiveDismissDisabled(phase == .working)
    .onAppear { if phase == nil { start() } }
    .onDisappear { job?.cancel() }
    .accessibilityIdentifier("nextcup.sheet")
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
            "Sending this brew to \($0). It may search coffee sites first."
          } ?? "Reading this brew on this iPhone."
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
        Text("Your Next Cup is on the Brew tab").font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("nextcup.done")
        if !outcome.summary.isEmpty {
          Text(outcome.summary).font(.body).foregroundStyle(DS.ink2)
        }
        ForEach(outcome.changes, id: \.self) { change in
          VStack(alignment: .leading, spacing: 2) {
            Text(change.what).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
            if !change.why.isEmpty {
              Text(change.why).font(.subheadline).foregroundStyle(DS.ink2)
            }
          }
          .accessibilityElement(children: .combine)
        }
        if outcome.replaced != nil {
          Text("It replaced your earlier Next Cup for this method.")
            .font(.footnote).foregroundStyle(DS.ink2)
        }
        if let undoError {
          StateBanner(kind: .error, message: undoError)
        }
      }
      .padding(DS.Space.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: DS.Space.sm) {
        SteelButton(title: "Open in Brew") {
          router?.showRecipe(outcome.recipeID)
          close()
        }
        .accessibilityIdentifier("nextcup.open")
        if let replaced = outcome.replaced {
          SteelButton(title: "Put the old one back", kind: .secondary) { putBack(replaced) }
            .accessibilityIdentifier("nextcup.undo")
        }
      }
      .padding(DS.Space.lg)
      .background(DS.bg, ignoresSafeAreaEdges: .bottom)
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

  private func putBack(_ replaced: RecipeDraft) {
    let service = RecipeEditorService(store: Store(context: context))
    if case .failure(let failure) = service.save(replaced) {
      undoError = failure.message
    } else {
      close()
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
