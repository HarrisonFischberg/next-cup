import SwiftUI

/// Shown while Create with AI works: a cup fills with coffee and steam rises from it. The
/// coffee takes the look's accent, so it follows every palette. Reduce Motion shows the
/// full cup with still steam. Decorative; the caption beside it says what is happening.
struct BrewingCupView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date()

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { tl in
      Canvas { ctx, size in
        let s = min(size.width, size.height) / 200
        ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        let t = reduceMotion ? 0 : tl.date.timeIntervalSince(start)
        Self.draw(in: &ctx, t: t, still: reduceMotion)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }

  /// Draws on a 200-point square: cup from y 80 to 170, steam above it.
  private static func draw(in ctx: inout GraphicsContext, t: Double, still: Bool) {
    let rim = CGRect(x: 48, y: 80, width: 92, height: 90)
    let cup = Path(roundedRect: rim, cornerSize: CGSize(width: 18, height: 18), style: .continuous)
    // Fills over 4 s, holds, then empties quickly and brews again, every 7 s.
    let cycle = t.truncatingRemainder(dividingBy: 7)
    let fill =
      still
      ? 0.82
      : cycle < 4 ? 0.82 * ease(cycle / 4) : cycle < 6.4 ? 0.82 : 0.82 * (1 - (cycle - 6.4) / 0.6)
    let level = rim.maxY - rim.height * fill
    var coffee = Path()
    coffee.move(to: CGPoint(x: rim.minX, y: level))
    for x in stride(from: rim.minX, through: rim.maxX, by: 4) {
      coffee.addLine(to: CGPoint(x: x, y: level + sin(x / 9 + t * 3) * (still ? 0 : 1.6)))
    }
    coffee.addLine(to: CGPoint(x: rim.maxX, y: rim.maxY))
    coffee.addLine(to: CGPoint(x: rim.minX, y: rim.maxY))
    coffee.closeSubpath()
    ctx.drawLayer { layer in
      layer.clip(to: cup)
      layer.fill(coffee, with: .color(DS.accent.opacity(0.85)))
    }
    // A thin stream pours in while the cup fills.
    if !still, cycle < 4 {
      var stream = Path()
      stream.move(to: CGPoint(x: 94, y: 30))
      stream.addLine(to: CGPoint(x: 94, y: level))
      ctx.stroke(stream, with: .color(DS.accent.opacity(0.85)), lineWidth: 3)
    }
    let ink = GraphicsContext.Shading.color(DS.ink)
    ctx.stroke(cup, with: ink, lineWidth: 4)
    var handle = Path()
    handle.addArc(
      center: CGPoint(x: rim.maxX, y: 118), radius: 17, startAngle: .degrees(-70),
      endAngle: .degrees(70), clockwise: false)
    ctx.stroke(handle, with: ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
    var saucer = Path()
    saucer.move(to: CGPoint(x: 30, y: 180))
    saucer.addLine(to: CGPoint(x: 170, y: 180))
    ctx.stroke(saucer, with: ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
    // Three wisps rise from the coffee, sway and fade, each half a beat apart.
    for wisp in 0..<3 {
      let phase = still ? 0.45 : (t / 2.4 + Double(wisp) / 3).truncatingRemainder(dividingBy: 1)
      let x0 = 72 + Double(wisp) * 22
      var path = Path()
      for step in 0...12 {
        let k = Double(step) / 12
        let y = 74 - k * 46 - phase * 14
        let x = x0 + sin(k * 5 + phase * 6 + Double(wisp)) * 6
        if step == 0 {
          path.move(to: CGPoint(x: x, y: y))
        } else {
          path.addLine(to: CGPoint(x: x, y: y))
        }
      }
      let opacity = (still ? 0.6 : sin(phase * .pi)) * (fill / 0.82)
      ctx.stroke(
        path, with: .color(DS.ink2.opacity(opacity)),
        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
  }

  private static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

#Preview {
  BrewingCupView().frame(width: 180).padding()
}
