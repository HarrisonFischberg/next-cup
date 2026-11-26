import MapKit
import SwiftUI

/// One roaster from the map: where it is and how to reach it, without leaving the app.
/// Calling, directions, the website and Google Maps open only when tapped, and each link
/// carries the roaster's details, never the user's location.
struct RoasterPlaceDetailView: View {
  let place: RoasterPlace
  let isSaved: Bool
  /// Opens the roaster's catalog page. Nil where the catalog page is pushed in place.
  var openCatalog: ((RoasterCatalog.Roaster) -> Void)?
  let toggleSaved: () -> Void

  @Environment(\.openURL) private var openURL
  @State private var placeCard: MKMapItem?
  @State private var loadingCard = false
  @State private var cardNotice: String?

  private var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
          Text(place.name.dsTitle).font(DS.Font.din(30, relativeTo: .title))
            .foregroundStyle(DS.ink)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("roasterdetail.name")
          if let line = place.address ?? place.city {
            Text(line).font(.callout).foregroundStyle(DS.ink2)
              .textSelection(.enabled)
              .accessibilityIdentifier("roasterdetail.address")
          }
        }
        Map(
          initialPosition: .region(
            MKCoordinateRegion(
              center: coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200)),
          interactionModes: []
        ) {
          Marker(place.name, coordinate: coordinate)
        }
        .frame(height: 180)
        .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        .accessibilityHidden(true)

        SteelButton(title: "Directions") { open(place.directionsURL) }
          .accessibilityHint("Opens Apple Maps")
          .accessibilityIdentifier("roasterdetail.directions")
        if let call = place.callURL {
          SteelButton(title: "Call", kind: .secondary) { openURL(call) }
            .accessibilityIdentifier("roasterdetail.call")
        }

        details
        if let cardNotice {
          StateBanner(kind: .info, message: cardNotice)
            .accessibilityIdentifier("roasterdetail.cardNotice")
        }

        SteelButton(title: isSaved ? "Saved" : "Save roaster", kind: .secondary) {
          toggleSaved()
        }
        .accessibilityLabel(isSaved ? "Remove \(place.name) from saved" : "Save \(place.name)")
        .accessibilityAddTraits(isSaved ? .isSelected : [])
        .accessibilityIdentifier("roasterdetail.save")
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("Roaster")
    .navigationBarTitleDisplayMode(.inline)
    .mapItemDetailSheet(item: $placeCard)
    .accessibilityIdentifier("roasterdetail.screen")
  }

  // MARK: Rows

  private var catalogRoaster: RoasterCatalog.Roaster? {
    RoasterCatalog.shared?.roaster(matching: place.name)
  }

  @ViewBuilder private func catalogRow(_ roaster: RoasterCatalog.Roaster) -> some View {
    let label = rowLabel(
      "Coffees and starter recipes", "\(roaster.coffees.count) in the Next Cup catalog",
      "storefront")
    if let openCatalog {
      Button {
        openCatalog(roaster)
      } label: {
        label
      }
      .accessibilityIdentifier("roasterdetail.catalog")
    } else {
      NavigationLink {
        CatalogRoasterView(roaster: roaster, checkedOn: RoasterCatalog.shared?.checkedOn ?? "")
      } label: {
        label
      }
      .accessibilityIdentifier("roasterdetail.catalog")
    }
    Hairline()
  }

  private var details: some View {
    PaperBox {
      VStack(spacing: 0) {
        if let catalogRoaster { catalogRow(catalogRoaster) }
        if let phone = place.phone {
          row("Phone", phone, "phone", id: "phone") { open(place.callURL) }
          Hairline()
        }
        if let website = place.website {
          row("Website", website.host() ?? website.absoluteString, "safari", id: "website") {
            openURL(website)
          }
          Hairline()
        }
        if place.mapItemID != nil {
          row(
            "Hours, photos and more", loadingCard ? "Loading" : "From Apple Maps", "clock",
            id: "hours", action: showPlaceCard)
          Hairline()
        }
        row(
          "Open in Google Maps", "The app, or your browser", "arrow.up.right.square", id: "google"
        ) {
          open(place.googleMapsURL)
        }
      }
    }
    .buttonStyle(PressableStyle())
  }

  private func row(
    _ title: String, _ detail: String, _ symbol: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) { rowLabel(title, detail, symbol) }
      .accessibilityIdentifier("roasterdetail.\(id)")
  }

  private func rowLabel(_ title: String, _ detail: String, _ symbol: String) -> some View {
    RoasterRowLabel(title: title, detail: detail, symbol: symbol)
  }

  // MARK: Actions

  private func open(_ url: URL?) {
    if let url { openURL(url) }
  }

  /// Apple's own place card carries what a search result does not: opening hours,
  /// photos and ratings.
  private func showPlaceCard() {
    guard !loadingCard, let raw = place.mapItemID,
      let identifier = MKMapItem.Identifier(rawValue: raw)
    else { return }
    loadingCard = true
    cardNotice = nil
    Task {
      defer { loadingCard = false }
      do {
        placeCard = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
      } catch {
        cardNotice = "Apple Maps couldn't load this place right now. Try again in a moment."
      }
    }
  }
}
