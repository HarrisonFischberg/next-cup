import MapKit
import SwiftData
import SwiftUI
import UIKit

/// S10: find local roasters. Search a typed city, or tap "Use my location" (asked
/// for then, not at launch). Only a roaster the user saves is kept, and it keeps
/// the roaster's place, never the user's.
struct RoasterDiscoveryView: View {
  let onClose: () -> Void

  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @Query(filter: #Predicate<Roaster> { $0.savedFromMap }, sort: \Roaster.name)
  private var saved: [Roaster]
  @State private var model = RoasterDiscoveryModel.live()
  @State private var camera = MapCameraPosition.automatic
  @State private var error: String?

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
          .textContentType(.addressCity)
          .submitLabel(.search)
          .textInputAutocapitalization(.words)
          .onSubmit(searchCity)
          .padding(.horizontal, DS.Space.md)
          .frame(minHeight: DS.Size.control)
          .background(DS.paper, ignoresSafeAreaEdges: [])
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
          .accessibilityIdentifier("roasters.city")
        Button(action: searchCity) {
          Text("SEARCH").font(DS.Font.headline)
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
    Task { await model.searchCity() }
  }

  // MARK: Results

  @ViewBuilder private var results: some View {
    switch model.phase {
    case .idle, .locating:
      if model.phase == .idle {
        Text("Search a city or use your location. Only roasters you save are kept.")
          .font(.callout).foregroundStyle(DS.ink2)
          .padding(.horizontal, DS.Space.lg)
          .listRowInsets(EdgeInsets()).listRowBackground(DS.bg).listRowSeparator(.hidden)
          .accessibilityIdentifier("roasters.hint")
      }
    case .searching:
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
        Map(position: $camera) {
          ForEach(model.places) { place in
            Marker(
              place.name,
              coordinate: CLLocationCoordinate2D(
                latitude: place.latitude, longitude: place.longitude))
          }
        }
        .frame(height: 220)
        .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        // The list below carries every result; the map only adds the picture.
        .accessibilityHidden(true)
        .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.lg, bottom: 0, trailing: DS.Space.lg))
        .listRowBackground(DS.bg).listRowSeparator(.hidden)
        ForEach(model.places) { place in
          PlaceRow(place: place, isSaved: service.isSaved(place, in: saved)) { toggle(place) }
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
          VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(roaster.name.uppercased()).font(DS.Font.headline).foregroundStyle(DS.ink)
            if let city = roaster.city { Text(city).font(.footnote).foregroundStyle(DS.ink2) }
          }
          Spacer(minLength: DS.Space.sm)
          Button("Remove") { remove(roaster) }
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
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .failure(.saveFailed(let reason)):
      error = "The change was not kept. \(reason)"
    }
  }
}

/// One result: name and city, with a Save / Saved toggle that stays reachable at
/// every text size.
private struct PlaceRow: View {
  let place: RoasterPlace
  let isSaved: Bool
  let toggle: () -> Void
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(spacing: DS.Space.md))
    layout {
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        Text(place.name.uppercased()).font(DS.Font.headline).foregroundStyle(DS.ink)
        if let city = place.city { Text(city).font(.footnote).foregroundStyle(DS.ink2) }
      }
      .accessibilityElement(children: .combine)
      if !dts.isAccessibilitySize { Spacer(minLength: DS.Space.sm) }
      Button(action: toggle) {
        Text(isSaved ? "SAVED" : "SAVE").font(DS.Font.label)
          .foregroundStyle(isSaved ? DS.onSignal : DS.ink)
          .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
          .padding(.horizontal, DS.Space.sm)
          .background(isSaved ? DS.signal : DS.paper, ignoresSafeAreaEdges: [])
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isSaved ? "Remove \(place.name) from saved" : "Save \(place.name)")
      .accessibilityAddTraits(isSaved ? .isSelected : [])
      .accessibilityIdentifier("roasters.toggle.\(place.name)")
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
