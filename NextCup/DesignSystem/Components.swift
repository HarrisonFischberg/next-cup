import NextCupKit
import SwiftUI

// Steel & Kraft components. Each is a primitive: no model types, so it can be
// reused by every screen. States: default, pressed, disabled, loading, error,
// empty. Every interactive component is at least 44 pt and carries its own
// accessibility label or traits. Gallery.swift shows each state.

// MARK: Rules

struct Hairline: View {
  var body: some View { Rectangle().fill(DS.line).frame(height: DS.rule) }
}

/// A surface in the flavor's corner radius: Liquid Glass tinted with the fill, its content
/// clipped to the rounded shape. Sticker flavors and Reduce Transparency get the solid fill
/// and full border instead (stickers add a hard offset shadow in the accent, no blur).
private struct Panel: ViewModifier {
  let fill: Color
  var border = DS.line
  var dash: [CGFloat] = []
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
    if DS.flavor.control == .sticker || reduceTransparency {
      content
        .clipShape(shape)
        .background(fill, in: shape)
        .overlay(
          shape.strokeBorder(border, style: StrokeStyle(lineWidth: DS.rule, dash: dash))
        )
        .background {
          if DS.flavor.control == .sticker { shape.fill(DS.signal).offset(x: 3, y: 3) }
        }
    } else {
      content
        .clipShape(shape)
        .glassEffect(.regular.tint(fill.opacity(0.6)), in: shape)
        .overlay(
          shape.strokeBorder(border.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: dash))
        )
    }
  }
}

extension View {
  func panel(_ fill: Color, border: Color = DS.line, dash: [CGFloat] = []) -> some View {
    modifier(Panel(fill: fill, border: border, dash: dash))
  }
}

// MARK: Buttons

enum SteelKind { case primary, secondary }

/// Square-cornered hardware button. Press moves it down 2 pt (no motion with Reduce Motion).
struct SteelButtonStyle: ButtonStyle {
  var kind: SteelKind = .primary
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
    if DS.flavor.control == .sticker || reduceTransparency {
      solid(configuration, shape)
    } else {
      // Liquid Glass: the primary tinted with the accent, the secondary clear.
      configuration.label
        .foregroundStyle(kind == .primary ? DS.onSignal : DS.ink)
        .glassEffect(
          (kind == .primary ? Glass.regular.tint(DS.signal) : Glass.regular).interactive(),
          in: shape
        )
        .opacity(enabled ? 1 : 0.4)
    }
  }

  private func solid(_ configuration: Configuration, _ shape: RoundedRectangle) -> some View {
    configuration.label
      .foregroundStyle(kind == .primary ? DS.onSignal : (DS.isBloom ? DS.ink : DS.onSteel))
      .background(kind == .primary ? DS.signal : (DS.isBloom ? .clear : DS.steel), in: shape)
      .overlay(shape.strokeBorder(DS.line, lineWidth: DS.isBloom ? 1 : DS.rule))
      .background {
        if DS.flavor.control == .sticker {
          shape.fill(kind == .primary ? DS.line : DS.signal).offset(x: 3, y: 3)
        }
      }
      .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
      .brightness(configuration.isPressed && reduceMotion ? -0.08 : 0)
      .opacity(enabled ? 1 : 0.4)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

/// Titled button. `isLoading` keeps the label (so VoiceOver still names it), shows a spinner and blocks taps.
struct SteelButton: View {
  let title: String
  var kind: SteelKind = .primary
  var isLoading = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DS.Space.sm) {
        if isLoading { ProgressView().tint(kind == .primary ? DS.onSignal : DS.onSteel) }
        Text(title.dsTitle).font(DS.Font.din(kind == .primary ? 26 : 22, relativeTo: .title2))
          .tracking(1)
          // A long title (a bean's name in it) shrinks instead of running off the button.
          .lineLimit(1).minimumScaleFactor(0.6)
      }
      .padding(.horizontal, DS.Space.md)
      .dynamicTypeSize(...DS.displayCap)
      .frame(
        maxWidth: .infinity, minHeight: kind == .primary ? DS.Size.primary : DS.Size.timerControl)
    }
    .buttonStyle(SteelButtonStyle(kind: kind))
    .allowsHitTesting(!isLoading)
    .accessibilityLabel(title)
    .accessibilityValue(isLoading ? "Working" : "")
  }
}

// MARK: Spec sheet

/// One cell of the spec grid: label over a measured value.
struct SpecCell: View {
  let label: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
      Text(value).font(DS.Font.mono(.title2, .bold)).foregroundStyle(DS.ink)
        .minimumScaleFactor(0.6).lineLimit(1)
    }
    .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Bordered paper container (spec grid, table body).
struct PaperBox<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content.panel(DS.paper)
  }
}

/// Steel header row for a table: "T+  Operation  Scale".
struct ColumnHeader: View {
  let leading: String
  let middle: String
  let trailing: String
  var body: some View {
    HStack {
      Text(leading).frame(width: 56, alignment: .leading)
      Text(middle)
      Spacer()
      Text(trailing)
    }
    .font(DS.Font.label).textCase(.uppercase).foregroundStyle(DS.isBloom ? DS.ink2 : DS.onSteel)
    .padding(.horizontal, DS.Space.md).frame(minHeight: 36)
    .background(
      DS.isBloom ? .clear : DS.steel,
      in: RoundedRectangle(cornerRadius: min(DS.radius, 12), style: .continuous)
    )
    .accessibilityHidden(true)
  }
}

enum RowState { case upcoming, live, done }

/// One operation in a recipe: time, name, optional instruction, scale target.
/// `live` lights the row in signal orange and shows its instruction.
struct OperationRow: View {
  let time: String
  let name: String
  var instruction: String?
  var scale: String?
  var state: RowState = .upcoming
  var showsInstruction = true
  /// Off for the last row, so the table ends on its rounded edge, not a rule.
  var showsDivider = true
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    let live = state == .live
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Space.md))
    layout {
      Text(time).font(DS.Font.data).fixedSize().frame(minWidth: 52, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(name.dsTitle).font(DS.Font.din(live ? 26 : 20, relativeTo: .title3))
        if let instruction, live || showsInstruction {
          Text(instruction).font(live ? .subheadline : .footnote)
            .foregroundStyle(live ? DS.onSignal : DS.ink2)
        }
      }
      if !dts.isAccessibilitySize { Spacer(minLength: DS.Space.sm) }
      if let scale { Text(scale).font(live ? DS.Font.mono(.title3, .bold) : DS.Font.data) }
    }
    .foregroundStyle(live ? DS.onSignal : (state == .done ? DS.ink2 : DS.ink))
    .padding(.horizontal, DS.Space.md).padding(.vertical, live ? DS.Space.md : DS.Space.md - 3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(live ? DS.signal : .clear, ignoresSafeAreaEdges: [])
    .overlay(alignment: .bottom) {
      if showsDivider {
        Rectangle().fill(DS.line.opacity(0.5)).frame(height: DS.hairline)
          .padding(.horizontal, DS.Space.md)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(live ? .isSelected : [])
  }
}

// MARK: Instrument panel

/// Steel panel for the timer readout.
struct InstrumentPanel<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content
      .padding(DS.Space.lg)
      .panel(DS.steel)
  }
}

/// Elapsed-time bar on steel. Decorative; the readout carries the value.
struct ReadoutBar: View {
  let fraction: Double
  var body: some View {
    Rectangle().fill(DS.onSteel.opacity(0.2)).frame(height: 8)
      .overlay(alignment: .leading) {
        GeometryReader { g in
          Rectangle().fill(DS.signalOnSteel).frame(width: g.size.width * min(1, max(0, fraction)))
        }
      }
      .accessibilityHidden(true)
  }
}

// MARK: Value entry

/// Value with its recipe target and -/+ buttons. The saved value is whatever is shown.
struct StepperTile: View {
  let title: String
  let value: String
  var unit = ""
  var target: String?
  let down: () -> Void
  let up: () -> Void
  var minusLabel: String?
  var plusLabel: String?
  /// When set, the value is a field the user can tap and type into.
  var text: Binding<String>?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
          if let text {
            TextField(title, text: text).font(DS.Font.dataLarge).keyboardType(.decimalPad)
              .fixedSize().accessibilityLabel(title).accessibilityHint("Type a value")
              .accessibilityIdentifier("stepper.\(title.lowercased()).value")
            Image(systemName: "pencil").font(.footnote).foregroundStyle(DS.ink2)
              .accessibilityHidden(true)
          } else {
            Text(value).font(DS.Font.dataLarge).minimumScaleFactor(0.6).lineLimit(1)
          }
          Text(unit).font(DS.Font.mono(.callout))
        }
        .foregroundStyle(DS.ink)
        Text(target.map { "TARGET \($0)" } ?? " ").font(DS.Font.mono(.caption2)).foregroundStyle(
          DS.ink2
        )
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(DS.Space.md)
      Hairline()
      HStack(spacing: 0) {
        stepButton("minus", label: minusLabel ?? "Decrease \(title)", action: down)
        Rectangle().fill(DS.line).frame(width: DS.rule)
        stepButton("plus", label: plusLabel ?? "Increase \(title)", action: up)
      }
    }
    .panel(DS.paper)
    .accessibilityElement(children: .contain)
  }

  private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.body.weight(.heavy)).frame(
        maxWidth: .infinity, minHeight: DS.Size.control)
    }
    .foregroundStyle(DS.ink)
    .accessibilityLabel(label)
  }
}

/// Derived value (ratio, remaining stock): looks like a tile, takes no input.
struct ReadoutTile: View {
  let title: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
      Text(value).font(DS.Font.dataLarge).foregroundStyle(DS.ink).minimumScaleFactor(0.6).lineLimit(
        1)
      Text("CALCULATED").font(DS.Font.mono(.caption2)).foregroundStyle(DS.ink2).minimumScaleFactor(
        0.7
      ).lineLimit(1)
    }
    .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
    .panel(.clear, dash: [5, 3])
    .accessibilityElement(children: .combine)
  }
}

/// One of a row of mutually exclusive choices (taste verdict, method).
struct ChoiceButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title.dsTitle).font(DS.Font.din(20, relativeTo: .headline))
        .lineLimit(1).minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, minHeight: DS.Size.control)
        .foregroundStyle(isSelected ? DS.onSignal : DS.ink)
        .panel(isSelected ? DS.signal : DS.paper)
    }
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// The cup's rating out of 10 in steps of 0.1: a slider for speed, minus and plus for the
/// last tenth. 0 means not rated, so sliding to the left end clears it.
struct GradeScale: View {
  @Binding var tenths: Int
  @Environment(\.dynamicTypeSize) private var dts

  private var value: Binding<Double> {
    Binding(
      get: { Double(tenths) / 10 },
      set: { tenths = min(Rating.maxTenths, max(0, Int(($0 * 10).rounded()))) })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
        Text(tenths == 0 ? "Not rated" : Rating.text(tenths))
          .font(tenths == 0 ? .title3.weight(.semibold) : DS.Font.dataLarge)
          .foregroundStyle(tenths == 0 ? DS.ink2 : DS.ink)
          .contentTransition(.numericText())
        if tenths > 0 { Text("/ 10").font(DS.Font.mono(.callout)).foregroundStyle(DS.ink2) }
      }
      .accessibilityHidden(true)
      HStack(spacing: DS.Space.sm) {
        nudge("minus", by: -1).disabled(tenths == 0)
        Slider(value: value, in: 0...10, step: 0.1)
          .tint(DS.accent)
          .accessibilityHidden(true)
        nudge("plus", by: 1).disabled(tenths == Rating.maxTenths)
      }
      Text("Slide to rate this cup from 0 to 10.").font(.footnote).foregroundStyle(DS.ink2)
        .accessibilityHidden(true)
    }
    .sensoryFeedback(.selection, trigger: tenths / 10)
    .accessibilityElement()
    .accessibilityLabel("Rating")
    .accessibilityValue(tenths == 0 ? "Not rated" : "\(Rating.text(tenths)) of 10")
    .accessibilityAdjustableAction { dir in
      tenths = dir == .increment ? min(Rating.maxTenths, tenths + 1) : max(0, tenths - 1)
    }
  }

  private func nudge(_ symbol: String, by step: Int) -> some View {
    Button {
      tenths = min(Rating.maxTenths, max(0, tenths + step))
    } label: {
      Image(systemName: symbol).font(.body.weight(.bold)).foregroundStyle(DS.accent)
        .frame(width: DS.Size.minTap, height: DS.Size.minTap)
        .overlay(Circle().strokeBorder(DS.accent, lineWidth: 1.5))
    }
    .buttonRepeatBehavior(.enabled)
    .accessibilityHidden(true)
  }
}

/// Square grade chip for lists: signal block with the grade, or a dash.
struct GradeBadge: View {
  let tenths: Int
  var body: some View {
    Text(tenths == 0 ? "—" : Self.text(tenths))
      .font(DS.isBloom ? .system(.title2, design: .serif) : DS.Font.mono(.title3, .bold))
      .foregroundStyle(DS.isBloom ? DS.ink : DS.onSignal)
      .fixedSize().padding(.horizontal, DS.Space.sm)
      .frame(minWidth: DS.Size.minTap, minHeight: 32)
      .background(DS.isBloom ? .clear : DS.signal, ignoresSafeAreaEdges: [])
      .accessibilityLabel(tenths == 0 ? "Unrated" : "Rated \(Self.text(tenths)) of 10")
  }

  static func text(_ tenths: Int) -> String { Rating.text(tenths) }
}

// MARK: Notes

/// Kraft-paper label with a dashed edge: tuning notes, the tasting note field.
struct KraftNote<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content
      .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
      .panel(DS.paper, dash: [5, 3])
  }
}

// MARK: Feedback and state

/// Bottom toast with a single action (Undo). Destructive actions use this, not a confirm dialog.
struct SteelToast: View {
  let message: String
  let actionTitle: String
  let action: () -> Void
  @Environment(\.dynamicTypeSize) private var dts
  var body: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
      : AnyLayout(HStackLayout(spacing: DS.Space.lg))
    layout {
      Text(message).font(.subheadline.weight(.semibold)).lineLimit(dts.isAccessibilitySize ? 4 : 2)
      if !dts.isAccessibilitySize { Spacer(minLength: DS.Space.sm) }
      Button(actionTitle.dsTitle, action: action)
        .font(DS.Font.din(20, relativeTo: .headline)).foregroundStyle(DS.signalOnSteel)
        .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
    }
    .padding(.vertical, dts.isAccessibilitySize ? DS.Space.sm : 0)
    .foregroundStyle(DS.onSteel)
    .padding(.horizontal, DS.Space.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.steel)
    // `.contain`, not `.combine`: Undo must stay its own control for VoiceOver.
    .accessibilityElement(children: .contain)
  }
}

enum BannerKind { case error, offline, info }

/// Inline banner for save failures, offline queueing and notices. Always names the problem and the way out.
struct StateBanner: View {
  let kind: BannerKind
  let message: String
  var actionTitle: String?
  var action: (() -> Void)?
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    let stacked = dts.isAccessibilitySize
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      HStack(alignment: .top, spacing: DS.Space.md) {
        Image(
          systemName: kind == .error
            ? "exclamationmark.triangle.fill" : (kind == .offline ? "wifi.slash" : "info.circle")
        )
        .foregroundStyle(kind == .error ? DS.error : DS.ink).accessibilityHidden(true)
        Text(message).font(.callout.weight(.semibold)).foregroundStyle(
          kind == .error ? DS.error : DS.ink)
        if !stacked {
          Spacer(minLength: DS.Space.sm)
          actionButton
        }
      }
      if stacked { actionButton }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper, border: kind == .error ? DS.error : DS.line)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var actionButton: some View {
    if let actionTitle, let action {
      Button(actionTitle.dsTitle, action: action)
        .font(DS.Font.din(18, relativeTo: .headline)).foregroundStyle(DS.ink)
        .frame(minWidth: DS.Size.minTap, minHeight: DS.Size.minTap)
    }
  }
}

/// Empty list with the next action; never a bare blank screen.
struct EmptyState: View {
  let title: String
  let message: String
  var actionTitle: String?
  var action: (() -> Void)?
  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      Text(title.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
      Text(message).font(.body).foregroundStyle(DS.ink2)
      if let actionTitle, let action { SteelButton(title: actionTitle, action: action) }
    }
    .padding(DS.Space.xl).frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
  }
}

/// Loading placeholder shaped like a journal row. Static under Reduce Motion.
struct SkeletonRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dim = false
  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Rectangle().fill(DS.ink2.opacity(0.35)).frame(width: 180, height: 22)
      Rectangle().fill(DS.ink2.opacity(0.25)).frame(width: 240, height: 12)
      Rectangle().fill(DS.ink2.opacity(0.25)).frame(height: 12)
    }
    .padding(DS.Space.lg).frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.paper, ignoresSafeAreaEdges: [])
    .opacity(dim ? 0.55 : 1)
    .onAppear {
      if !reduceMotion { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dim = true } }
    }
    .accessibilityElement().accessibilityLabel("Loading")
  }
}

/// A pinned bottom bar steps aside while the keyboard is up, so it never floats
/// over the keyboard's Done bar or covers the field being typed in.
struct HiddenWhileTyping: ViewModifier {
  @State private var keyboardUp = false
  func body(content: Content) -> some View {
    VStack(spacing: 0) { if !keyboardUp { content } }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
      ) { _ in
        keyboardUp = true
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
      ) { _ in
        keyboardUp = false
      }
  }
}

extension View {
  func hiddenWhileTyping() -> some View { modifier(HiddenWhileTyping()) }
}
