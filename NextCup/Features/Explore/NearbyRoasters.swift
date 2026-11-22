import MapKit
import SwiftData
import SwiftUI

/// The top of Explore once location is allowed: a strip of map and the three closest
/// roasters. Nothing shows before location is allowed, or when the search finds none
/// or fails; "Find roasters near me" below still opens the full map.
struct NearbyRoasters: View {
  let model: RoasterDiscoveryModel
  let seeAll: () -> Void

  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<Roaster> { $0.savedFromMap }, sort: \Roaster.name)
  private var saved: [Roaster]
  @State private var detail: RoasterPlace?

  private var service: RoasterService { RoasterService(store: Store(context: context)) }
  private var closest: [RoasterPlace] { Array(model.places.prefix(3)) }

  var body: some View {
    if model.opensOnMap, model.isBusy || (model.phase == .results && !closest.isEmpty) {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("NEAR YOU").font(DS.Font.label).foregroundStyle(DS.ink2)
          .accessibilityAddTraits(.isHeader)
        if model.isBusy {
          PaperBox {
            VStack(spacing: 0) { ForEach(0..<3, id: \.self) { _ in SkeletonRow() } }
          }
          .accessibilityLabel("Finding roasters near you")
        } else {
          results
        }
      }
      .navigationDestination(item: $detail) { place in
        RoasterPlaceDetailView(place: place, isSaved: service.isSaved(place, in: saved)) {
          if case .success = service.toggle(place, in: saved) { Feedback.tap() }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("explore.nearby")
    }
  }

  private var results: some View {
    PaperBox {
      VStack(spacing: 0) {
        if let region = RoasterMap.region(fitting: closest, around: model.origin) {
          Button(action: seeAll) {
            Map(initialPosition: .region(region), interactionModes: []) {
              ForEach(closest) { place in
                Marker(
                  place.name,
                  coordinate: CLLocationCoordinate2D(
                    latitude: place.latitude, longitude: place.longitude))
              }
            }
            .frame(height: 150)
            .allowsHitTesting(false)
          }
          .accessibilityLabel("Map of roasters near you")
          .accessibilityHint("Opens the full map")
          .accessibilityIdentifier("explore.nearby.map")
          Hairline()
        }
        ForEach(closest) { place in
          Button {
            detail = place
          } label: {
            HStack(spacing: DS.Space.md) {
              VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(DS.Font.headline).foregroundStyle(DS.ink)
                let line = [place.city, model.distanceText(to: place)].compactMap { $0 }
                  .joined(separator: "  ·  ")
                if !line.isEmpty { Text(line).font(.footnote).foregroundStyle(DS.ink2) }
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
          .accessibilityIdentifier("explore.nearby.\(place.name)")
          Hairline()
        }
        Button(action: seeAll) {
          Text(
            model.places.count > closest.count
              ? "See all \(model.places.count) on the map" : "See them on the map"
          )
          .font(DS.Font.label).foregroundStyle(DS.ink)
          .padding(DS.Space.md)
          .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
          .contentShape(Rectangle())
        }
        .accessibilityIdentifier("explore.nearby.all")
      }
    }
    .buttonStyle(PressableStyle())
  }
}

/// What Explore's search box found: catalog roasters and coffees, saved roasters, and
/// always a way to look for the same words on the map.
struct ExploreSearchResults: View {
  let query: String
  let searchMap: () -> Void

  @Query(filter: #Predicate<Roaster> { $0.savedFromMap }, sort: \Roaster.name)
  private var saved: [Roaster]

  var body: some View {
    let found = RoasterCatalog.shared?.search(query) ?? (roasters: [], coffees: [])
    let mine = saved.filter {
      $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
    let checkedOn = RoasterCatalog.shared?.checkedOn ?? ""
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      if !found.roasters.isEmpty || !mine.isEmpty {
        section("ROASTERS") {
          ForEach(mine) { roaster in
            NavigationLink {
              SavedRoasterView(roaster: roaster)
            } label: {
              RoasterRowLabel(
                title: roaster.name, detail: "Saved" + (roaster.city.map { "  ·  \($0)" } ?? ""),
                symbol: "mappin.and.ellipse")
            }
            Hairline()
          }
          ForEach(found.roasters) { roaster in
            NavigationLink {
              CatalogRoasterView(roaster: roaster, checkedOn: checkedOn)
            } label: {
              RoasterRowLabel(
                title: roaster.name,
                detail: "\(roaster.place)  ·  \(roaster.coffees.count) coffees",
                symbol: "storefront")
            }
            .accessibilityIdentifier("explore.search.roaster.\(roaster.key)")
            Hairline()
          }
        }
      }
      if !found.coffees.isEmpty {
        section("COFFEES") {
          ForEach(found.coffees) { listing in
            NavigationLink {
              CatalogCoffeeView(coffee: listing.coffee, roaster: listing.roaster)
            } label: {
              RoasterRowLabel(
                title: listing.coffee.name,
                detail: [listing.roaster.name, CatalogText.facts(listing.coffee)]
                  .filter { !$0.isEmpty }.joined(separator: "  ·  "),
                symbol: "leaf")
            }
            .accessibilityIdentifier("explore.search.coffee.\(listing.coffee.key)")
            Hairline()
          }
        }
      }
      if found.roasters.isEmpty && found.coffees.isEmpty && mine.isEmpty {
        Text("Nothing in the catalog or your saved roasters matches. Try the map.")
          .font(.callout).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("explore.search.none")
      }
      PaperBox {
        Button(action: searchMap) {
          RoasterRowLabel(
            title: "Search the map for “\(query)”", detail: "A city or a roaster's name",
            symbol: "map")
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("explore.search.map")
      }
    }
  }

  private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text(title).font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      PaperBox { VStack(spacing: 0) { rows() } }
        .buttonStyle(PressableStyle())
    }
  }
}
