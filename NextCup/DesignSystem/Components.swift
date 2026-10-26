import SwiftUI

// Steel & Kraft components. Each is a primitive: no model types, so it can be
// reused by every screen. States: default, pressed, disabled, loading, error,
// empty. Every interactive component is at least 44 pt and carries its own
// accessibility label or traits. Gallery.swift shows each state.

// MARK: Rules

struct Hairline: View {
  var body: some View { Rectangle().fill(DS.line).frame(height: DS.rule) }
}

/// A filled, bordered surface in the flavor's corner radius. Sticker flavors add a hard
/// offset shadow in the accent (no blur), so the border and shadow carry state without color alone.
private struct Panel: ViewModifier {
  let fill: Color
  var border = DS.line
  var dash: [CGFloat] = []

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
    content
      .background(fill, in: shape)
      .overlay(
        shape.strokeBorder(border, style: StrokeStyle(lineWidth: DS.rule, dash: dash))
      )
      .background {
        if DS.flavor.control == .sticker { shape.fill(DS.signal).offset(x: 3, y: 3) }
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
    if let kind = DS.flavor.glass, !reduceTransparency {
      glass(configuration, kind, shape)
    } else {
      solid(configuration, shape)
    }
  }

  /// Glass looks: the primary is tinted with the accent, the secondary is plain glass.
  /// Interactive glass gives the press feedback. Reduce Transparency falls back to `solid`.
  private func glass(_ configuration: Configuration, _ kind: GlassKind, _ shape: RoundedRectangle)
    -> some View
  {
    // Clear glass shifts a tint toward full saturation, so the primary always uses regular.
    let base: Glass = kind == .clear && self.kind == .secondary ? .clear : .regular
    return configuration.label
      .foregroundStyle(self.kind == .primary ? DS.onSignal : DS.ink)
      .glassEffect(
        base.tint(self.kind == .primary ? DS.signal : nil).interactive(), in: shape
      )
      .opacity(enabled ? 1 : 0.4)
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
      }
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
    .padding(.horizontal, DS.Space.md).frame(minHeight: 32)
    .background(DS.isBloom ? .clear : DS.steel, ignoresSafeAreaEdges: [])
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
    .background(live ? DS.signal : DS.paper, ignoresSafeAreaEdges: [])
    .overlay(alignment: .bottom) {
      Rectangle().fill(DS.line.opacity(0.5)).frame(height: DS.hairline)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
          Text(value).font(DS.Font.dataLarge).minimumScaleFactor(0.6).lineLimit(1)
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

/// Grade 0.5 to 5 in one tap per whole grade, plus a half-step toggle. Replaces eight taps on a stepper.
struct GradeScale: View {
  @Binding var halfSteps: Int
  var body: some View {
    let whole = halfSteps / 2
    let isHalf = halfSteps % 2 == 1
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(spacing: 0) {
        ForEach(1...5, id: \.self) { i in
          let lit = i <= whole
          let halfLit = isHalf && i == whole + 1
          Button {
            halfSteps = halfSteps == i * 2 ? 0 : i * 2
          } label: {
            Text("\(i)").font(DS.Font.mono(.title3, .bold))
              .frame(maxWidth: .infinity, minHeight: DS.Size.control)
              .foregroundStyle(lit ? DS.onSignal : DS.ink)
              .background(
                lit ? DS.signal : (halfLit ? DS.signal.opacity(0.45) : DS.paper),
                ignoresSafeAreaEdges: []
              )
              .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.hairline))
          }
          .accessibilityHidden(true)
        }
      }
      .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
      Button {
        halfSteps = isHalf ? min(10, halfSteps + 1) : max(0, halfSteps - 1)
      } label: {
        Text(isHalf ? "MAKE IT A WHOLE" : "TAKE OFF A HALF").font(DS.Font.label)
          .foregroundStyle(DS.ink).frame(minHeight: DS.Size.minTap)
      }
      .disabled(halfSteps == 0)
      .accessibilityHidden(true)
    }
    .accessibilityElement()
    .accessibilityLabel("Grade")
    .accessibilityValue(halfSteps == 0 ? "Unrated" : "\(Double(halfSteps) / 2) of 5")
    .accessibilityAdjustableAction { dir in
      halfSteps = dir == .increment ? min(10, halfSteps + 1) : max(0, halfSteps - 1)
    }
  }
}

/// Square grade chip for lists: signal block with the grade, or a dash.
struct GradeBadge: View {
  let halfSteps: Int
  var body: some View {
    Text(
      halfSteps == 0
        ? "—"
        : (halfSteps % 2 == 0 ? "\(halfSteps / 2)" : String(format: "%.1f", Double(halfSteps) / 2))
    )
    .font(DS.isBloom ? .system(.title2, design: .serif) : DS.Font.mono(.title3, .bold))
    .foregroundStyle(DS.isBloom ? DS.ink : DS.onSignal)
    .fixedSize().padding(.horizontal, DS.Space.sm)
    .frame(minWidth: DS.Size.minTap, minHeight: 32)
    .background(DS.isBloom ? .clear : DS.signal, ignoresSafeAreaEdges: [])
    .accessibilityLabel(halfSteps == 0 ? "Unrated" : "Grade \(Double(halfSteps) / 2) of 5")
  }
}

// MARK: Notes

/// Kraft-paper label with a dashed edge: tuning notes, the tasting note field.
struct KraftNote<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content
      .padding(DS.Space.md).frame(maxWidth: .infinity, alignment: .leading)
      .panel(DS.kraft, dash: [5, 3])
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
