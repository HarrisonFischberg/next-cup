import SwiftUI

/// A setting stepped with − / +, styled like the Dose row, so a scroll past it cannot
/// change it. Holding the number opens a dial over it: slide while still holding and let go
/// to keep; a hold let go without sliding leaves the dial open to slide, and a tap outside
/// closes it. The host shows the dial with `dialPopups()`, outside any clipped panel.
/// Every stepper row is this view, so their labels and controls line up.
struct DialStepper: View {
  /// What VoiceOver calls it, e.g. "Grind setting".
  let title: String
  let options: [String]
  @Binding var selection: String
  let unit: String?
  let identifier: String
  /// The words on the left. The design directions put the row's name here.
  var caption = "Hold for dial"
  /// The number over its − and +, for a half-width tile.
  var stacked = false

  @State private var open = false
  /// The stop the hold began on; nil when no finger is down on the number.
  @State private var heldFrom: Int?

  private var index: Int { options.firstIndex(of: selection) ?? 0 }

  var body: some View {
    let minus = stepButton("minus", label: "Decrease \(title)", id: "decrease") { step(by: -1) }
      .disabled(index == 0)
    let plus = stepButton("plus", label: "Increase \(title)", id: "increase") { step(by: 1) }
      .disabled(index == options.count - 1)
    return Group {
      if stacked {
        VStack(spacing: DS.Space.xs) {
          number
          HStack(spacing: DS.Space.md) {
            minus
            plus
          }
        }
        .frame(maxWidth: .infinity)
      } else {
        HStack(spacing: 2) {
          Text(caption).font(.footnote).foregroundStyle(DS.ink2).layoutPriority(1)
          Spacer(minLength: DS.Space.sm)
          minus
          number
          plus
        }
        .padding(DS.Space.md)
      }
    }
    .sensoryFeedback(.selection, trigger: selection)
  }

  private var number: some View {
    HStack(alignment: .firstTextBaseline, spacing: 2) {
      Text(Self.shown(selection)).font(DS.Font.dataLarge)
      if let unit { Text(unit).font(DS.Font.mono(.callout)) }
    }
    // One width for every row, so − and + sit at the same place on each.
    .foregroundStyle(DS.ink).frame(minWidth: 100, minHeight: DS.Size.minTap)
    .contentShape(Rectangle())
    .gesture(hold)
    .anchorPreference(key: DialPopupKey.self, value: .bounds) { anchor in
      open
        ? DialPopup(
          anchor: anchor,
          view: AnyView(
            DialCard(
              options: options, selection: $selection, open: $open,
              holding: heldFrom != nil)))
        : nil
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(Self.shown(selection) + (unit.map { " \($0)" } ?? ""))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: step(by: 1)
      case .decrement: step(by: -1)
      @unknown default: break
      }
    }
    .accessibilityIdentifier(identifier)
  }

  /// Hold, then slide up for higher and down for lower, like turning a wheel.
  private var hold: some Gesture {
    LongPressGesture(minimumDuration: 0.35)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .onChanged { value in
        guard case .second(true, let drag) = value else { return }
        if heldFrom == nil {
          heldFrom = index
          open = true
        }
        guard let drag, let from = heldFrom else { return }
        select(from - Int((drag.translation.height / DialCard.rowHeight).rounded()))
      }
      .onEnded { value in
        guard heldFrom != nil else { return }
        heldFrom = nil
        if case .second(true, let drag?) = value, abs(drag.translation.height) > 8 { open = false }
      }
  }

  private func step(by delta: Int) { select(index + delta) }

  private func select(_ i: Int) {
    let stop = options[min(max(i, 0), options.count - 1)]
    if stop != selection { selection = stop }
  }

  static func shown(_ stop: String) -> String { stop.isEmpty ? "—" : stop }

  private func stepButton(
    _ symbol: String, label: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      #if DEBUG
        if let design = DesignExplore.current {
          designGlyph(symbol, design)
        } else {
          ringGlyph(symbol)
        }
      #else
        ringGlyph(symbol)
      #endif
    }
    .accessibilityLabel(label)
    .accessibilityIdentifier("\(identifier).\(id)")
  }

  #if DEBUG
    /// The − and + of each design direction; the tap target stays 44 pt.
    @ViewBuilder private func designGlyph(_ symbol: String, _ design: DesignExplore) -> some View {
      switch design {
      // A square key on the instrument.
      case .a:
        Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
          .foregroundStyle(DS.accent).frame(width: 40, height: 36)
          .background(DS.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
          .frame(width: DS.Size.minTap, height: DS.Size.minTap).contentShape(Rectangle())
      // A solid cobalt button.
      case .b:
        Image(systemName: symbol).font(.system(size: 16, weight: .heavy))
          .foregroundStyle(DS.onSignal).frame(width: 40, height: 40)
          .background(DS.signal, in: Circle())
          .frame(width: DS.Size.minTap, height: DS.Size.minTap).contentShape(Rectangle())
      // A pen mark, no button drawn.
      case .c:
        Image(systemName: symbol).font(.system(size: 18, weight: .medium))
          .foregroundStyle(DS.accent)
          .frame(width: DS.Size.minTap, height: DS.Size.minTap).contentShape(Rectangle())
      }
    }
  #endif

  private func ringGlyph(_ symbol: String) -> some View {
    Group {
      // A 38 pt ring with a fine glyph, inside the full 44 pt tap target.
      Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
        .foregroundStyle(DS.accent)
        .frame(width: 38, height: 38)
        .overlay(Circle().strokeBorder(DS.accent, lineWidth: 1.25))
        .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        .contentShape(Rectangle())
    }
  }
}

/// The dial over the number: two stops either side of the current one.
private struct DialCard: View {
  static let rowHeight: CGFloat = 36
  let options: [String]
  @Binding var selection: String
  @Binding var open: Bool
  let holding: Bool
  @State private var dragFrom: Int?

  var body: some View {
    let index = options.firstIndex(of: selection) ?? 0
    ZStack {
      Color.black.opacity(0.35).padding(-2000)
        .contentShape(Rectangle())
        .onTapGesture { open = false }
        .accessibilityHidden(true)
      VStack(spacing: DS.Space.xs) {
        VStack(spacing: 0) {
          ForEach(-2...2, id: \.self) { offset in
            let i = index + offset
            Text(options.indices.contains(i) ? DialStepper.shown(options[i]) : " ")
              .font(offset == 0 ? DS.Font.dataLarge : DS.Font.data)
              .foregroundStyle(offset == 0 ? DS.ink : DS.ink2)
              .opacity(offset == 0 ? 1 : 0.7 - 0.2 * Double(abs(offset)))
              .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
              .background {
                if offset == 0 {
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DS.accent.opacity(0.14))
                }
              }
          }
        }
        Text("Slide to set · let go to keep").font(.caption).foregroundStyle(DS.ink2)
          .fixedSize()
      }
      .padding(DS.Space.md)
      .frame(width: 168)
      .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
          .strokeBorder(DS.accent, lineWidth: 1.5)
      )
      .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
      // Once the finger is up, the dial itself slides.
      .gesture(
        DragGesture(minimumDistance: 4)
          .onChanged { drag in
            let from = dragFrom ?? index
            dragFrom = from
            let i = from - Int((drag.translation.height / Self.rowHeight).rounded())
            let stop = options[min(max(i, 0), options.count - 1)]
            if stop != selection { selection = stop }
          }
          .onEnded { _ in dragFrom = nil },
        isEnabled: !holding
      )
      .accessibilityElement(children: .ignore)
      .accessibilityIdentifier("dial.popup")
    }
  }
}

struct DialPopup {
  let anchor: Anchor<CGRect>
  let view: AnyView
}

struct DialPopupKey: PreferenceKey {
  static var defaultValue: DialPopup? { nil }
  static func reduce(value: inout DialPopup?, nextValue: () -> DialPopup?) {
    value = value ?? nextValue()
  }
}

extension View {
  /// Shows an open `DialStepper` dial centred over its number, above the content.
  func dialPopups() -> some View {
    overlayPreferenceValue(DialPopupKey.self) { popup in
      GeometryReader { proxy in
        if let popup {
          let frame = proxy[popup.anchor]
          popup.view.position(x: frame.midX, y: frame.midY)
        }
      }
    }
  }
}
