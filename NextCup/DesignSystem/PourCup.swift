import SwiftUI

/// A cup that fills as the water goes in: the brew timer's picture of how far along the
/// pour is. Decorative; the instruction and the countdown beside it carry the meaning.
/// The liquid is always the plain contrasting colour (`DS.liquid`, or `DS.onField` on the
/// field), never the second colour or a warm accent, so it cannot read as anything but a drink.
struct PourCup: View {
  /// 0...1 of the recipe's water poured so far.
  let fraction: Double
  var line = DS.ink
  var fill = DS.liquid

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 200
      ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
      ctx.scaleBy(x: s, y: s)
      let rim = CGRect(x: 30, y: 34, width: 120, height: 132)
      let cup = Path(
        roundedRect: rim, cornerSize: CGSize(width: 30, height: 30), style: .continuous)
      // The liquid stands a little off the wall, so the cup still reads when both are
      // the same colour; a full cup stops short of the rim.
      let inside = rim.insetBy(dx: 10, dy: 10)
      let level = inside.maxY - inside.height * min(max(fraction, 0), 1) * 0.92
      ctx.drawLayer { layer in
        layer.clip(
          to: Path(
            roundedRect: inside, cornerSize: CGSize(width: 20, height: 20), style: .continuous))
        layer.fill(
          Path(CGRect(x: inside.minX, y: level, width: inside.width, height: inside.maxY - level)),
          with: .color(fill))
      }
      let ink = GraphicsContext.Shading.color(line)
      ctx.stroke(cup, with: ink, lineWidth: 6)
      var handle = Path()
      handle.addArc(
        center: CGPoint(x: rim.maxX, y: 92), radius: 26, startAngle: .degrees(-72),
        endAngle: .degrees(72), clockwise: false)
      ctx.stroke(handle, with: ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
      var saucer = Path()
      saucer.move(to: CGPoint(x: 12, y: 182))
      saucer.addLine(to: CGPoint(x: 188, y: 182))
      ctx.stroke(saucer, with: ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

#Preview {
  PourCup(fraction: 0.4).frame(width: 180).padding()
}
