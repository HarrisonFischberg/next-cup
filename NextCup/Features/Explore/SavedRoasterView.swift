import NextCupKit
import SwiftData
import SwiftUI

/// What the user has from one roaster: how many beans and brews, and how they rated.
struct RoasterStats: Equatable {
  let beans: Int
  let brews: Int
  /// Average rating of the rated brews, in tenths out of 10. Nil when none is rated.
  let averageTenths: Int?

  init(beans: [Bean]) {
    self.beans = beans.count
    var seen = Set<UUID>()
    let brews = beans.flatMap { $0.brewUses ?? [] }.compactMap(\.brew)
      .filter { seen.insert($0.id).inserted }
    self.brews = brews.count
    let ratings = brews.compactMap(\.ratingTenths).filter { $0 > 0 }
    averageTenths =
      ratings.isEmpty
      ? nil : Int((Double(ratings.reduce(0, +)) / Double(ratings.count)).rounded())
  }
}

/// A saved roaster's own page: the user's beans and brews from it, a way to add
/// another bean with the roaster filled in, and how to get there.
struct SavedRoasterView: View {
  let roaster: Roaster

  @Environment(\.openURL) private var openURL
  @State private var addingBean = false

  private var beans: [Bean] { (roaster.beans ?? []).sorted { $0.name < $1.name } }
  private var place: RoasterPlace? { RoasterPlace(roaster) }
  private var catalogRoaster: RoasterCatalog.Roaster? {
    RoasterCatalog.shared?.roaster(matching: roaster.name)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
          Text(roaster.name.dsTitle).font(DS.Font.din(30, relativeTo: .title))
            .foregroundStyle(DS.ink)
            .accessibilityAddTraits(.isHeader)
          if let city = roaster.city {
            Text(city).font(.callout).foregroundStyle(DS.ink2)
          }
        }
        stats
        beanList
        SteelButton(title: "Add a bean from this roaster", kind: .secondary) {
          addingBean = true
        }
        .accessibilityIdentifier("savedroaster.addBean")
        links
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("Roaster")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $addingBean) {
      BeanEditorView(target: .new, prefill: prefill) { addingBean = false }
    }
    .accessibilityIdentifier("savedroaster.screen")
  }

  private var prefill: BeanFields {
    var fields = BeanFields()
    fields.roasterName = roaster.name
    fields.roasterCity = roaster.city ?? ""
    fields.roasterWebsite = roaster.website
    return fields
  }

  private var stats: some View {
    let stats = RoasterStats(beans: beans)
    return PaperBox {
      HStack(spacing: 0) {
        SpecCell(label: "Beans", value: "\(stats.beans)")
        SpecCell(label: "Brews", value: "\(stats.brews)")
        SpecCell(
          label: "Avg rating", value: stats.averageTenths.map { Rating.text($0) } ?? "–"
        )
        .accessibilityLabel(
          stats.averageTenths.map { "Average rating \(Rating.text($0)) out of 10" }
            ?? "No rated brews yet")
      }
    }
    .accessibilityIdentifier("savedroaster.stats")
  }

  @ViewBuilder private var beanList: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("YOUR BEANS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      if beans.isEmpty {
        Text("No beans from this roaster yet. Add one and its brews show up here.")
          .font(.callout).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("savedroaster.noBeans")
      } else {
        PaperBox {
          VStack(spacing: 0) {
            ForEach(beans) { bean in
              NavigationLink(value: DeepLink.bean(bean.id)) {
                HStack(spacing: DS.Space.md) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(bean.name).font(DS.Font.headline).foregroundStyle(DS.ink)
                    let count = bean.brewUses?.count ?? 0
                    Text(count == 1 ? "1 brew" : "\(count) brews").font(.footnote)
                      .foregroundStyle(DS.ink2)
                  }
                  Spacer(minLength: DS.Space.sm)
                  Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.ink2).accessibilityHidden(true)
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
                .contentShape(Rectangle())
              }
              .accessibilityElement(children: .combine)
              .accessibilityIdentifier("savedroaster.bean.\(bean.name)")
              if bean.id != beans.last?.id { Hairline() }
            }
          }
        }
        .buttonStyle(PressableStyle())
      }
    }
  }

  private var links: some View {
    PaperBox {
      VStack(spacing: 0) {
        if let catalogRoaster {
          NavigationLink {
            CatalogRoasterView(
              roaster: catalogRoaster, checkedOn: RoasterCatalog.shared?.checkedOn ?? "")
          } label: {
            RoasterRowLabel(
              title: "Coffees and starter recipes",
              detail: "\(catalogRoaster.coffees.count) in the Next Cup catalog",
              symbol: "storefront")
          }
          .accessibilityIdentifier("savedroaster.catalog")
          Hairline()
        }
        if let url = place?.directionsURL {
          Button {
            openURL(url)
          } label: {
            RoasterRowLabel(title: "Directions", detail: "Opens Apple Maps", symbol: "map")
          }
          .accessibilityIdentifier("savedroaster.directions")
          Hairline()
        }
        if let website = roaster.website {
          Button {
            openURL(website)
          } label: {
            RoasterRowLabel(
              title: "Website", detail: website.host() ?? website.absoluteString,
              symbol: "safari")
          }
          .accessibilityIdentifier("savedroaster.website")
          Hairline()
        }
        if let url = place?.googleMapsURL {
          Button {
            openURL(url)
          } label: {
            RoasterRowLabel(
              title: "Open in Google Maps", detail: "The app, or your browser",
              symbol: "arrow.up.right.square")
          }
          .accessibilityIdentifier("savedroaster.google")
        }
      }
    }
    .buttonStyle(PressableStyle())
  }
}

/// One tappable line on a roaster's page: a symbol, a title and what it opens.
struct RoasterRowLabel: View {
  let title: String
  let detail: String
  let symbol: String

  var body: some View {
    HStack(spacing: DS.Space.md) {
      Image(systemName: symbol).foregroundStyle(DS.ink2).frame(width: 24)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(detail).font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
