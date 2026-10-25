import NextCupKit
import SwiftData
import SwiftUI
import UIKit

/// S03: the bean library. Searchable, filtered by status (All, In use, Buy again,
/// Wishlist, Finished) and sortable, with the status and order remembered. Delete
/// is a swipe, the row's menu or a VoiceOver action, followed by an Undo toast;
/// the bean is only removed once the toast times out or the screen is left.
struct BeanLibraryView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dts
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
  @State private var search = ""
  @State private var editor: BeanEditorTarget?
  @State private var showsRoasters = false
  @State private var pendingDelete: UUID?
  @State private var deleteTimer: Task<Void, Never>?
  @State private var error: String?
  @AppStorage(BeanStorage.statusKey) private var statusChoice = BeanStatusFilter.all.rawValue
  @AppStorage(BeanStorage.sortKey) private var sortChoice = BeanSort.recent.rawValue
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  private static let undoSeconds = 6

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var service: BeanService { BeanService(store: Store(context: context)) }

  /// Every bean except the one waiting out its Undo window.
  private var library: [Bean] { beans.filter { $0.id != pendingDelete } }

  private var filter: BeanFilter {
    BeanFilter(
      search: search, status: BeanStatusFilter(rawValue: statusChoice) ?? .all,
      sort: BeanSort(rawValue: sortChoice) ?? .recent)
  }

  var body: some View {
    let shown = filter.apply(to: library)
    Group {
      if library.isEmpty {
        ScrollView {
          EmptyState(
            title: "No beans yet",
            message: "Add a bag to track its freshness and how much is left.",
            actionTitle: "Add a bean", action: { editor = .new })
        }
      } else if shown.isEmpty {
        ScrollView {
          EmptyState(
            title: "No matches", message: "No bean matches. Try fewer words or clear the filters.",
            actionTitle: "Clear filters", action: clearFilters)
        }
      } else {
        list(shown)
      }
    }
    .background(DS.bg)
    .searchable(text: $search, prompt: "Search beans")
    .safeAreaInset(edge: .top, spacing: 0) { if !library.isEmpty { filterBar } }
    .safeAreaInset(edge: .bottom, spacing: 0) { toast }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          showsRoasters = true
        } label: {
          Image(systemName: "map")
        }
        .accessibilityLabel("Find roasters")
        .accessibilityIdentifier("beans.roasters")
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          editor = .new
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add a bean")
        .accessibilityIdentifier("beans.add")
      }
    }
    .sheet(item: $editor) { target in
      BeanEditorView(target: target) { editor = nil }
    }
    .sheet(isPresented: $showsRoasters) {
      RoasterDiscoveryView { showsRoasters = false }
    }
    .navigationTitle("Beans")
    .navigationBarTitleDisplayMode(.inline)
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the rows inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.beans")
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { commitPendingDelete() } }
    .onDisappear { commitPendingDelete() }
  }

  // MARK: List

  private func list(_ shown: [Bean]) -> some View {
    List {
      if let error {
        StateBanner(kind: .error, message: error, actionTitle: "Dismiss") { self.error = nil }
          .accessibilityIdentifier("beans.error")
          .listRowInsets(EdgeInsets())
          .listRowBackground(DS.bg)
      }
      ForEach(shown) { bean in
        NavigationLink(value: DeepLink.bean(bean.id)) {
          BeanRow(bean: bean, units: units)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.paper)
        .listRowSeparatorTint(DS.line)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
          let finished = bean.status == .finished
          Button {
            set(bean, finished ? .inUse : .finished)
          } label: {
            Label(
              finished ? "Back in use" : "Finished",
              systemImage: finished ? "arrow.uturn.backward" : "checkmark")
          }
          .tint(DS.steel)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            delete(bean)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
        .contextMenu {
          Button {
            editor = .edit(bean.id)
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          Menu {
            ForEach(BeanStatus.allCases, id: \.self) { status in
              Button(status.title) { set(bean, status) }
            }
          } label: {
            Label("Move to", systemImage: "tray")
          }
          Button(role: .destructive) {
            delete(bean)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
        .accessibilityAction(named: "Edit") { editor = .edit(bean.id) }
        .accessibilityAction(named: bean.status == .finished ? "Back in use" : "Mark finished") {
          set(bean, bean.status == .finished ? .inUse : .finished)
        }
        .accessibilityAction(named: "Delete") { delete(bean) }
        .accessibilityIdentifier("beans.row.\(bean.name)")
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, DS.Size.minTap)
    .accessibilityIdentifier("beans.list")
  }

  // MARK: Filter bar

  private var filterBar: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(spacing: DS.Space.sm))
    let active = filter
    return layout {
      FilterMenu(title: "Status", value: active.status.title) {
        Picker("Status", selection: $statusChoice) {
          ForEach(BeanStatusFilter.allCases) { Text($0.title).tag($0.rawValue) }
        }
      }
      .accessibilityIdentifier("beans.filter.status")
      FilterMenu(title: "Order", value: active.sort.title) {
        Picker("Order", selection: $sortChoice) {
          ForEach(BeanSort.allCases) { Text($0.title).tag($0.rawValue) }
        }
      }
      .accessibilityIdentifier("beans.filter.order")
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.bg)
    .overlay(alignment: .bottom) { Hairline() }
  }

  private func clearFilters() {
    search = ""
    statusChoice = BeanStatusFilter.all.rawValue
  }

  private func set(_ bean: Bean, _ status: BeanStatus) {
    switch service.setStatus(bean, status) {
    case .success:
      error = nil
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .failure(let failure):
      error = failure.message
    }
  }

  // MARK: Delete with Undo

  @ViewBuilder private var toast: some View {
    if pendingDelete != nil {
      SteelToast(message: "Bean deleted", actionTitle: "Undo", action: undoDelete)
        .padding(.horizontal, DS.Space.lg).padding(.bottom, DS.Space.sm)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("beans.toast")
    }
  }

  private func delete(_ bean: Bean) {
    commitPendingDelete()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingDelete = bean.id }
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

  /// Removes the bean that was waiting out its Undo window. A write failure puts
  /// the bean back and says so, so nothing disappears without being deleted.
  private func commitPendingDelete() {
    deleteTimer?.cancel()
    guard let id = pendingDelete else { return }
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingDelete = nil }
    guard let bean = try? Store(context: context).find(Bean.self, id: id) else { return }
    if case .failure(let failure) = service.delete(bean) {
      error = "The bean was not deleted. \(failure.message)"
    }
  }
}

enum BeanStorage {
  static let statusKey = "beans.filter.status"
  static let sortKey = "beans.sort"

  /// Forgets the remembered status and order (UI tests start from a known list).
  static func reset(_ defaults: UserDefaults = .standard) {
    for key in [statusKey, sortKey] { defaults.removeObject(forKey: key) }
  }
}

// MARK: Pieces

/// One bean in the list: name, roaster and origin, freshness, and what is left.
private struct BeanRow: View {
  let bean: Bean
  let units: UnitPreferences

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
        Text(bean.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
        if bean.isDecaf { Tag(text: "Decaf") }
        Spacer(minLength: DS.Space.sm)
        if let grade = bean.ratingHalfSteps, grade > 0 { GradeBadge(halfSteps: grade) }
      }
      if !bean.subtitle.isEmpty {
        Text(bean.subtitle).font(.footnote).foregroundStyle(DS.ink2)
      }
      Text(BeanText.freshnessLine(bean)).font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
      HStack(spacing: DS.Space.sm) {
        Text(BeanText.stockLine(bean, units: units)).font(DS.Font.mono(.footnote))
          .foregroundStyle(
            bean.stockLevel == .low || bean.stockLevel == .empty ? DS.error : DS.ink2)
        if bean.status != .inUse { Tag(text: bean.status.title) }
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// A small outlined word: a status or a flag. Text, never color alone.
struct Tag: View {
  let text: String

  var body: some View {
    Text(text.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
      .padding(.horizontal, DS.Space.sm).padding(.vertical, 2)
      .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
      .fixedSize()
  }
}

/// Words for freshness and stock, shared by the list and the detail.
enum BeanText {
  static func freshnessLine(_ bean: Bean, today: Date = Date()) -> String {
    let state = bean.freshness(today: today)
    guard let age = bean.ageDays(today: today), state != .unknown else { return state.title }
    return "\(state.title)  ·  day \(age)"
  }

  static func stockLine(_ bean: Bean, units: UnitPreferences) -> String {
    guard let left = bean.remainingG else { return "Amount not tracked" }
    switch bean.stockLevel {
    case .empty: return "Empty"
    case .low: return "Low: \(RecipeFormat.weight(left, units)) left"
    default: return "\(RecipeFormat.weight(left, units)) left"
    }
  }
}
