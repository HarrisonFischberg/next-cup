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
      .onChange(of: model.places) { camera = .automatic }
      .onChange(of: selectedID) {
        guard let place = model.places.first(where: { $0.id == selectedID }) else { return }
        detail = place
        selectedID = nil
      }
      .navigationDestination(item: $detail) { place in
        RoasterPlaceDetailView(place: place, isSaved: service.isSaved(place, in: saved)) {
          toggle(place)
        }
      }
      .task { await model.start() }
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
        TextField("City", text: $model.city)
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
        .accessibilityLabel("Search city")
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
      ForEach(0..<3, id: \.self) { _ in
        SkeletonRow().listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
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
        Map(position: $camera, selection: $selectedID) {
          ForEach(model.places) { place in
            Marker(
              place.name,
              coordinate: CLLocationCoordinate2D(
                latitude: place.latitude, longitude: place.longitude)
            )
            .tag(place.id)
          }
        }
        .frame(height: 260)
        .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        // The list below carries every result and opens the same details.
        .accessibilityHidden(true)
        .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.lg, bottom: 0, trailing: DS.Space.lg))
        .listRowBackground(DS.bg).listRowSeparator(.hidden)
        ForEach(model.places) { place in
          PlaceRow(
            place: place, isSaved: service.isSaved(place, in: saved),
            open: { detail = place }
          ) { toggle(place) }
          .listRowInsets(EdgeInsets())
          .listRowBackground(DS.paper)
          .listRowSeparatorTint(DS.line)
        }
      }
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
    let existing = saved.first {
      $0.name.compare(place.name, options: [.caseInsensitive, .diacriticInsensitive])
        == .orderedSame
    }
    let result: Result<Void, StoreError>
    if let existing {
      result = service.unsave(existing)
    } else {
      result = service.save(place).map { _ in () }
    }
    apply(result)
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
            if let city = place.city { Text(city).font(.footnote).foregroundStyle(DS.ink2) }
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
