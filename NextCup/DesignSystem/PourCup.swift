import SwiftUI

/// A cup that fills as the water goes in: the brew timer's picture of how far along the
/// pour is, with steam over it while what is in it is hot. Decorative; the instruction and
/// the countdown beside it carry the meaning.
/// The liquid and the steam are always the plain contrasting colour (`DS.liquid`, or
/// `DS.onField` on the field), never the second colour or a warm accent.
struct PourCup: View {
  /// 0...1 of the recipe's water poured so far.
  let fraction: Double
  var line = DS.ink
  var fill = DS.liquid
  /// How much steam rises, 0...1: none over an empty or cold cup, most right after a pour.
  var steam = 0.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 200
      ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
      ctx.scaleBy(x: s, y: s)
      let rim = CupSteam.rim
      let cup = Path(
        roundedRect: rim, cornerSize: CGSize(width: 28, height: 28), style: .continuous)
      // The liquid stands a little off the wall, so the cup still reads when both are
      // the same colour; a full cup stops short of the rim.
      let inside = rim.insetBy(dx: 10, dy: 10)
      let level = inside.maxY - inside.height * min(max(fraction, 0), 1) * 0.92
      ctx.drawLayer { layer in
        layer.clip(
          to: Path(
            roundedRect: inside, cornerSize: CGSize(width: 18, height: 18), style: .continuous))
        layer.fill(
          Path(CGRect(x: inside.minX, y: level, width: inside.width, height: inside.maxY - level)),
          with: .color(fill))
      }
      let ink = GraphicsContext.Shading.color(line)
      ctx.stroke(cup, with: ink, lineWidth: CupSteam.lineWidth)
      var handle = Path()
      handle.addArc(
        center: CGPoint(x: rim.maxX, y: rim.midY - 8), radius: 24, startAngle: .degrees(-72),
        endAngle: .degrees(72), clockwise: false)
      ctx.stroke(
        handle, with: ink, style: StrokeStyle(lineWidth: CupSteam.lineWidth, lineCap: .round))
      var saucer = Path()
      saucer.move(to: CGPoint(x: 12, y: 188))
      saucer.addLine(to: CGPoint(x: 188, y: 188))
      ctx.stroke(
        saucer, with: ink, style: StrokeStyle(lineWidth: CupSteam.lineWidth, lineCap: .round))
    }
    // Steam is drawn over the cup in the same square, so it never moves what is beside it.
    .overlay {
      CupSteam(color: fill, rising: steam > 0)
        .opacity(min(max(steam, 0), 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.6), value: steam)
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// Three wisps over the cup, in the cup's line weight: a slow drift up and a fade, on its
/// own clock so the timer's once-a-second redraw does not drive it. Reduce Motion shows
/// them standing still.
private struct CupSteam: View {
  /// The cup in the 200-point drawing both views share; the steam starts above its rim.
  static let rim = CGRect(x: 30, y: 66, width: 120, height: 110)
  static let lineWidth: CGFloat = 6

  let color: Color
  /// False stops the clock while there is nothing to draw.
  let rising: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date()

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !rising)) { timeline in
      Canvas { ctx, size in
        let s = min(size.width, size.height) / 200
        ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
        for wisp in 0..<3 {
          // Each wisp rises over five seconds, a third of a beat after the last.
          let phase =
            reduceMotion
            ? 0.5 : (t / 5 + Double(wisp) / 3).truncatingRemainder(dividingBy: 1)
          let x0 = Self.rim.midX - 26 + Double(wisp) * 26
          // A soft S, taller than it is wide, that sways a little as it climbs.
          var path = Path()
          for step in 0...16 {
            let k = Double(step) / 16
            let point = CGPoint(
              x: x0 + sin(k * 5.6 + phase * 1.5 + Double(wisp) * 2.1) * 6,
              y: Self.rim.minY - 10 - k * 36 - phase * 8)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
          }
          // In and out without a jump where the loop wraps.
          let strength = reduceMotion ? 0.8 : pow(sin(phase * .pi), 0.6)
          ctx.stroke(
            path, with: .color(color.opacity(strength)),
            style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

#Preview {
  PourCup(fraction: 0.4, steam: 1).frame(width: 180).padding()
}
