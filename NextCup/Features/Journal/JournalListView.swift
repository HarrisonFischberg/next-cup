import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// S01: the journal. Newest brews first, searchable, filterable by method and
/// bean, with the filter and order remembered. Delete is a swipe (or the row's
/// menu, or a VoiceOver action) followed by an Undo toast: the brew is only
/// removed from the store once the toast times out or the screen is left.
struct JournalListView: View {
  let router: AppRouter

  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query(sort: \Brew.date, order: .reverse) private var brews: [Brew]
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var search = ""
  @State private var pendingDelete: UUID?
  @State private var deleteTimer: Task<Void, Never>?
  @State private var deleteError: String?
  @State private var showImport = false
  /// Brews started or edited and left without saving, read from the draft files.
  @State private var unsaved: [SavedDraft] = []
  @AppStorage(JournalStorage.methodKey) private var methodFilter = ""
  @AppStorage(JournalStorage.beanKey) private var beanFilter = ""
  @AppStorage(JournalStorage.sortKey) private var sortChoice = JournalSort.newest.rawValue
  @AppStorage(GettingStartedCard.dismissedKey) private var gettingStartedDismissed = false
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private static let undoSeconds = 6

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  /// Every saved brew except the one waiting out its Undo window.
  private var logged: [Brew] { brews.filter { $0.id != pendingDelete } }

  /// A remembered method or bean that no longer exists is ignored, so an old
  /// choice can never leave the journal looking empty.
  private func filter(beanNames: [String]) -> JournalFilter {
    let methodID = UUID(uuidString: methodFilter)
    return JournalFilter(
      search: search,
      methodID: methods.contains { $0.id == methodID } ? methodID : nil,
      beanName: beanNames.contains(beanFilter) ? beanFilter : nil,
      sort: JournalSort(rawValue: sortChoice) ?? .newest)
  }

  var body: some View {
    // Computed once per update: each pass walks every brew and its beans.
    let logged = self.logged
    let beanNames = Set(logged.flatMap(\.beanNames)).sorted()
    let filter = filter(beanNames: beanNames)
    let shown = filter.apply(to: logged)
    Group {
      if logged.isEmpty {
        ScrollView {
          header.padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.sm)
          if gettingStartedDismissed {
            EmptyState(
              title: "No brews yet",
              message: "Log a brew and it will be listed here, newest first.",
              actionTitle: "Log a brew", action: { router.open(.newBrew) })
          } else {
            GettingStartedCard(
              logBrew: { router.open(.newBrew) }, importPage: { showImport = true })
          }
          if !unsaved.isEmpty {
            LazyVStack(alignment: .leading, spacing: DS.Space.sm) {
              unsavedHeader
              ForEach(unsaved) { entry in
                Button {
                  openUnsaved(entry)
                } label: {
                  UnsavedBrewRow(entry: entry, methods: methods)
                    .background(
                      RoundedRectangle(cornerRadius: max(DS.radius, 18), style: .continuous)
                        .fill(DS.paper))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Space.lg)
                .contextMenu { discardButton(entry) }
              }
            }
          }
        }
      } else if shown.isEmpty {
        ScrollView {
          EmptyState(
            title: "No matches", message: "No brew matches. Try fewer words or clear the filters.",
            actionTitle: "Clear filters", action: clearFilters)
        }
      } else {
        list(shown, logged: logged)
      }
    }
    .background(DS.bg)
    .searchable(
      text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search brews"
    )
    .safeAreaInset(edge: .top, spacing: 0) {
      if !logged.isEmpty { filterBar(filter, beanNames: beanNames) }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { toast }
    .toolbar {
      ToolbarItem(placement: .primaryAction) { SettingsGear(id: "journal.settings") }
      ToolbarItem(placement: .primaryAction) {
        // A tap logs a brew at once; holding opens the other ways to add one.
        Menu {
          Button("Log a brew", systemImage: "plus") { router.open(.newBrew) }
          Button("Import a journal page", systemImage: "doc.text.viewfinder") {
            showImport = true
          }
          .accessibilityIdentifier("journal.import.menu")
        } label: {
          Image(systemName: "plus")
        } primaryAction: {
          router.open(.newBrew)
        }
        .accessibilityLabel("Log a brew")
        .accessibilityHint("Hold for more ways to add a brew")
        .accessibilityAction(named: "Import a journal page") { showImport = true }
        .accessibilityIdentifier("journal.add")
      }
    }
    .navigationTitle("Journal")
    .toolbar(removing: .title)
    .navigationBarTitleDisplayMode(.inline)
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the rows inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.journal")
    }
    .sheet(isPresented: $showImport) {
      PaperImportView(context: context) { showImport = false }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { commitPendingDelete() } else { loadUnsaved() }
    }
    .onAppear(perform: loadUnsaved)
    .onReceive(NotificationCenter.default.publisher(for: DraftStore.didChange)) { _ in
      loadUnsaved()
    }
    .onChange(of: brews.count) { _, _ in loadUnsaved() }
    .onDisappear { commitPendingDelete() }
  }

  private var header: some View { PageHeader("Journal") }

  // MARK: List

  private func list(_ shown: [Brew], logged: [Brew]) -> some View {
    List {
      header
        .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.sm)
        .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
      if let deleteError {
        StateBanner(kind: .error, message: deleteError, actionTitle: "Dismiss") {
          self.deleteError = nil
        }
        .accessibilityIdentifier("journal.error")
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
      }
      if let last = logged.first, TodayCard.applies(to: last) {
        TodayCard(brew: last) { router.open(.taste(last.id)) }
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
          .listRowInsets(EdgeInsets())
          .listRowBackground(DS.bg)
          .listRowSeparator(.hidden)
      }
      if DS.isBloom, let last = logged.first, !TodayCard.applies(to: last) {
        LastCupCard(
          brew: last, brewedDays: LastCupCard.brewedDays(logged),
          brewAgain: { brewAgain(last) }, quickLog: { router.open(.newBrew) }
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
        .listRowSeparator(.hidden)
      }
      if !shown.isEmpty {
        Text("Past Brews").font(.system(.title2, design: .serif, weight: .medium))
          .foregroundStyle(DS.ink).accessibilityAddTraits(.isHeader)
          .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.md)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
          .accessibilityIdentifier("journal.past")
      }
      ForEach(shown) { brew in
        NavigationLink(value: DeepLink.brew(brew.id)) {
          BrewRow(brew: brew, units: units)
        }
        // Each brew is its own soft card, spaced from the next, with no rule between. The
        // wider trailing inset keeps the row's chevron inside the card.
        .listRowInsets(
          EdgeInsets(
            top: DS.Space.xs, leading: DS.Space.lg, bottom: DS.Space.xs,
            trailing: DS.Space.lg + DS.Space.md)
        )
        .listRowBackground(
          RoundedRectangle(cornerRadius: max(DS.radius, 18), style: .continuous).fill(DS.paper)
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.xs)
        )
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
          Button {
            brewAgain(brew)
          } label: {
            Label("Brew again", systemImage: "arrow.counterclockwise")
          }
          .tint(DS.ink)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            delete(brew)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
        .contextMenu {
          Button {
            brewAgain(brew)
          } label: {
            Label("Brew again", systemImage: "arrow.counterclockwise")
          }
          Button {
            router.journalPath.append(.brew(brew.id))
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          Button(role: .destructive) {
            delete(brew)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
        .accessibilityAction(named: "Brew again") { brewAgain(brew) }
        .accessibilityAction(named: "Delete") { delete(brew) }
        .accessibilityIdentifier("journal.row.\(brew.id.uuidString)")
      }
      if !unsaved.isEmpty {
        unsavedHeader
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
      }
      ForEach(unsaved) { entry in
        Button {
          openUnsaved(entry)
        } label: {
          UnsavedBrewRow(entry: entry, methods: methods)
        }
        .buttonStyle(.plain)
        .listRowInsets(
          EdgeInsets(
            top: DS.Space.xs, leading: DS.Space.lg, bottom: DS.Space.xs,
            trailing: DS.Space.lg + DS.Space.md)
        )
        .listRowBackground(
          RoundedRectangle(cornerRadius: max(DS.radius, 18), style: .continuous).fill(DS.paper)
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.xs)
        )
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { discardButton(entry) }
        .contextMenu { discardButton(entry) }
        .accessibilityAction(named: "Discard") { discard(entry) }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, DS.Size.minTap)
  }

  // MARK: Filter bar

  /// One quiet Filter button instead of three pinned menus; it names how many
  /// filters are on so a filtered list never looks like missing brews.
  private func filterBar(_ active: JournalFilter, beanNames: [String]) -> some View {
    let count = (active.methodID == nil ? 0 : 1) + (active.beanName == nil ? 0 : 1)
    return HStack {
      Menu {
        Menu("Method") {
          Button("All methods") { methodFilter = "" }
          ForEach(methods.filter { !$0.isHidden || $0.id == active.methodID }) { method in
            Button {
              methodFilter = method.id.uuidString
            } label: {
              if method.id == active.methodID {
                Label(method.name, systemImage: "checkmark")
              } else {
                Text(method.name)
              }
            }
          }
        }
        .accessibilityIdentifier("journal.filter.method")
        if !beanNames.isEmpty {
          Menu("Bean") {
            Button("All beans") { beanFilter = "" }
            ForEach(beanNames, id: \.self) { name in
              Button {
                beanFilter = name
              } label: {
                if name == active.beanName {
                  Label(name, systemImage: "checkmark")
                } else {
                  Text(name)
                }
              }
            }
          }
          .accessibilityIdentifier("journal.filter.bean")
        }
        Picker("Order", selection: $sortChoice) {
          ForEach(JournalSort.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .accessibilityIdentifier("journal.filter.order")
        if count > 0 {
          Button("Clear filters", systemImage: "xmark.circle", action: clearFilters)
        }
      } label: {
        Label(
          count > 0 ? "Filter · \(count) on" : "Filter · \(active.sort.title)",
          systemImage: "line.3.horizontal.decrease"
        )
        .font(.subheadline.weight(.semibold)).foregroundStyle(count > 0 ? DS.ink : DS.ink2)
        .padding(.horizontal, DS.Space.md)
        .frame(minHeight: DS.Size.minTap)
        .overlay(Capsule().strokeBorder(DS.line, lineWidth: 1))
      }
      .accessibilityLabel("Filter")
      .accessibilityValue(count > 0 ? "\(count) on, \(active.sort.title)" : active.sort.title)
      .accessibilityIdentifier("journal.filter")
      Spacer()
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.xs)
    .background(DS.bg)
  }

  // MARK: Unsaved brews

  private var unsavedHeader: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Unsaved Brews").font(.system(.title2, design: .serif, weight: .medium))
        .foregroundStyle(DS.ink).accessibilityAddTraits(.isHeader)
      Text("Started or changed, but not saved yet. Tap one to finish it.")
        .font(.subheadline).foregroundStyle(DS.ink2)
    }
    .padding(.horizontal, DS.Space.lg).padding(.top, DS.Space.lg)
    .accessibilityIdentifier("journal.unsaved")
  }

  private func discardButton(_ entry: SavedDraft) -> some View {
    Button(role: .destructive) {
      discard(entry)
    } label: {
      Label("Discard", systemImage: "trash")
    }
  }

  /// Reads the draft files. A draft for a brew that is gone, or one that holds
  /// nothing new, is left out.
  private func loadUnsaved() {
    let store = Store(context: context)
    unsaved = DraftStore.all().filter { entry in
      switch entry.kind {
      case .newBrew:
        return BrewFormModel.hasChanges(entry.draft, editing: nil, repeating: nil, store: store)
      case .editing(let id):
        guard let brew = try? store.find(Brew.self, id: id) else { return false }
        return BrewFormModel.hasChanges(entry.draft, editing: brew, repeating: nil, store: store)
      case .repeating(let id):
        guard let source = try? store.find(Brew.self, id: id) else { return false }
        return BrewFormModel.hasChanges(entry.draft, editing: nil, repeating: source, store: store)
      }
    }
  }

  private func openUnsaved(_ entry: SavedDraft) {
    switch entry.kind {
    case .newBrew: router.open(.newBrew)
    case .editing(let id): router.journalPath.append(.brew(id))
    case .repeating(let id): router.journalPath.append(.brewAgain(id))
    }
  }

  private func discard(_ entry: SavedDraft) {
    _ = entry.store.clear()
    loadUnsaved()
  }

  private func brewAgain(_ brew: Brew) {
    router.journalPath.append(.brewAgain(brew.id))
  }

  private func clearFilters() {
    search = ""
    methodFilter = ""
    beanFilter = ""
  }

  // MARK: Delete with Undo

  @ViewBuilder private var toast: some View {
    if pendingDelete != nil {
      SteelToast(message: "Brew deleted", actionTitle: "Undo", action: undoDelete)
        .padding(.horizontal, DS.Space.lg).padding(.bottom, DS.Space.sm)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("journal.toast")
    }
  }

  private func delete(_ brew: Brew) {
    commitPendingDelete()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingDelete = brew.id }
    deleteTimer = Task {
      try? await Task.sleep(for: .seconds(Self.undoSeconds))
      guard !Task.isCancelled else { return }
      commitPendingDelete()
    }
  }

  private func undoDelete() {
    deleteTimer?.cancel()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingDelete = nil }
  }

  /// Removes the brew that was waiting out its Undo window. A write failure puts
  /// the brew back and says so, so nothing disappears without being deleted.
  private func commitPendingDelete() {
    deleteTimer?.cancel()
    guard let id = pendingDelete else { return }
    let store = Store(context: context)
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingDelete = nil }
    guard let brew = try? store.find(Brew.self, id: id) else { return }
    context.delete(brew)
    if case .failure(.saveFailed(let message)) = store.save() {
      context.rollback()
      deleteError = "The brew was not deleted. \(message)"
    }
  }
}

enum JournalStorage {
  static let methodKey = "journal.filter.method"
  static let beanKey = "journal.filter.bean"
  static let sortKey = "journal.sort"

  /// Forgets the remembered filter and order (UI tests start from a known list).
  static func reset(_ defaults: UserDefaults = .standard) {
    for key in [methodKey, beanKey, sortKey] { defaults.removeObject(forKey: key) }
  }
}

// MARK: Pieces

/// A bordered menu button that names what it filters and what is chosen.
struct FilterMenu<Content: View>: View {
  let title: String
  let value: String
  @ViewBuilder let content: Content

  var body: some View {
    Menu {
      content
    } label: {
      HStack(spacing: DS.Space.sm) {
        VStack(alignment: .leading, spacing: 0) {
          Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
          Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink).lineLimit(1)
        }
        Spacer(minLength: DS.Space.xs)
        Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold))
          .foregroundStyle(DS.ink).accessibilityHidden(true)
      }
      .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.xs)
      .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
      .glassEffect(
        .regular.tint(DS.paper.opacity(0.6)), in: RoundedRectangle(cornerRadius: DS.controlRadius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DS.controlRadius)
          .strokeBorder(DS.line, lineWidth: DS.isBloom ? 1 : DS.rule))
    }
    .accessibilityLabel(title)
    .accessibilityValue(value)
  }
}

/// A brew left without saving: what it is, whether it is new or an edit, and
/// when it was last changed.
private struct UnsavedBrewRow: View {
  let entry: SavedDraft
  let methods: [BrewMethod]

  private var method: String? { methods.first { $0.id == entry.draft.methodID }?.name }
  private var title: String { entry.draft.beans?.first?.name ?? method ?? "Brew" }

  private var status: String {
    switch entry.kind {
    case .newBrew: "New brew, not saved"
    case .editing: "Changes not saved"
    case .repeating: "Brew again, not saved"
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: DS.Space.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(status.uppercased()).font(DS.Font.label).foregroundStyle(DS.signal)
        Text(title).font(.system(.title3, design: .serif, weight: .medium))
          .foregroundStyle(DS.ink).lineLimit(2)
        Text(subtitle).font(.subheadline).foregroundStyle(DS.ink2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(DS.ink2).accessibilityHidden(true)
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens it so you can finish and save it")
  }

  /// "Last changed Oct 28, 3:29 PM · Cone dripper"
  private var subtitle: String {
    var text =
      "Last changed "
      + entry.changedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    if let method, method != title { text += " · \(method)" }
    return text
  }
}

/// One brew in the list: method and grade, when, the numbers, and a note preview.
/// One past brew, in the Today card's manner: the bean large, when and on what, the
/// rating on the right, then the numbers, the tastes and the notes with room to breathe.
private struct BrewRow: View {
  let brew: Brew
  let units: UnitPreferences

  private var title: String { brew.beanNames.first ?? brew.method?.name ?? "Brew" }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.md) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.system(.title3, design: .serif, weight: .medium))
            .foregroundStyle(DS.ink).lineLimit(2)
          Text(subtitle).font(.subheadline).foregroundStyle(DS.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let grade = brew.ratingTenths, grade > 0 {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(Rating.text(grade)).font(.system(.title2, design: .serif, weight: .semibold))
              .foregroundStyle(DS.ink)
            Text("/10").font(.footnote).foregroundStyle(DS.ink2)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Rated \(Rating.text(grade)) of 10")
        }
      }
      if !stats.isEmpty {
        HStack(alignment: .top, spacing: DS.Space.lg) {
          ForEach(stats, id: \.name) { stat in
            VStack(alignment: .leading, spacing: 2) {
              Text(stat.value).font(DS.Font.mono(.subheadline)).foregroundStyle(DS.ink)
              Text(stat.name).font(.caption).foregroundStyle(DS.ink2)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
      if !tags.isEmpty {
        HStack(spacing: DS.Space.xs) {
          ForEach(tags, id: \.self) { tag in
            Text(tag).font(.caption.weight(.semibold)).foregroundStyle(DS.ink)
              .padding(.horizontal, DS.Space.sm).padding(.vertical, 4)
              .background(DS.ink.opacity(0.06), in: Capsule())
          }
        }
      }
      if !brew.notes.isEmpty {
        Text(brew.notes).font(.footnote).foregroundStyle(DS.ink).lineLimit(2)
      }
      if let dialIn {
        Text(dialIn).font(.footnote.weight(.medium)).foregroundStyle(DS.signal)
          .accessibilityIdentifier("journal.row.dialin")
      }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  /// "Oct 27, 8:12 AM · Cone dripper", and the other beans of a blend.
  private var subtitle: String {
    var text = brew.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    if let method = brew.method?.name, method != title { text += " · \(method)" }
    let others = brew.beanNames.dropFirst()
    if !others.isEmpty { text += " · with " + others.joined(separator: ", ") }
    return text
  }

  private var stats: [(name: String, value: String)] {
    var stats: [(name: String, value: String)] = []
    if let dose = brew.doseG, let water = brew.waterG {
      stats.append(
        (
          "dose : water",
          "\(RecipeFormat.weight(dose, units)) : \(RecipeFormat.weight(water, units))"
        ))
    }
    if let ratio = BrewMath.ratioLabel(BrewMath.ratio(doseG: brew.doseG, waterG: brew.waterG)) {
      stats.append(("ratio", ratio))
    }
    if let seconds = brew.totalTimeS { stats.append(("time", RecipeFormat.clock(seconds))) }
    return stats
  }

  /// The tastes picked and the grind, as small tags.
  private var tags: [String] {
    var tags = brew.verdicts.map(\.rawValue.capitalized)
    if let grind = brew.grindSetting { tags.append("Grind \(grind)") }
    return tags
  }

  /// The suggestion this cup produced and the one it followed (X4).
  private var dialIn: String? {
    var parts: [String] = []
    if let made = (brew.suggestionsMade ?? []).max(by: { $0.createdAt < $1.createdAt }) {
      parts.append(
        "Next: \(SuggestionFormat.headline(made, units)) (\(SuggestionFormat.title(made.state).lowercased()))"
      )
    }
    if let followed = brew.suggestionFollowed {
      parts.append("Followed: \(SuggestionFormat.headline(followed, units))")
    }
    return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
  }
}
