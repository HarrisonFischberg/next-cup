import SwiftUI

/// Settings > Appearance: every flavor as a live preview tile, plus the Make It Yours controls.
/// A change rebuilds the whole tree (see NextCupApp), so each one first asks Settings to scroll
/// back to this section.
struct FlavorPicker: View {
  static let returnKey = "settings.returnToAppearance"

  @AppStorage(AppStyle.storageKey) private var style = AppStyle.steelKraft.rawValue
  @AppStorage(MakeItYours.accentKey) private var accent = Swatch.all[2].id
  @AppStorage(MakeItYours.cornersKey) private var corners = Corners.soft.rawValue
  @AppStorage(MakeItYours.densityKey) private var density = Density.regular.rawValue
  @AppStorage(MakeItYours.fontKey) private var font = FontChoice.standard.rawValue
  @Environment(\.dynamicTypeSize) private var dts

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: DS.Space.md, alignment: .top),
      count: dts.isAccessibilitySize ? 1 : 2)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      LazyVGrid(columns: columns, spacing: DS.Space.md) {
        ForEach(AppStyle.allCases) { option in
          FlavorTile(style: option, isSelected: style == option.rawValue) {
            Self.keepPlace()
            style = option.rawValue
          }
        }
      }
      if style == AppStyle.makeItYours.rawValue { makeItYours }
    }
    .padding(.vertical, DS.Space.sm)
    .accessibilityIdentifier("settings.flavors")
  }

  private var makeItYours: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      Text("Make it yours").font(DS.Font.headline).foregroundStyle(DS.ink)
      Text("Accent").font(.footnote.weight(.semibold)).foregroundStyle(DS.ink2)
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: DS.Size.minTap + 4), spacing: DS.Space.sm)],
        spacing: DS.Space.sm
      ) {
        ForEach(Swatch.all) { swatch in
          Button {
            Self.keepPlace()
            accent = swatch.id
          } label: {
            Circle().fill(Color(P(swatch.light, swatch.dark)))
              .frame(width: 36, height: 36)
              .overlay {
                if accent == swatch.id {
                  Image(systemName: "checkmark").font(.footnote.weight(.heavy))
                    .foregroundStyle(DS.palette.onSignal.color)
                }
              }
              .overlay(Circle().strokeBorder(DS.line, lineWidth: DS.hairline))
              .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
          }
          .accessibilityLabel(swatch.title)
          .accessibilityAddTraits(accent == swatch.id ? .isSelected : [])
        }
      }
      segmented(
        "Corners", selection: $corners,
        options: Corners.allCases.map { ($0.rawValue, $0.title) }, id: "corners")
      segmented(
        "Density", selection: $density,
        options: [Density.compact, .regular].map { ($0.rawValue, $0.title) }, id: "density")
      segmented(
        "Type", selection: $font,
        options: FontChoice.allCases.map { ($0.rawValue, $0.title) }, id: "font")
    }
    .padding(DS.Space.md)
    .panel(DS.paper)
    .accessibilityElement(children: .contain)
  }

  private func segmented(
    _ title: String, selection: Binding<String>, options: [(value: String, title: String)],
    id: String
  ) -> some View {
    Picker(
      title,
      selection: Binding(
        get: { selection.wrappedValue },
        set: {
          Self.keepPlace()
          selection.wrappedValue = $0
        })
    ) {
      ForEach(options, id: \.value) { Text($0.title).tag($0.value) }
    }
    .pickerStyle(.segmented)
    .frame(minHeight: DS.Size.control)
    .accessibilityIdentifier("settings.mine.\(id)")
  }

  /// Settings reads this when it reappears after the rebuild.
  static func keepPlace() {
    UserDefaults.standard.set(true, forKey: returnKey)
  }
}

extension P {
  fileprivate var color: Color { Color(self) }
}

/// A miniature spec card drawn in one flavor's colors, type, corners and control style.
struct FlavorTile: View {
  let style: AppStyle
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let palette = style.palette
    let flavor = style.flavor
    let shape = RoundedRectangle(cornerRadius: flavor.radius, style: .continuous)
    let button = RoundedRectangle(
      cornerRadius: flavor.control == .pill ? 999 : flavor.radius, style: .continuous)
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8 * flavor.density.factor) {
        HStack(alignment: .firstTextBaseline) {
          Text(style.title).font(flavor.display(20, relativeTo: .headline))
            .foregroundStyle(palette.ink.color).lineLimit(2)
          Spacer(minLength: 4)
          if isSelected {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.signal.color)
          }
        }
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("18 g").font(flavor.number(.title3, .bold))
          Text("1:16").font(flavor.number(.footnote, .regular))
            .foregroundStyle(palette.ink2.color)
        }
        .foregroundStyle(palette.ink.color)
        Text("Brew")
          .font(flavor.display(16, relativeTo: .footnote))
          .foregroundStyle(palette.onSignal.color)
          .frame(maxWidth: .infinity, minHeight: 28)
          .background(palette.signal.color, in: button)
          .overlay(button.strokeBorder(palette.line.color, lineWidth: 1))
          .background {
            if flavor.control == .sticker {
              button.fill(palette.line.color).offset(x: 2, y: 2)
            }
          }
      }
      .padding(10 * flavor.density.factor)
      .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
      .background(palette.paper.color, in: shape)
      .overlay(shape.strokeBorder(palette.line.color, lineWidth: isSelected ? 3 : 1))
      .background {
        if flavor.control == .sticker {
          shape.fill(palette.signal.color).offset(x: 3, y: 3)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(style.title)
    .accessibilityHint(style.mood)
    .accessibilityValue(isSelected ? "Selected" : "")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityIdentifier("settings.flavor.\(style.rawValue)")
  }
}
