#if DEBUG
  import SwiftUI

  // Shared drawings for the three design directions (branch design/explore, never shipped).

  /// One brew step as the design screens show it.
  struct DXStep: Identifiable {
    let id: Int
    let startS: Int
    let name: String
    /// Water on the scale by the end of the step, in grams; nil for a step that adds none.
    let targetG: Double?
    /// The same weight in the user's unit, "150 g".
    let target: String?
    let instruction: String
  }

  enum DXPour {
    /// A steady kettle, as `StepCue.pourGramsPerS`.
    static let gramsPerS = 5.0

    /// (seconds, grams) corners of the pour: each pour ramps at kettle speed, then holds.
    static func corners(_ steps: [DXStep], totalS: Int) -> [(t: Double, g: Double)] {
      var points: [(t: Double, g: Double)] = [(0, 0)]
      var water = 0.0
      for (index, step) in steps.enumerated() {
        let start = Double(step.startS)
        let end = Double(index + 1 < steps.count ? steps[index + 1].startS : totalS)
        points.append((start, water))
        if let target = step.targetG, target > water {
          points.append((min(start + (target - water) / gramsPerS, end), target))
          water = target
        }
      }
      points.append((Double(totalS), water))
      return points
    }

    /// Water that should be on the scale at `t`.
    static func grams(at t: Double, _ steps: [DXStep], totalS: Int) -> Double {
      let points = corners(steps, totalS: totalS)
      for (a, b) in zip(points, points.dropFirst()) where t <= b.t {
        return b.t > a.t ? a.g + (b.g - a.g) * (t - a.t) / (b.t - a.t) : b.g
      }
      return points.last?.g ?? 0
    }
  }

  /// Direction A's signature: the recipe as water on the scale over time. Before the brew it
  /// is the plan; during it the part already poured is filled and a marker rides the line.
  struct PourChart: View {
    let steps: [DXStep]
    let totalS: Int
    var elapsed: Double?

    var body: some View {
      Canvas { ctx, size in
        let corners = DXPour.corners(steps, totalS: totalS)
        let maxG = max(corners.map(\.g).max() ?? 1, 1)
        let plot = CGRect(x: 0, y: 22, width: size.width, height: size.height - 22 - 22)
        func point(_ t: Double, _ g: Double) -> CGPoint {
          CGPoint(
            x: plot.minX + plot.width * t / Double(max(totalS, 1)),
            y: plot.maxY - plot.height * g / maxG)
        }
        let grid = GraphicsContext.Shading.color(DS.line.opacity(0.28))
        // Graph paper: four rows, and a column wherever a step starts.
        for row in 0...4 {
          let y = plot.minY + plot.height * CGFloat(row) / 4
          var line = Path()
          line.move(to: CGPoint(x: plot.minX, y: y))
          line.addLine(to: CGPoint(x: plot.maxX, y: y))
          ctx.stroke(line, with: grid, lineWidth: row == 4 ? 1.5 : 0.5)
        }
        let label = Font.system(.caption, design: .monospaced, weight: .medium)
        for (index, step) in steps.enumerated() {
          let x = point(Double(step.startS), 0).x
          var line = Path()
          line.move(to: CGPoint(x: x, y: plot.minY))
          line.addLine(to: CGPoint(x: x, y: plot.maxY))
          ctx.stroke(line, with: grid, style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
          ctx.draw(
            Text(RecipeFormat.clock(step.startS)).font(label).foregroundStyle(DS.ink2),
            at: CGPoint(x: x, y: plot.maxY + 6), anchor: index == 0 ? .topLeading : .top)
        }
        ctx.draw(
          Text(RecipeFormat.clock(totalS)).font(label).foregroundStyle(DS.ink2),
          at: CGPoint(x: plot.maxX, y: plot.maxY + 6), anchor: .topTrailing)

        var curve = Path()
        curve.move(to: point(0, 0))
        for corner in corners.dropFirst() { curve.addLine(to: point(corner.t, corner.g)) }
        var area = curve
        area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        area.closeSubpath()
        let stroke = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        if let elapsed {
          // The plan ahead in grey, what is poured in the accent.
          ctx.stroke(curve, with: .color(DS.ink2.opacity(0.55)), style: stroke)
          let now = point(elapsed, DXPour.grams(at: elapsed, steps, totalS: totalS))
          ctx.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: 0, y: 0, width: now.x, height: size.height)))
            layer.fill(area, with: .color(DS.accent.opacity(0.16)))
            layer.stroke(curve, with: .color(DS.accent), style: stroke)
          }
          var marker = Path()
          marker.move(to: CGPoint(x: now.x, y: plot.minY))
          marker.addLine(to: CGPoint(x: now.x, y: plot.maxY))
          ctx.stroke(marker, with: .color(DS.accent), lineWidth: 1)
          let dot = CGRect(x: now.x - 7, y: now.y - 7, width: 14, height: 14)
          ctx.fill(Path(ellipseIn: dot), with: .color(DS.paper))
          ctx.stroke(Path(ellipseIn: dot), with: .color(DS.accent), lineWidth: 3)
        } else {
          ctx.fill(area, with: .color(DS.accent.opacity(0.1)))
          ctx.stroke(curve, with: .color(DS.accent), style: stroke)
        }
        // Each weight sits on its own plateau.
        var seen = 0.0
        for (index, step) in steps.enumerated() {
          guard let g = step.targetG, g > seen, let text = step.target else { continue }
          let end = Double(index + 1 < steps.count ? steps[index + 1].startS : totalS)
          let from = min(Double(step.startS) + (g - seen) / DXPour.gramsPerS, end)
          seen = g
          let reached = elapsed.map { $0 >= from } ?? true
          // On a short plateau the label hangs back over the ramp, clear of the next one.
          let wide = point(end, g).x - point(from, g).x > 64
          ctx.draw(
            Text(text).font(.system(.footnote, design: .monospaced, weight: .bold))
              .foregroundStyle(reached ? DS.ink : DS.ink2),
            at: CGPoint(
              x: point(wide ? from : end, g).x + (wide ? 2 : -4), y: point(from, g).y - 6),
            anchor: wide ? .bottomLeading : .bottomTrailing)
        }
      }
      .accessibilityElement()
      .accessibilityLabel("Pour plan")
      .accessibilityValue(
        steps.map { "\(RecipeFormat.clock($0.startS)) \($0.name)" }.joined(separator: ", "))
    }
  }

  /// Direction B's signature: a cup that fills as the water goes in.
  struct PourCup: View {
    /// 0...1 of the recipe's water poured so far.
    let fraction: Double
    var line = DS.ink
    var fill = DS.accent

    var body: some View {
      Canvas { ctx, size in
        let s = min(size.width, size.height) / 200
        ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        let rim = CGRect(x: 30, y: 34, width: 120, height: 132)
        let cup = Path(
          roundedRect: rim, cornerSize: CGSize(width: 30, height: 30), style: .continuous)
        let level = rim.maxY - rim.height * min(max(fraction, 0), 1) * 0.9
        ctx.drawLayer { layer in
          layer.clip(to: cup)
          layer.fill(
            Path(CGRect(x: rim.minX, y: level, width: rim.width, height: rim.maxY - level)),
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

  /// One bar per step, as wide as the step is long.
  struct DXSegments: View {
    let steps: [DXStep]
    let totalS: Int
    /// The step under way, and how far through it.
    let current: Int
    let fraction: Double
    var on = DS.accent
    var off = DS.line.opacity(0.35)
    var height: CGFloat = 6

    var body: some View {
      GeometryReader { g in
        let gap: CGFloat = 4
        let width = max(g.size.width - gap * CGFloat(steps.count - 1), 0)
        HStack(spacing: gap) {
          ForEach(steps) { step in
            let end = step.id + 1 < steps.count ? steps[step.id + 1].startS : totalS
            let share = CGFloat(end - step.startS) / CGFloat(max(totalS, 1))
            let fill = step.id < current ? 1 : step.id == current ? fraction : 0
            ZStack(alignment: .leading) {
              Capsule().fill(off)
              Capsule().fill(on).frame(width: width * share * fill)
            }
            .frame(width: width * share)
          }
        }
      }
      .frame(height: height)
      .accessibilityHidden(true)
    }
  }

  /// A flat filled button whose colours the screen picks, for the colour-field timer.
  struct DXFieldButton: ButtonStyle {
    let fill: Color
    let label: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .font(.system(.title2, design: .rounded, weight: .heavy))
        .foregroundStyle(label)
        .frame(maxWidth: .infinity, minHeight: DS.Size.primary)
        .background(fill, in: Capsule())
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
        .opacity(configuration.isPressed ? 0.85 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
  }

  /// Direction C's paper: a cream card with a soft edge.
  struct DXCard: ViewModifier {
    func body(content: Content) -> some View {
      content.background {
        RoundedRectangle(cornerRadius: DS.radius, style: .continuous).fill(DS.paper)
          .shadow(color: DS.ink.opacity(0.14), radius: 3, y: 1)
      }
    }
  }

  /// Direction C's rules: the pale blue line of an index card, and its one red header rule.
  enum DXCardRule {
    static let blue = Color(P(0xB9C9E6, 0x3A4668))
    static let red = Color(P(0xC9483C, 0xE08A7E))
  }

  struct DXRule: View {
    var color = DXCardRule.blue
    var body: some View { Rectangle().fill(color).frame(height: 1).accessibilityHidden(true) }
  }
#endif
