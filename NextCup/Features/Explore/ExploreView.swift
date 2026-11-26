import NextCupKit
import SwiftData
import SwiftUI

/// The Explore tab: coffee beyond the bags on the shelf. Roasters near you and in the catalog,
/// one search box across both, and a flavor explorer of the beans you have. Brewing a bean, and the AI's help with it, live
/// on the bean's own page in Beans.
struct ExploreView: View {
  @State private var taxonomy = ExploreModel.taxonomy
  /// The roaster finder sheet, with the words to look for on the map when it was opened
  /// from the search box.
  @State private var finder: RoasterFinder?
  /// Finds the roasters at the top of Explore, once location is allowed.
  @State private var nearby = RoasterDiscoveryModel.live()
  @State private var query = ""
  @State private var catalogRoaster: RoasterCatalog.Roaster?
  @FocusState private var searching: Bool

  private var typed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        PageHeader(title: "Explore") { SettingsGear(id: "explore.settings", large: true) }
        if taxonomy == nil {
          StateBanner(
            kind: .error,
            message:
              "The flavor vocabulary could not be read, so the flavor explorer is unavailable.",
            actionTitle: "Try again", action: { taxonomy = try? Taxonomy(bundle: .main) }
          )
          .accessibilityIdentifier("explore.error")
        }
        searchBox
        if typed.isEmpty {
          moreSections
        } else {
          ExploreSearchResults(query: typed) {
            searching = false
            finder = RoasterFinder(query: typed)
          }
        }
      }
      .padding(DS.Space.lg)
    }
    .scrollDismissesKeyboard(.immediately)
    .background(DS.bg)
    .navigationTitle("Explore")
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $finder) { finder in
      RoasterDiscoveryView(
        initialQuery: finder.query,
        openCatalog: { roaster in
          self.finder = nil
          catalogRoaster = roaster
        }
      ) { self.finder = nil }
    }
    .navigationDestination(item: $catalogRoaster) { roaster in
      CatalogRoasterView(roaster: roaster, checkedOn: RoasterCatalog.shared?.checkedOn ?? "")
    }
    .task { await nearby.start() }
    .accessibilityIdentifier("explore.list")
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the rows inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.explore")
    }
  }

  /// Roasters and flavors as labeled sections under the recommendations, not
  /// icon-only toolbar buttons.
  private var searchBox: some View {
    HStack(spacing: DS.Space.sm) {
      Image(systemName: "magnifyingglass").foregroundStyle(DS.ink2).accessibilityHidden(true)
      TextField("Search roasters and coffees", text: $query)
        .focused($searching)
        .submitLabel(.search)
        .autocorrectionDisabled()
        .accessibilityIdentifier("explore.search")
      if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(DS.ink2)
            .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
        }
        .accessibilityLabel("Clear search")
        .accessibilityIdentifier("explore.search.clear")
      }
    }
    .padding(.horizontal, DS.Space.md)
    .frame(minHeight: DS.Size.control)
    .panel(DS.paper)
  }

  @ViewBuilder private var moreSections: some View {
    NearbyRoasters(model: nearby) { finder = RoasterFinder() }
    SavedRoasters()
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("ROASTERS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        VStack(spacing: 0) {
          if let catalog = RoasterCatalog.shared {
            NavigationLink {
              RoasterCatalogView(catalog: catalog, nearKeys: catalog.roasters(near: nearby.places))
            } label: {
              sectionRow("Roaster catalog", "Coffees with starter recipes", "storefront")
            }
            .accessibilityIdentifier("explore.catalog")
            Hairline()
          }
          Button {
            finder = RoasterFinder()
          } label: {
            sectionRow("Find roasters near me", "Search the map while you use the app", "map")
          }
          .accessibilityIdentifier("explore.roasters")
        }
      }
      .buttonStyle(PressableStyle())
    }
    if let taxonomy {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("FLAVORS").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        PaperBox {
          NavigationLink {
            FlavorExplorerView(taxonomy: taxonomy)
          } label: {
            sectionRow("Flavor explorer", "The flavors, origins and roasts of your beans", "book")
          }
          .buttonStyle(PressableStyle())
          .accessibilityIdentifier("explore.flavors")
        }
      }
    }
  }

  private func sectionRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
    HStack(spacing: DS.Space.md) {
      Image(systemName: symbol).foregroundStyle(DS.ink2).frame(width: 24).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(detail).font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(DS.ink2).accessibilityHidden(true)
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// One opening of the roaster finder.
private struct RoasterFinder: Identifiable {
  let id = UUID()
  var query: String?
}
