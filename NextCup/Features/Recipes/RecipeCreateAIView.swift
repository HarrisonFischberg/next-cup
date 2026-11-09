import NextCupKit
import SwiftData
import SwiftUI

/// "Create with AI" from the Brew tab's +: pick a brewer and grinder, say what you want,
/// and the AI writes a whole recipe with a grind to start at. It opens in the recipe editor to check and Save; nothing is
/// stored before that.
struct RecipeCreateAIView: View {
  let created: (RecipeDraft) -> Void
  let cancel: () -> Void

  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @Query(sort: \Grinder.name) private var grinders: [Grinder]
  @AppStorage(BrewFormModel.lastGrinderKey) private var lastGrinderID = ""
  @State private var methodID: UUID?
  /// A grinder's name, `otherTag` for a typed one, or "" for none.
  @State private var grinderChoice: String?
  @State private var otherGrinder = ""
  @State private var note = ""
  @State private var working = false
  /// True while the provider searches coffee sites, before it writes the recipe.
  @State private var researching = false
  @State private var job: Task<Void, Never>?
  @State private var error: String?
  @State private var disclosure: AIProvider?
  @State private var sizeQuestion: BrewMethod?
  @FocusState private var typing: Bool

  private static let otherTag = "__other__"
  private var method: BrewMethod? { methods.first { $0.id == methodID } }
  private var grinderName: String? {
    let name = (grinderChoice == Self.otherTag ? otherGrinder : grinderChoice ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
  }
  private var provider: String? {
    DirectAI.pendingDisclosure?.title ?? RecipeReviewAI.cloudProviderTitle
  }
  private var available: Bool {
    RecipeReviewAI.isAvailable || DirectAI.pendingDisclosure != nil
  }
  private var canCreate: Bool {
    available && method != nil && !working
      && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Brewer") {
          Picker("Method", selection: $methodID) {
            ForEach(methods.filter { !$0.isHidden } + methods.filter(\.isHidden)) { method in
              Text(method.name).tag(UUID?.some(method.id))
            }
          }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("recipe.create.method")
        }
        .listRowBackground(DS.paper)
        Section {
          Picker("Grinder", selection: $grinderChoice) {
            Text("None").tag(String?.some(""))
            ForEach(grinders) { grinder in
              Text(grinder.name).tag(String?.some(grinder.name))
            }
            Text("Other…").tag(String?.some(Self.otherTag))
          }
          .frame(minHeight: DS.Size.control)
          .accessibilityIdentifier("recipe.create.grinder")
          if grinderChoice == Self.otherTag {
            TextField("Grinder name, e.g. Comandante C40", text: $otherGrinder)
              .textInputAutocapitalization(.words).autocorrectionDisabled()
              .focused($typing).frame(minHeight: DS.Size.control)
              .accessibilityIdentifier("recipe.create.grinderName")
          }
        } header: {
          Text("Grinder")
        } footer: {
          Text("The recipe says where to start on it.")
        }
        .listRowBackground(DS.paper)
        Section {
          TextField(
            "For example: 600 g of water for an 18 oz mug. My dripper only holds 400 g, so "
              + "steep half with the valve closed, drain, then pour over the rest.",
            text: $note, axis: .vertical
          )
          .lineLimit(4...12).focused($typing)
          .accessibilityIdentifier("recipe.create.note")
        } header: {
          Text("What you want")
        } footer: {
          Text(footer)
        }
        .listRowBackground(DS.paper)
        if let error {
          Text(error).font(.footnote).foregroundStyle(DS.error)
            .listRowBackground(DS.bg)
            .accessibilityIdentifier("recipe.create.error")
        }
      }
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .background(DS.bg)
      .overlay {
        if working { brewing.transition(.opacity) }
      }
      .animation(.easeInOut(duration: 0.25), value: working)
      .navigationTitle("Create with AI")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            job?.cancel()
            cancel()
          }.accessibilityIdentifier("recipe.create.cancel")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { typing = false }
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        SteelButton(title: "Create recipe", isLoading: working, action: create)
          .disabled(!canCreate)
          .accessibilityIdentifier("recipe.create.go")
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
          .background(DS.bg, ignoresSafeAreaEdges: .bottom)
      }
      .sheet(item: $disclosure) { provider in
        AIDisclosureView(provider: provider) {
          AIPreferences().acceptDisclosure(for: provider)
          disclosure = nil
          create()
        } cancel: {
          disclosure = nil
        }
      }
      .sheet(item: $sizeQuestion) { method in
        BrewerSizeQuestion(method: method) {
          sizeQuestion = nil
          create()
        }
      }
      .onAppear {
        #if DEBUG
          // Holds the brewing screen for screenshots and recordings.
          if ProcessInfo.processInfo.arguments.contains("-brewingPreview") {
            working = true
            researching = true
          }
          // Opens the brewer size question for screenshots and UI tests.
          if ProcessInfo.processInfo.arguments.contains("-brewerSizeQuestion") {
            sizeQuestion = methods.first { $0.builtInKey == "switchable-dripper" }
            methodID = sizeQuestion?.id
          }
        #endif
        if methodID == nil { methodID = methods.first { !$0.isHidden }?.id }
        if grinderChoice == nil {
          grinderChoice =
            grinders.first { $0.id.uuidString == lastGrinderID }?.name
            ?? grinders.first?.name ?? ""
        }
      }
    }
    .accessibilityIdentifier("recipe.create")
  }

  /// Covers the form while the AI works: the cup brews and the caption says which step.
  private var brewing: some View {
    VStack(spacing: DS.Space.lg) {
      BrewingCupView().frame(maxWidth: 180)
      VStack(spacing: DS.Space.xs) {
        Text(researching ? "Reading coffee sites" : "Brewing your recipe")
          .font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(
          researching
            ? "Looking up popular recipes for this brewer."
            : "Working out the dose, water and every step."
        )
        .font(.body).foregroundStyle(DS.ink2).multilineTextAlignment(.center)
      }
      .accessibilityElement(children: .combine)
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.bg)
    .accessibilityIdentifier("recipe.create.brewing")
  }

  private var footer: String {
    guard available else {
      return "Turn on Apple Intelligence, or add a key in Settings > AI, to create recipes."
    }
    if let provider {
      return "Sends the brewer, grinder and what you typed to \(provider), which searches "
        + "popular coffee sites for recipes first and lists them as sources. The recipe opens "
        + "for you to check and save."
    }
    return "Apple Intelligence writes it on this iPhone. It is a small model and cannot search "
      + "the web; an Anthropic or OpenAI key in Settings > AI researches coffee sites and "
      + "writes far better recipes."
  }

  private func create() {
    typing = false
    error = nil
    if let pending = DirectAI.pendingDisclosure {
      disclosure = pending
      return
    }
    guard let method else { return }
    if BrewerCapacity.needsAsking(method.builtInKey) {
      sizeQuestion = method
      return
    }
    let brewer = BrewerFit.current(method.builtInKey)
    var base = RecipeDraft()
    base.name = "\(method.name) (AI)"
    base.methodID = method.id
    let style = RecipeFormat.title(method.style)
    let grinder = grinderName
    working = true
    job = Task {
      defer {
        working = false
        researching = false
      }
      // A failed search never blocks the recipe: it is written without sources instead.
      researching = DirectAI.cloudProviderTitle != nil
      let research = try? await DirectAI.research(
        RecipeReviewAI.researchQuestion(
          methodName: method.name, style: style, note: note, grinder: grinder),
        system: RecipeReviewAI.researchSystem)
      researching = false
      guard !Task.isCancelled else { return }
      let payload = RecipeReviewAI.createPayload(
        methodName: method.name, style: style, note: note, grinder: grinder, research: research,
        brewer: brewer)
      do {
        let review = try await RecipeReviewAI.review(
          payload, base: base, mode: .create, brewer: brewer)
        guard !Task.isCancelled else { return }
        var draft = review.draft
        draft.credit = "AI, from your note"
        draft.tuningNote = RecipeReviewAI.note(
          RecipeReviewAI.summary(review.summary, sources: research?.sources ?? []),
          grind: review.grind, grinder: grinderName)
        draft.grindSetting = RecipeReviewAI.wheelSetting(review.grind, grinder: grinderName)
        draft.grinderName = draft.grindSetting == nil ? nil : grinderName
        created(draft)
      } catch {
        guard !Task.isCancelled else { return }
        self.error =
          "The AI could not write a recipe that adds up. Try again, or say a little more."
      }
    }
  }
}
