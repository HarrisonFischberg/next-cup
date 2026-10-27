import NextCupKit
import SwiftUI

/// The timer's moving picture: the method's brewer doing the current step. The kettle
/// tips during pours, the press plunges, the inverted press flips onto the mug, the
/// espresso gauge climbs and pulls, cold brew darkens. Everything it shows comes from
/// `BrewScene.frame`, so it always agrees with the timer. Reduce Motion keeps the
/// drawing and drops the movement. Decorative; the readout carries the values.
struct BrewSceneView: View {
  let kind: BrewSceneKind
  /// Which drawing the pour-over scene uses (cone, flat bed or iced).
  let glyph: BrewGlyph
  let frame: BrewSceneFrame
  let running: Bool

  @State private var motion = SceneMotion()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !running || reduceMotion)) { tl in
      Canvas { ctx, size in
        let s = min(size.width, size.height) / 200
        ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        motion.advance(toward: frame, at: tl.date, snap: reduceMotion)
        let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
        SceneArt(pen: Pen(ctx: ctx, ink: .current), m: motion, t: t).draw(kind, glyph)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// Eases each part toward the latest frame so one step flows into the next.
final class SceneMotion {
  var kettle = 0.0
  var kettleShown = 0.0
  var bed = 0.0
  var vessel = 0.0
  var drips = 0.0
  var lid = 0.0
  var plunger = 0.0
  var flip = 0.0
  var bubbles = 0.0
  var needle = -70.0
  var shot = 0.0
  var darkness = 0.0
  private var last: Date?

  func advance(toward f: BrewSceneFrame, at now: Date, snap: Bool) {
    let dt = last.map { min(0.1, max(0, now.timeIntervalSince($0))) } ?? 1
    let first = last == nil
    last = now
    let k = snap || first ? 1 : min(1, dt * 6)
    func ease(_ value: inout Double, _ target: Double, _ rate: Double = k) {
      value += (target - value) * rate
    }
    ease(&kettle, f.pouring ? 1 : 0)
    ease(&kettleShown, f.kettleShown ? 1 : 0)
    ease(&bed, f.bed)
    ease(&vessel, f.vessel)
    ease(&drips, f.dripping ? 1 : 0)
    ease(&lid, f.lidOn ? 1 : 0)
    ease(&plunger, f.plunger)
    ease(&flip, f.inverted ? 1 : 0, snap || first ? 1 : min(1, dt * 4))
    ease(&bubbles, f.steeping ? 1 : 0)
    let jitter = f.shot ? sin(now.timeIntervalSinceReferenceDate * 11) * 3 : 0
    let gauge = f.pressureBar >= 9 ? 62 + jitter : f.pressureBar > 0 ? -25 : -70
    ease(&needle, gauge, snap || first ? 1 : min(1, dt * 3))
    ease(&shot, f.shot ? 1 : 0)
    ease(&darkness, f.darkness)
  }
}

/// Draws one scene on a 200-point square.
private struct SceneArt {
  let pen: Pen
  let m: SceneMotion
  /// Seconds, for the parts that move on their own (water, drips, bubbles).
  let t: Double

  private var ctx: GraphicsContext { pen.ctx }

  func draw(_ kind: BrewSceneKind, _ glyph: BrewGlyph) {
    switch kind {
    case .pourOver: pourOver(glyph)
    case .switchable: switchable()
    case .press: press()
    case .inverted: inverted()
    case .espresso:
      var c = ctx
      c.translateBy(x: -10, y: -10)
      c.scaleBy(x: 2.2, y: 2.2)
      BrewArt.espressoMachine(
        Pen(ctx: c, ink: pen.ink), needle: m.needle, cup: m.vessel, shot: m.shot > 0.5, phase: t)
    case .cold: cold()
    case .still: still(glyph)
    }
  }

  /// The brewer's own drawing, filling with coffee as the schedule runs.
  private func still(_ glyph: BrewGlyph) {
    var c = ctx
    c.translateBy(x: 20, y: 20)
    c.scaleBy(x: 1.6, y: 1.6)
    let p = Pen(ctx: c, ink: pen.ink)
    switch glyph {
    case .moka: BrewArt.mokaPot(p, fill: m.vessel)
    case .aeroPress: BrewArt.aeroPress(p, fill: m.vessel)
    case .chemex: BrewArt.chemex(p, fill: m.vessel)
    case .dripMachine: BrewArt.dripMachine(p, fill: m.vessel)
    default: BrewArt.draw(glyph, p)
    }
  }

  // MARK: Scenes

  private func pourOver(_ glyph: BrewGlyph) {
    if glyph == .iced {
      let glass = Art.svg("M70 122 H130 L126 180 Q125.5 184 121 184 H79 Q74.5 184 74 180 Z")
      pen.glass(glass)
      level(in: glass, bottom: 184, height: 44, x: 66, width: 68)
      pen.ice(Art.cube(80, 150, 16, -12))
      pen.ice(Art.cube(102, 156, 15, 14))
      pen.ice(Art.cube(92, 134, 14, 8))
    } else {
      server(neckY: 118, neckHeight: 10)
    }
    var d = ctx
    d.translateBy(x: 25, y: 17.5)
    d.scaleBy(x: 1.5, y: 1.5)
    if glyph == .flat {
      BrewArt.flatDripper(Pen(ctx: d, ink: pen.ink), bed: m.bed)
    } else {
      BrewArt.coneDripper(Pen(ctx: d, ink: pen.ink), bed: m.bed)
    }
    drips(x: 100, y: 120, fall: glyph == .iced ? 30 : 34)
    kettle(x: 52, y: 27, scale: 1.3, streamEnd: 80)
  }

  private func switchable() {
    server(neckY: 120, neckHeight: 8)
    var d = ctx
    d.translateBy(x: 25, y: 6)
    d.scaleBy(x: 1.5, y: 1.5)
    BrewArt.switchableDripper(Pen(ctx: d, ink: pen.ink), bed: m.bed, lid: m.lid)
    drips(x: 100, y: 118, fall: 38)
    kettle(x: 50, y: 22, scale: 1.3, streamEnd: 70)
  }

  private func press() {
    var c = ctx
    c.translateBy(x: 8.2, y: 28)
    c.scaleBy(x: 1.8, y: 1.8)
    let p = Pen(ctx: c, ink: pen.ink)
    let beaker = Art.rect(31.5, 27, 33, 53.5, r: 2.5)
    p.glass(Art.rect(30, 26, 36, 56, r: 4))
    var inside = c
    inside.clip(to: beaker)
    let h = 37 * m.vessel
    inside.fill(Art.rect(31.5, 80.5 - h, 33, h), with: .color(pen.ink.coffee))
    if m.bubbles > 0.01 {
      for (i, x) in [38.0, 46, 54, 60].enumerated() {
        let f = ((t + Double(i) * 0.6) / 2.6).truncatingRemainder(dividingBy: 1)
        inside.fill(
          Art.circle(x, 74 - 26 * f, 1.3),
          with: .color(pen.ink.line.opacity(0.25 * m.bubbles * min(1, f * 5) * (1 - f))))
      }
    }
    p.line(Art.svg("M30 31 L25 28"))
    p.trimLine(Art.svg("M66 34 H71 Q75 34 75 38 V66 Q75 70 71 70 H66"))
    p.glass(Art.rect(28, 82, 40, 3.5, r: 1.5))
    guard m.lid > 0.01 else { return }
    var lid = c
    lid.opacity = m.lid
    let lp = Pen(ctx: lid, ink: pen.ink)
    lp.trim(Art.rect(27, 21, 42, 5, r: 2))
    var plunger = lid
    plunger.translateBy(x: 0, y: 28 * m.plunger)
    let pp = Pen(ctx: plunger, ink: pen.ink)
    pp.trim(Art.circle(48, -12, 3.5))
    pp.line(Art.svg("M48 -8.5 V42"))
    pp.trimLine(Art.svg("M32.5 42 H63.5"), 2.6)
    pp.thin(Art.svg("M34 44 H62"))
  }

  private func inverted() {
    if m.flip < 0.99 {
      var mug = ctx
      mug.opacity = 1 - m.flip
      let mp = Pen(ctx: mug, ink: pen.ink)
      let cup = Art.svg("M76 150 H124 V170 Q124 180 114 180 H86 Q76 180 76 170 Z")
      mp.glass(cup)
      var inside = mug
      inside.clip(
        to: Art.svg("M77.5 151 H122.5 V170 Q122.5 178.5 114 178.5 H86 Q77.5 178.5 77.5 170 Z"))
      let h = 24 * m.vessel
      inside.fill(Art.rect(76, 178.5 - h, 48, h), with: .color(pen.ink.coffee))
      mp.line(Art.svg("M124 156 H128 Q134 156 134 163 Q134 170 124 171"))
    }
    var g = ctx
    g.translateBy(x: 100, y: 97)
    g.rotate(by: .degrees(180 * m.flip))
    g.translateBy(x: -100, y: -97)
    let p = Pen(ctx: g, ink: pen.ink)
    p.glass(Art.rect(72, 134, 56, 5, r: 2))
    if m.lid > 0.01 {
      var cap = g
      cap.opacity = m.lid
      Pen(ctx: cap, ink: pen.ink).trim(Art.rect(80, 139, 40, 6, r: 2))
    }
    p.glass(Art.rect(82, 60, 36, 74, r: 2))
    let dy = 56 * m.plunger
    let top = 76 + dy
    let filled = (134 - top) * m.bed
    g.fill(Art.rect(83.5, 134 - filled, 33, filled), with: .color(pen.ink.coffee))
    p.thin(Art.svg("M86 82 H92 M86 96 H92 M86 110 H92 M86 124 H92"))
    var plunger = g
    plunger.translateBy(x: 0, y: dy)
    let pp = Pen(ctx: plunger, ink: pen.ink)
    pp.trim(Art.rect(74, 14, 52, 5, r: 2))
    pp.glass(Art.rect(85, 19, 30, 51, r: 1))
    pp.seal(Art.rect(84, 70, 32, 6, r: 1.5))
    // A curved arrow while it turns over.
    let turning = 4 * m.flip * (1 - m.flip)
    if turning > 0.05 {
      var arrow = ctx
      arrow.opacity = turning
      let ap = Pen(ctx: arrow, ink: pen.ink)
      ap.trimLine(Art.svg("M150 70 C172 76 172 124 150 130"), 2.4)
      ap.trimLine(Art.svg("M144 124 L150 131 L156 123"), 2.4)
    }
    kettle(x: 44, y: 24, scale: 1.2, streamEnd: 52)
  }

  private func cold() {
    // Night falls while it steeps: a moon and a few stars.
    let moon = Art.circle(160, 44, 12).subtracting(Art.circle(166, 39, 10))
    ctx.fill(moon, with: .color(pen.ink.trim.opacity(0.85)))
    for (i, star) in [(140.0, 26.0, 1.6), (176, 66, 1.3), (134, 48, 1.1)].enumerated() {
      let glow = 0.6 + 0.4 * sin(t * 2.1 + Double(i) * 2)
      ctx.fill(Art.circle(star.0, star.1, star.2), with: .color(pen.ink.trim.opacity(glow)))
    }
    var c = ctx
    c.translateBy(x: 0, y: 3)
    c.scaleBy(x: 2, y: 2)
    BrewArt.coldBrewJar(
      Pen(ctx: c, ink: pen.ink), strength: m.darkness, fill: m.bed, phase: t == 0 ? nil : t)
  }

  // MARK: Shared parts

  /// The glass server under a dripper, filled to the scene's vessel level.
  private func server(neckY: Double, neckHeight: Double) {
    let bulb = Art.svg("M80 128 C60 140 62 176 82 180 H118 C138 176 140 140 120 128 Z")
    pen.glass(Art.rect(79, neckY, 42, neckHeight, r: 2))
    pen.glass(bulb)
    level(in: bulb, bottom: 180, height: 40, x: 60, width: 80)
    pen.trimLine(Art.svg("M121 134 C141 132 142 162 126 167"), 3)
    pen.thin(Art.svg("M86 172 H114"))
  }

  private func level(in shape: Path, bottom: Double, height: Double, x: Double, width: Double) {
    var inside = ctx
    inside.clip(to: shape)
    let h = height * m.vessel
    inside.fill(Art.rect(x, bottom - h, width, h), with: .color(pen.ink.coffee))
  }

  private func drips(x: Double, y: Double, fall: Double) {
    guard m.drips > 0.01 else { return }
    for delay in [0, 0.37, 0.74] {
      let f = ((t + delay) / 1.1).truncatingRemainder(dividingBy: 1)
      let fade = f < 0.15 ? f / 0.15 : 1 - (f - 0.15) / 0.85
      ctx.fill(
        Art.circle(x, y + fall * f * f, 1.9),
        with: .color(pen.ink.coffee.opacity(m.drips * fade)))
    }
  }

  /// A gooseneck kettle at (x, y), mirrored to pour to its right. It tips as `m.kettle`
  /// goes to 1, and the stream runs from the spout tip to `streamEnd` on the centre line.
  private func kettle(x: Double, y: Double, scale s: Double, streamEnd: Double) {
    guard m.kettleShown > 0.01 else { return }
    var k = ctx
    k.opacity = m.kettleShown
    let angle = -38 * m.kettle
    let rad = angle * .pi / 180
    if m.kettle > 0.85 {
      let tx = -44 * cos(rad) + 22 * sin(rad)
      let ty = -44 * sin(rad) - 22 * cos(rad)
      let sx = x - s * tx
      let sy = y + s * ty
      var stream = Path()
      stream.move(to: CGPoint(x: sx, y: sy))
      stream.addQuadCurve(to: CGPoint(x: 100, y: streamEnd), control: CGPoint(x: sx + 5, y: sy + 3))
      k.stroke(
        stream, with: .color(pen.ink.line.opacity(0.75)),
        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [7, 5], dashPhase: -t * 26))
    }
    var body = k
    body.translateBy(x: x, y: y)
    body.scaleBy(x: -s, y: s)
    body.rotate(by: .degrees(angle))
    let kp = Pen(ctx: body, ink: pen.ink)
    kp.glass(
      Art.svg(
        "M-16 14 H16 Q20 14 19 10 L15 -10 Q14 -14 10 -14 H-10 Q-14 -14 -15 -10 L-19 10 Q-20 14 -16 14 Z"
      ))
    kp.trim(Art.svg("M-10 -14 Q0 -22 10 -14 Z"))
    kp.trim(Art.circle(0, -20.5, 2.4))
    kp.trimLine(Art.svg("M16 -10 C28 -10 28 10 17 10"), 3.5)
    kp.line(Art.svg("M-18 8 C-30 10 -32 -10 -34 -18 Q-36 -24 -44 -22"), 2.6)
  }
}
