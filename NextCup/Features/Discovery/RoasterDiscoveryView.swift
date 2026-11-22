import MapKit
import SwiftData
import SwiftUI
import UIKit

/// S10: find local roasters. Search a typed city, or tap "Use my location" (asked
/// for then, not at launch). Once location is allowed the screen opens on the map of
/// roasters nearby. Tapping a roaster, on the map or in the list, shows its details.
/// Only a roaster the user saves is kept, and it keeps the roaster's place, never the
/// user's.
struct RoasterDiscoveryView: View {
  /// Text from Explore's search box: searched on the map as soon as the screen opens.
  var initialQuery: String?
  /// Opens a roaster's catalog page (coffees and starter recipes) back on Explore.
  var openCatalog: ((RoasterCatalog.Roaster) -> Void)?
  let onClose: () -> Void

  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @FocusState private var cityFocused: Bool
  @Query(filter: #Predicate<Roaster> { $0.savedFromMap }, sort: \Roaster.name)
  private var saved: [Roaster]
  @State private var model = RoasterDiscoveryModel.live()
  @State private var camera = MapCameraPosition.automatic
  @State private var error: String?
  @State private var selectedID: String?
  @State private var detail: RoasterPlace?
  /// The framing the results were shown in, and where the user has moved the map to.
  @State private var fittedRegion: MKCoordinateRegion?
  @State private var visibleRegion: MKCoordinateRegion?

  private var service: RoasterService { RoasterService(store: Store(context: context)) }

  var body: some View {
    NavigationStack {
      List {
        Section { controls }
          .listRowInsets(EdgeInsets())
          .listRowBackground(DS.bg)
          .listRowSeparator(.hidden)
        if let error {
          StateBanner(kind: .error, message: error, actionTitle: "Dismiss") { self.error = nil }
            .accessibilityIdentifier("roasters.error")
            .listRowInsets(EdgeInsets())
            .listRowBackground(DS.bg)
        }
        results
        savedSection
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .environment(\.defaultMinListRowHeight, DS.Size.minTap)
      .background(DS.bg)
      .navigationTitle("Find roasters")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: onClose).accessibilityIdentifier("roasters.done")
        }
      }
      .onChange(of: model.places) {
        // "Search this area" keeps the map where the user put it.
        if model.showsRegionResults {
          fittedRegion = visibleRegion
        } else if let region = RoasterMap.region(fitting: model.places, around: model.origin) {
          camera = .region(region)
          fittedRegion = region
        }
      }
      .onChange(of: selectedID) {
        guard let place = model.places.first(where: { $0.id == selectedID }) else { return }
        detail = place
        selectedID = nil
      }
      .navigationDestination(item: $detail) { place in
        RoasterPlaceDetailView(
          place: place, isSaved: service.isSaved(place, in: saved), openCatalog: openCatalog
        ) {
          toggle(place)
        }
      }
      .task {
        if let initialQuery, model.phase == .idle, model.places.isEmpty {
          model.city = initialQuery
          await model.searchCity()
        } else {
          await model.start()
        }
      }
      .accessibilityIdentifier("roasters.screen")
    }
  }

  // MARK: Search

  private var controls: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      let layout =
        dts.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
        : AnyLayout(HStackLayout(spacing: DS.Space.sm))
      layout {
        TextField("City or roaster", text: $model.city)
          .focused($cityFocused)
          .textContentType(.addressCity)
          .submitLabel(.search)
          .textInputAutocapitalization(.words)
          .onSubmit(searchCity)
          .padding(.horizontal, DS.Space.md)
          .frame(minHeight: DS.Size.control)
          .panel(DS.paper)
          .accessibilityIdentifier("roasters.city")
        Button(action: searchCity) {
          Text("Search".dsTitle).font(DS.Font.headline)
            .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.control)
            .padding(.horizontal, DS.Space.md)
        }
        .buttonStyle(SteelButtonStyle(kind: .secondary))
        .disabled(model.isBusy || model.city.trimmingCharacters(in: .whitespaces).isEmpty)
        .accessibilityLabel("Search city or roaster")
        .accessibilityIdentifier("roasters.search")
      }
      SteelButton(
        title: "Use my location", kind: .secondary, isLoading: model.phase == .locating
      ) {
        Task { await model.useMyLocation() }
      }
      .accessibilityIdentifier("roasters.locate")
      if let notice = model.locationNotice {
        StateBanner(kind: .info, message: notice)
          .accessibilityIdentifier("roasters.locationNotice")
      }
    }
    .padding(DS.Space.lg)
  }

  private func searchCity() {
    cityFocused = false  // the keyboard would hide the results
    Task { await model.searchCity() }
  }

  // MARK: Results

  @ViewBuilder private var results: some View {
    switch model.phase {
    case .idle:
      // With location already allowed the screen is on its way to the map: no hint.
      if !model.opensOnMap {
        Text("Search a city or use your location. Only roasters you save are kept.")
          .font(.callout).foregroundStyle(DS.ink2)
          .padding(.horizontal, DS.Space.lg)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
          .accessibilityIdentifier("roasters.hint")
      }
    case .locating, .searching:
      if model.showsRegionResults, !model.places.isEmpty {
        mapAndRows  // the map stays while its area is searched
      } else {
        ForEach(0..<3, id: \.self) { _ in
          SkeletonRow().listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
        }
      }
    case .failed(let message):
      StateBanner(kind: .offline, message: message, actionTitle: "Retry") {
        Task { await model.retry() }
      }
      .accessibilityIdentifier("roasters.failed")
      .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
    case .results:
      if model.places.isEmpty {
        EmptyState(
          title: "No roasters found",
          message: "Try a nearby city, or check the spelling."
        )
        .accessibilityIdentifier("roasters.empty")
        .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
      } else {
        mapAndRows
      }
    }
  }

  private var canSearchArea: Bool {
    guard !model.isBusy, let fittedRegion, let visibleRegion else { return false }
    return RoasterMap.moved(from: fittedRegion, to: visibleRegion)
  }

  @ViewBuilder private var mapAndRows: some View {
    Map(position: $camera, selection: $selectedID) {
      if model.opensOnMap { UserAnnotation() }
      ForEach(model.places) { place in
        Marker(
          place.name,
          coordinate: CLLocationCoordinate2D(
            latitude: place.latitude, longitude: place.longitude)
        )
        .tag(place.id)
      }
    }
    .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
    .frame(height: 260)
    .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
    // The list below carries every result and opens the same details.
    .accessibilityHidden(true)
    .overlay(alignment: .top) {
      if canSearchArea || (model.phase == .searching && model.showsRegionResults) {
        Button {
          guard let visibleRegion else { return }
          // Pin the map where the user put it: it is redrawn while the area is searched.
          camera = .region(visibleRegion)
          fittedRegion = visibleRegion
          Task { await model.searchRegion(visibleRegion) }
        } label: {
          HStack(spacing: DS.Space.sm) {
            if model.phase == .searching { ProgressView().tint(DS.ink) }
            Text("Search this area").font(DS.Font.label).foregroundStyle(DS.ink)
          }
          .padding(.horizontal, DS.Space.md)
          .frame(minHeight: DS.Size.minTap)
          .background(DS.paper, ignoresSafeAreaEdges: [])
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        }
        .buttonStyle(PressableStyle())
        .disabled(model.isBusy)
        .padding(.top, DS.Space.sm)
        .accessibilityIdentifier("roasters.searchArea")
      }
    }
    .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.lg, bottom: 0, trailing: DS.Space.lg))
    .listRowBackground(DS.bg).listRowSeparator(.hidden)
    if let notice = model.areaNotice {
      StateBanner(kind: .info, message: notice)
        .accessibilityIdentifier("roasters.areaNotice")
        .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
    }
    ForEach(model.places) { place in
      PlaceRow(
        place: place, distance: model.distanceText(to: place),
        isSaved: service.isSaved(place, in: saved),
        open: { detail = place }
      ) { toggle(place) }
      .listRowInsets(EdgeInsets())
      .listRowBackground(DS.paper)
      .listRowSeparatorTint(DS.line)
    }
  }

  // MARK: Saved

  @ViewBuilder private var savedSection: some View {
    Section {
      if saved.isEmpty {
        Text("Roasters you save appear here and can be picked on a bean.")
          .font(.callout).foregroundStyle(DS.ink2)
          .listRowBackground(DS.bg)
          .accessibilityIdentifier("roasters.savedEmpty")
      }
      ForEach(saved) { roaster in
        HStack(spacing: DS.Space.md) {
          Button {
            detail = RoasterPlace(roaster)
          } label: {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
              Text(roaster.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
              if let city = roaster.city { Text(city).font(.footnote).foregroundStyle(DS.ink2) }
            }
            .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(PressableStyle())
          .disabled(RoasterPlace(roaster) == nil)
          .accessibilityHint("Shows details")
          Button("Remove") { remove(roaster) }
            .buttonStyle(PressableStyle())
            .font(DS.Font.label).foregroundStyle(DS.ink)
            .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
            .accessibilityLabel("Remove \(roaster.name) from saved")
        }
        .padding(DS.Space.md)
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.paper)
        .listRowSeparatorTint(DS.line)
        .accessibilityIdentifier("roasters.saved.\(roaster.name)")
      }
    } header: {
      Text("SAVED ROASTERS").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
    }
  }

  private func toggle(_ place: RoasterPlace) {
    apply(service.toggle(place, in: saved))
  }

  private func remove(_ roaster: Roaster) {
    apply(service.unsave(roaster))
  }

  private func apply(_ result: Result<Void, StoreError>) {
    switch result {
    case .success:
      error = nil
      Feedback.tap()
    case .failure(.saveFailed(let reason)):
      error = "The change was not kept. \(reason)"
    }
  }
}

/// One result: name and city (tap for details), with a Save / Saved toggle that stays
/// reachable at every text size.
private struct PlaceRow: View {
  let place: RoasterPlace
  let distance: String?
  let isSaved: Bool
  let open: () -> Void
  let toggle: () -> Void
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(spacing: DS.Space.md))
    layout {
      Button(action: open) {
        HStack(spacing: DS.Space.sm) {
          VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(place.name.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
            let line = [place.city, distance].compactMap { $0 }.joined(separator: "  ·  ")
            if !line.isEmpty { Text(line).font(.footnote).foregroundStyle(DS.ink2) }
          }
          Spacer(minLength: DS.Space.sm)
          Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            .foregroundStyle(DS.ink2).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(PressableStyle())
      .accessibilityElement(children: .combine)
      .accessibilityHint("Shows address, phone and directions")
      .accessibilityIdentifier("roasters.place.\(place.name)")
      Button(action: toggle) {
        Text(isSaved ? "SAVED" : "SAVE").font(DS.Font.label)
          .foregroundStyle(isSaved ? DS.onSignal : DS.ink)
          .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
          .padding(.horizontal, DS.Space.sm)
          .background(isSaved ? DS.signal : DS.paper, ignoresSafeAreaEdges: [])
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(isSaved ? "Remove \(place.name) from saved" : "Save \(place.name)")
      .accessibilityAddTraits(isSaved ? .isSelected : [])
      .accessibilityIdentifier("roasters.toggle.\(place.name)")
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
