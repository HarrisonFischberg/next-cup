import SwiftUI

/// Settings > Appearance: every flavor as a live preview tile. A change rebuilds the whole
/// tree (see NextCupApp), so each one first asks Settings to scroll back to this section.
struct FlavorPicker: View {
  static let returnKey = "settings.returnToAppearance"

  @AppStorage(AppStyle.storageKey) private var style = AppStyle.sundayStudio.rawValue
  @Environment(\.dynamicTypeSize) private var dts

  /// The tiles in rows of two (one at accessibility sizes). A plain Grid, not a lazy one:
  /// inside a List row a LazyVGrid left a screen of blank space below the tiles.
  private var rows: [[AppStyle]] {
    let count = dts.isAccessibilitySize ? 1 : 2
    return stride(from: 0, to: AppStyle.offered.count, by: count).map {
      Array(AppStyle.offered[$0..<min($0 + count, AppStyle.offered.count)])
    }
  }

  var body: some View {
    Grid(horizontalSpacing: DS.Space.md, verticalSpacing: DS.Space.md) {
      ForEach(rows, id: \.self) { row in
        GridRow(alignment: .top) {
          ForEach(row) { option in
            FlavorTile(style: option, isSelected: option == AppStyle.current) {
              Self.keepPlace()
              style = option.rawValue
            }
          }
          if row.count == 1, !dts.isAccessibilitySize {
            Color.clear.gridCellUnsizedAxes(.vertical)
          }
        }
      }
    }
    .padding(.vertical, DS.Space.sm)
    .accessibilityIdentifier("settings.flavors")
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
          Text("1:16").font(flavor.number(.footnote, .bold))
            .foregroundStyle((palette.accent ?? palette.signal).color)
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
