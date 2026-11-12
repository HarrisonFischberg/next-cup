import NextCupKit
import SwiftData
import SwiftUI

/// The Explore tab: coffee beyond the bags on the shelf. Roasters near you and in the catalog,
/// and a flavor explorer of the beans you have. Brewing a bean, and the AI's help with it, live
/// on the bean's own page in Beans.
struct ExploreView: View {
  @State private var taxonomy = ExploreModel.taxonomy
  @State private var showsRoasters = false

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
        moreSections
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("Explore")
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showsRoasters) { RoasterDiscoveryView { showsRoasters = false } }
    .accessibilityIdentifier("explore.list")
    // A marker, not an identifier on the list: that would replace the
    // identifiers of the rows inside it.
    .background {
      Color.clear.accessibilityElement().accessibilityIdentifier("tab.root.explore")
    }
  }

  /// Roasters and flavors as labeled sections under the recommendations, not
  /// icon-only toolbar buttons.
  @ViewBuilder private var moreSections: some View {
    SavedRoasters()
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("ROASTERS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      PaperBox {
        VStack(spacing: 0) {
          if let catalog = RoasterCatalog.shared {
            NavigationLink {
              RoasterCatalogView(catalog: catalog)
            } label: {
              sectionRow("Roaster catalog", "Coffees with starter recipes", "storefront")
            }
            .accessibilityIdentifier("explore.catalog")
            Hairline()
          }
          Button {
            showsRoasters = true
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
