import SwiftUI

// The brewer drawings: line art on a 100-point square, one per built-in method plus a
// mug for methods the owner adds. Lines take the ink color, rims and handles take the
// style's accent, and coffee is always coffee. Drawn with Canvas, so they stay sharp
// at any size and follow every style without image files. Decorative: the method's
// name always sits beside or under the drawing.

enum BrewGlyph: String, CaseIterable, Sendable {
  case cone, flat, switchable, press, inverted, espresso, iced, coldBrew, cup

  /// `key` is the built-in method key from methods.json.
  init(methodKey key: String?) {
    switch key {
    case "cone-dripper": self = .cone
    case "flat-dripper": self = .flat
    case "switchable-dripper": self = .switchable
    case "press": self = .press
    case "inverted-press": self = .inverted
    case "espresso": self = .espresso
    case "iced-pour-over": self = .iced
    case "cold-brew": self = .coldBrew
    default: self = .cup
    }
  }

  /// Nudges each drawing so it sits optically centred in a medallion.
  fileprivate var dy: CGFloat {
    switch self {
    case .flat, .coldBrew: 1
    case .switchable: 4
    case .press: 2
    case .inverted: -1
    default: 0
    }
  }
}

extension BrewMethod {
  var glyph: BrewGlyph { BrewGlyph(methodKey: builtInKey) }

  /// The name under a drawing, where room is tight. VoiceOver still reads `name`.
  var shortName: String {
    name == "Switchable immersion dripper" ? "Switchable dripper" : name
  }
}

extension DS {
  /// Brewed coffee in the drawings: the same in every style.
  static let coffee = Color(P(0x5A3520, 0x6A4126))
}

// MARK: Drawing kit

/// Paths in drawing units. `svg` reads the absolute M L H V C Q Z subset, so the
/// drawings match the design mockups line for line.
enum Art {
  static func svg(_ d: String) -> Path {
    var path = Path()
    var tokens: [String] = []
    var number = ""
    for ch in d {
      if ch.isLetter {
        if !number.isEmpty { tokens.append(number) }
        number = ""
        tokens.append(String(ch))
      } else if ch == "-" && !number.isEmpty && !number.hasSuffix("e") {
        tokens.append(number)
        number = "-"
      } else if ch.isNumber || ch == "." || ch == "-" {
        number.append(ch)
      } else {
        if !number.isEmpty { tokens.append(number) }
        number = ""
      }
    }
    if !number.isEmpty { tokens.append(number) }

    var i = 0
    var command = "M"
    var current = CGPoint.zero
    func next() -> CGFloat {
      defer { i += 1 }
      return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0
    }
    func point() -> CGPoint { CGPoint(x: next(), y: next()) }
    while i < tokens.count {
      if let first = tokens[i].first, first.isLetter {
        command = tokens[i]
        i += 1
        if command == "Z" {
          path.closeSubpath()
          continue
        }
      }
      switch command {
      case "M":
        current = point()
        path.move(to: current)
        command = "L"
      case "L":
        current = point()
        path.addLine(to: current)
      case "H":
        current.x = next()
        path.addLine(to: current)
      case "V":
        current.y = next()
        path.addLine(to: current)
      case "C":
        let c1 = point()
        let c2 = point()
        current = point()
        path.addCurve(to: current, control1: c1, control2: c2)
      case "Q":
        let c = point()
        current = point()
        path.addQuadCurve(to: current, control: c)
      default:
        i += 1
      }
    }
    return path
  }

  static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
  }

  static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
  }

  static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
  }

  /// A rounded square turned `degrees` about its centre (ice cubes).
  static func cube(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ degrees: CGFloat) -> Path {
    let c = CGPoint(x: x + size / 2, y: y + size / 2)
    let turn = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: degrees * .pi / 180)
      .translatedBy(x: -c.x, y: -c.y)
    return rect(x, y, size, size, r: 2).applying(turn)
  }
}

/// Colors for one drawing.
struct GlyphInk {
  var line: Color
  var trim: Color
  var coffee: Color

  static var current: GlyphInk { GlyphInk(line: DS.ink, trim: DS.signal, coffee: DS.coffee) }
  /// The still drawings (method tiles, medallions) show empty brewers; only the timer's
  /// moving scene fills them with coffee.
  static var still: GlyphInk { GlyphInk(line: DS.ink, trim: DS.signal, coffee: .clear) }
}

/// The handful of strokes and fills every drawing is made from.
struct Pen {
  let ctx: GraphicsContext
  let ink: GlyphInk
  /// Dashes for every stroke this pen draws (the cold-brew filter).
  var dash: [CGFloat] = []

  private func style(_ width: CGFloat) -> StrokeStyle {
    StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
  }
  func line(_ p: Path, _ width: CGFloat = 2) {
    ctx.stroke(p, with: .color(ink.line), style: style(width))
  }
  /// Glass: a faint fill under the outline.
  func glass(_ p: Path) {
    ctx.fill(p, with: .color(ink.line.opacity(0.07)))
    line(p)
  }
  func thin(_ p: Path) {
    ctx.stroke(p, with: .color(ink.line.opacity(0.55)), style: style(1.1))
  }
  func coffee(_ p: Path, opacity: Double = 1) {
    ctx.fill(p, with: .color(ink.coffee.opacity(opacity)))
  }
  /// Rims, lids and collars: accent fill with a fine outline.
  func trim(_ p: Path) {
    ctx.fill(p, with: .color(ink.trim))
    line(p, 1.4)
  }
  /// Handles: a thick accent stroke.
  func trimLine(_ p: Path, _ width: CGFloat = 4) {
    ctx.stroke(p, with: .color(ink.trim), style: style(width))
  }
  /// The light line on top of the coffee.
  func crema(_ p: Path) {
    ctx.stroke(p, with: .color(ink.trim.opacity(0.7)), style: style(1.1))
  }
  func ice(_ p: Path) {
    ctx.fill(p, with: .color(ink.line.opacity(0.16)))
    line(p, 1.2)
  }
  func seal(_ p: Path) {
    ctx.fill(p, with: .color(ink.line.opacity(0.45)))
  }
}

// MARK: The drawings

enum BrewArt {
  static func draw(_ glyph: BrewGlyph, _ pen: Pen) {
    switch glyph {
    case .cone:
      coneDripper(pen)
      pen.glass(Art.ellipse(50, 70.5, 24, 3.5))
    case .flat:
      flatDripper(pen)
      pen.glass(Art.ellipse(50, 68, 24, 3.5))
    case .switchable: switchableDripper(pen)
    case .press: pressPot(pen)
    case .inverted: invertedPress(pen)
    case .espresso: espressoMachine(pen)
    case .iced: icedPourOver(pen)
    case .coldBrew: coldBrewJar(pen)
    case .cup: mug(pen)
    }
  }

  /// The cone dripper on its own; `bed` shows coffee in the filter (timer).
  static func coneDripper(_ pen: Pen, bed: Double = 0) {
    pen.trim(Art.rect(21, 27, 58, 5, r: 2))
    pen.glass(Art.svg("M23 32 H77 L56 63 H44 Z"))
    if bed > 0 { pen.coffee(Art.svg("M33.8 48 H66.2 L56 63 H44 Z"), opacity: bed) }
    pen.thin(Art.svg("M32 35 L46 60 M41 35 L48.5 60 M50 35 V60 M59 35 L51.5 60 M68 35 L54 60"))
    pen.line(Art.svg("M74.3 36 C90 34 90 55 63.5 52"))
    pen.glass(Art.rect(42, 63, 16, 4, r: 1))
  }

  static func flatDripper(_ pen: Pen, bed: Double = 0) {
    pen.trim(
      Art.svg(
        "M17 30 Q20.5 27 24 30 Q27.5 27 31 30 Q34.5 27 38 30 Q41.5 27 45 30 Q48.5 27 52 30 "
          + "Q55.5 27 59 30 Q62.5 27 66 30 Q69.5 27 73 30 Q76.5 27 80 30 H83 V35 H17 Z"))
    pen.glass(Art.svg("M20 35 H80 L64 60 H36 Z"))
    if bed > 0 { pen.coffee(Art.svg("M26.4 45 H73.6 L64 60 H36 Z"), opacity: bed) }
    var ribs = Path()
    for i in 0..<9 {
      ribs.move(to: CGPoint(x: 26 + 6 * CGFloat(i), y: 37))
      ribs.addLine(to: CGPoint(x: 38 + 3 * CGFloat(i), y: 58))
    }
    pen.thin(ribs)
    pen.line(Art.svg("M78 38 C93 37 93 58 67.2 55"))
    pen.glass(Art.rect(40, 60, 20, 4, r: 1))
  }

  /// `bed` is the steeping coffee; `lid` hides the lid while water goes in (timer).
  static func switchableDripper(_ pen: Pen, bed: Double = 1, lid: Double = 1) {
    if lid > 0 {
      var lidPen = pen
      lidPen.fade(lid)
      lidPen.trim(Art.svg("M27 27 Q50 18 73 27 Z"))
      lidPen.trim(Art.rect(46, 17, 8, 4, r: 1.5))
    }
    pen.glass(Art.svg("M24 29 H76 L62 60 H38 Z"))
    if bed > 0 {
      pen.coffee(Art.svg("M30.8 44 H69.2 L62 60 H38 Z"), opacity: bed)
      pen.crema(Art.svg("M30.8 44 H69.2"))
    }
    pen.thin(Art.svg("M35 31 L42.5 58 M45 31 L47.5 58 M55 31 L52.5 58 M65 31 L57.5 58"))
    pen.line(Art.svg("M73.3 35 C89 34 89 55 65.6 52"))
    pen.glass(Art.svg("M38 60 H62 L69 72 H31 Z"))
    pen.thin(Art.svg("M35 66 H65"))
    pen.glass(Art.rect(28, 72, 44, 3.5, r: 1.5))
  }

  private static func pressPot(_ pen: Pen) {
    pen.trim(Art.circle(48, 14, 3.5))
    pen.line(Art.svg("M48 17.5 V50"))
    pen.trim(Art.rect(27, 21, 42, 5, r: 2))
    pen.glass(Art.rect(30, 26, 36, 56, r: 4))
    pen.coffee(Art.svg("M31.5 50 H64.5 V78 Q64.5 80.5 62 80.5 H34 Q31.5 80.5 31.5 78 Z"))
    pen.trimLine(Art.svg("M32.5 51 H63.5"), 2.6)
    pen.line(Art.svg("M30 31 L25 28"))
    pen.trimLine(Art.svg("M66 34 H71 Q75 34 75 38 V66 Q75 70 71 70 H66"))
    pen.glass(Art.rect(28, 82, 40, 3.5, r: 1.5))
  }

  private static func invertedPress(_ pen: Pen) {
    pen.trim(Art.rect(33, 15, 34, 5, r: 1.5))
    pen.glass(Art.rect(29, 20, 42, 3.5, r: 1))
    pen.glass(Art.rect(35, 23.5, 30, 40, r: 1.5))
    pen.coffee(Art.rect(36.5, 27, 27, 21))
    pen.crema(Art.svg("M36.5 27 H63.5"))
    pen.thin(Art.svg("M38 33 H42 M38 39 H42 M38 45 H42"))
    pen.seal(Art.rect(36, 48, 28, 4, r: 1))
    pen.glass(Art.rect(38.5, 52, 23, 30, r: 1))
    pen.trim(Art.rect(31, 82, 38, 4, r: 1.5))
    // The flip arrow says "upside down" at a glance.
    pen.trimLine(Art.svg("M77 34 C86 34 91 41 91 48 C91 55 86 62 77 62"), 2)
    pen.trimLine(Art.svg("M73 58.5 L77 62.5 L80.5 58"), 2)
  }

  /// `needle` is the gauge angle in degrees (0 points straight up); `cup` fills the cup.
  static func espressoMachine(
    _ pen: Pen, needle: Double = 40, cup: Double = 1, shot: Bool = false, phase: Double = 0
  ) {
    pen.glass(Art.rect(16, 20, 68, 18, r: 4))
    pen.line(Art.circle(31, 29, 6))
    let a = needle * .pi / 180
    var hand = Path()
    hand.move(to: CGPoint(x: 31, y: 29))
    hand.addLine(to: CGPoint(x: 31 + 4.5 * sin(a), y: 29 - 4.5 * cos(a)))
    pen.trimLine(hand, 1.8)
    pen.trim(Art.circle(69, 29, 3))
    pen.thin(Art.svg("M47 26 H59 M47 31 H55"))
    pen.line(Art.svg("M21 38 V74 M79 38 V74"))
    pen.glass(Art.rect(40, 38, 20, 5, r: 1))
    pen.glass(Art.svg("M42 43 H58 L56.5 48 H43.5 Z"))
    pen.trimLine(Art.svg("M58 45.5 L76 48.5"), 4.5)
    if shot {
      pen.ctx.stroke(
        Art.svg("M48 48.5 V63 M52 48.5 V63"), with: .color(pen.ink.coffee),
        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3], dashPhase: -phase * 30))
    } else if cup >= 1 {
      pen.thin(Art.svg("M48 50 V59 M52 50 V59"))
    }
    pen.glass(Art.svg("M41 62 H59 L57 72 H43 Z"))
    if cup > 0 {
      let top = 71 - 6.5 * cup
      var drink = Path()
      drink.move(to: CGPoint(x: 42.3 + (71 - top) * 0.02, y: top))
      drink.addLine(to: CGPoint(x: 57.7 - (71 - top) * 0.02, y: top))
      drink.addLine(to: CGPoint(x: 56.4, y: 71))
      drink.addLine(to: CGPoint(x: 43.6, y: 71))
      drink.closeSubpath()
      pen.coffee(drink)
      pen.crema(Art.svg("M42.6 \(top) H57.4"))
    }
    pen.line(Art.svg("M59 64 C64.5 64 64.5 70 58 70"))
    pen.glass(Art.rect(14, 74, 72, 6, r: 2))
    pen.thin(Art.svg("M24 77 H76"))
  }

  private static func icedPourOver(_ pen: Pen) {
    pen.trim(Art.rect(28, 12, 44, 4, r: 1.5))
    pen.glass(Art.svg("M30 16 H70 L55 37 H45 Z"))
    pen.thin(Art.svg("M38 18 L47 35 M50 18 V35 M62 18 L53 35"))
    pen.glass(Art.rect(43, 37, 14, 3, r: 1))
    pen.glass(Art.svg("M32 41 H68 L65 85 Q64.8 88 62 88 H38 Q35.2 88 35 85 Z"))
    pen.coffee(Art.svg("M33.2 58 H66.8 L65.1 85 Q64.9 86.6 62 86.6 H38 Q35.1 86.6 34.9 85 Z"))
    pen.crema(Art.svg("M33.2 58 H66.8"))
    pen.ice(Art.cube(39, 64, 10, -12))
    pen.ice(Art.cube(51, 69, 9, 14))
    pen.ice(Art.cube(45, 50, 9, 8))
  }

  /// `strength` darkens the brew (timer); grounds drift down with `phase`.
  static func coldBrewJar(
    _ pen: Pen, strength: Double = 1, fill: Double = 1, phase: Double? = nil
  ) {
    pen.trim(Art.rect(44, 10, 12, 5, r: 1.5))
    pen.trim(Art.rect(33, 15, 34, 8, r: 2))
    pen.glass(Art.rect(30, 23, 40, 64, r: 6))
    if fill > 0 {
      let top = 85.5 - 45.5 * fill
      pen.coffee(
        Art.svg("M31.5 \(top) H68.5 V80.5 Q68.5 85.5 63.5 85.5 H36.5 Q31.5 85.5 31.5 80.5 Z"),
        opacity: 0.35 + 0.65 * strength)
      pen.crema(Art.svg("M31.5 \(top) H68.5"))
    }
    var mesh = pen
    mesh.dash = [2, 2.5]
    mesh.thin(Art.rect(44, 25, 12, 54, r: 2))
    if let phase {
      for (i, x) in [47.0, 50, 53, 48.5, 51.5].enumerated() {
        let p = (phase / 9 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
        pen.ctx.fill(
          Art.circle(x, 30 + 48 * p, 0.8), with: .color(pen.ink.line.opacity(0.35 * (1 - p))))
      }
    }
    pen.ice(Art.cube(34, 44, 9, -10))
    pen.ice(Art.cube(57, 47, 8, 12))
    pen.thin(Art.svg("M34 60 H37 M34 67 H37 M34 74 H37"))
  }

  private static func mug(_ pen: Pen) {
    pen.thin(Art.svg("M40 34 Q36 28 40 22 M48 34 Q44 28 48 22 M56 34 Q52 28 56 22"))
    pen.glass(Art.svg("M30 40 H66 V68 Q66 80 54 80 H42 Q30 80 30 68 Z"))
    pen.coffee(Art.svg("M31.5 47 H64.5 V68 Q64.5 78.5 54 78.5 H42 Q31.5 78.5 31.5 68 Z"))
    pen.crema(Art.svg("M31.5 47 H64.5"))
    pen.line(Art.svg("M66 46 H70 Q77 46 77 54 Q77 62 66 63"))
    pen.glass(Art.ellipse(48, 84, 24, 3))
  }
}

extension Pen {
  /// A copy that draws everything at `opacity`.
  fileprivate mutating func fade(_ opacity: Double) {
    var faded = ctx
    faded.opacity = opacity
    self = Pen(ctx: faded, ink: ink, dash: dash)
  }
}

// MARK: Views

/// One drawing, scaled to fit its frame.
struct BrewGlyphView: View {
  let glyph: BrewGlyph

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 100
      ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2 + glyph.dy * s)
      ctx.scaleBy(x: s, y: s)
      BrewArt.draw(glyph, Pen(ctx: ctx, ink: .still))
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// The drawing on its medallion: a soft disc in the round styles, a tile in the square
/// ones. Picked shows an accent ring and a check; dimmed fades the drawing.
struct BrewMedallion<Content: View>: View {
  var selected = false
  var dimmed = false
  @ViewBuilder var content: Content

  var body: some View {
    let shape = MedallionShape()
    content
      .padding(4)
      .opacity(dimmed ? 0.38 : 1)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(1, contentMode: .fit)
      .background {
        shape.fill(DS.paper)
          .overlay(
            shape.fill(
              EllipticalGradient(
                colors: [DS.ink.opacity(0.08), .clear], center: UnitPoint(x: 0.5, y: 0.18),
                startRadiusFraction: 0, endRadiusFraction: 0.75)))
      }
      .overlay(shape.strokeBorder(DS.ink.opacity(0.12), lineWidth: 1))
      .overlay {
        if selected {
          shape.inset(by: -4).strokeBorder(DS.signal, lineWidth: 2)
        }
      }
      .overlay(alignment: .topTrailing) {
        if selected {
          Image(systemName: "checkmark").font(.caption2.weight(.heavy))
            .foregroundStyle(DS.onSignal)
            .frame(width: 22, height: 22)
            .background(DS.signal, in: Circle())
            .overlay(Circle().strokeBorder(DS.bg, lineWidth: 2))
            .offset(x: 2, y: -2)
        }
      }
  }
}

extension BrewMedallion where Content == BrewGlyphView {
  init(_ glyph: BrewGlyph, selected: Bool = false, dimmed: Bool = false) {
    self.init(selected: selected, dimmed: dimmed) { BrewGlyphView(glyph: glyph) }
  }
}

/// A circle, or a rounded tile in the square-cornered styles.
struct MedallionShape: InsettableShape {
  var inset: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: inset, dy: inset)
    if DS.flavor.control == .square {
      return RoundedRectangle(cornerRadius: max(0, DS.radius + 4 - inset), style: .continuous)
        .path(in: r)
    }
    return Circle().path(in: r)
  }

  func inset(by amount: CGFloat) -> MedallionShape {
    var copy = self
    copy.inset += amount
    return copy
  }
}
