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
  @Environment(\.dynamicTypeSize) private var dts
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query(sort: \Brew.date, order: .reverse) private var brews: [Brew]
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var search = ""
  @State private var pendingDelete: UUID?
  @State private var deleteTimer: Task<Void, Never>?
  @State private var deleteError: String?
  @State private var showImport = false
  @AppStorage(JournalStorage.methodKey) private var methodFilter = ""
  @AppStorage(JournalStorage.beanKey) private var beanFilter = ""
  @AppStorage(JournalStorage.sortKey) private var sortChoice = JournalSort.newest.rawValue
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
  private var logged: [Brew] { brews.filter { !$0.isDraft && $0.id != pendingDelete } }

  private var beanNames: [String] { Set(logged.flatMap(\.beanNames)).sorted() }

  /// A remembered method or bean that no longer exists is ignored, so an old
  /// choice can never leave the journal looking empty.
  private var filter: JournalFilter {
    let methodID = UUID(uuidString: methodFilter)
    return JournalFilter(
      search: search,
      methodID: methods.contains { $0.id == methodID } ? methodID : nil,
      beanName: beanNames.contains(beanFilter) ? beanFilter : nil,
      sort: JournalSort(rawValue: sortChoice) ?? .newest)
  }

  var body: some View {
    let shown = filter.apply(to: logged)
    Group {
      if logged.isEmpty {
        ScrollView {
          EmptyState(
            title: "No brews yet",
            message: "Log a brew and it will be listed here, newest first.",
            actionTitle: "Log a brew", action: { router.open(.newBrew) })
        }
      } else if shown.isEmpty {
        ScrollView {
          EmptyState(
            title: "No matches", message: "No brew matches. Try fewer words or clear the filters.",
            actionTitle: "Clear filters", action: clearFilters)
        }
      } else {
        list(shown)
      }
    }
    .background(DS.bg)
    .searchable(text: $search, prompt: "Search brews")
    .safeAreaInset(edge: .top, spacing: 0) { if !logged.isEmpty { filterBar } }
    .safeAreaInset(edge: .bottom, spacing: 0) { toast }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          showImport = true
        } label: {
          Image(systemName: "doc.text.viewfinder")
        }
        .accessibilityLabel("Import a journal page")
        .accessibilityIdentifier("journal.import")
      }
      if !logged.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          Button {
            router.open(.newBrew)
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Log a brew")
        }
      }
    }
    .navigationTitle("Journal")
    .navigationBarTitleDisplayMode(.inline)
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the rows inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.journal")
    }
    .sheet(isPresented: $showImport) {
      PaperImportView(context: context) { showImport = false }
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { commitPendingDelete() } }
    .onDisappear { commitPendingDelete() }
  }

  // MARK: List

  private func list(_ shown: [Brew]) -> some View {
    List {
      if let deleteError {
        StateBanner(kind: .error, message: deleteError, actionTitle: "Dismiss") {
          self.deleteError = nil
        }
        .accessibilityIdentifier("journal.error")
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
      }
      ForEach(shown) { brew in
        NavigationLink(value: DeepLink.brew(brew.id)) {
          BrewRow(brew: brew, units: units)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.paper)
        .listRowSeparatorTint(DS.line)
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
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, DS.Size.minTap)
  }

  // MARK: Filter bar

  private var filterBar: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(spacing: DS.Space.sm))
    let active = filter
    return layout {
      FilterMenu(
        title: "Method",
        value: methods.first { $0.id == active.methodID }?.name ?? "All"
      ) {
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
        FilterMenu(title: "Bean", value: active.beanName ?? "All") {
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
      FilterMenu(title: "Order", value: active.sort.title) {
        Picker("Order", selection: $sortChoice) {
          ForEach(JournalSort.allCases) { Text($0.title).tag($0.rawValue) }
        }
      }
      .accessibilityIdentifier("journal.filter.order")
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.bg)
    .overlay(alignment: .bottom) { Hairline() }
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
      .background(DS.paper, ignoresSafeAreaEdges: [])
      .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
    }
    .accessibilityLabel(title)
    .accessibilityValue(value)
  }
}

/// One brew in the list: method and grade, when, the numbers, and a note preview.
private struct BrewRow: View {
  let brew: Brew
  let units: UnitPreferences

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
        Text((brew.method?.name ?? "Brew").uppercased()).font(DS.Font.headline)
          .foregroundStyle(DS.ink)
        Spacer(minLength: DS.Space.sm)
        if let grade = brew.ratingHalfSteps, grade > 0 { GradeBadge(halfSteps: grade) }
      }
      Text(brew.date.formatted(date: .abbreviated, time: .shortened))
        .font(.footnote).foregroundStyle(DS.ink2)
      if let numbers {
        Text(numbers).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
      }
      if let detail {
        Text(detail).font(.footnote).foregroundStyle(DS.ink2)
      }
      if !brew.notes.isEmpty {
        Text(brew.notes).font(.footnote).foregroundStyle(DS.ink).lineLimit(2)
      }
      if let dialIn {
        Text(dialIn).font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("journal.row.dialin")
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var numbers: String? {
    var parts: [String] = []
    if let dose = brew.doseG, let water = brew.waterG {
      parts.append("\(RecipeFormat.weight(dose, units)) : \(RecipeFormat.weight(water, units))")
    }
    if let ratio = BrewMath.ratioLabel(BrewMath.ratio(doseG: brew.doseG, waterG: brew.waterG)) {
      parts.append(ratio)
    }
    if let seconds = brew.totalTimeS { parts.append(RecipeFormat.clock(seconds)) }
    return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
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

  private var detail: String? {
    var parts = brew.beanNames
    if let verdict = brew.verdict { parts.append(verdict.rawValue.capitalized) }
    if let grind = brew.grindSetting { parts.append("Grind \(grind)") }
    return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
  }
}
