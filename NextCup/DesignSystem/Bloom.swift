import SwiftUI

// Bloom's signature pieces: rings drawn from the brew's own numbers.
// Decorative; the numbers beside each ring carry the value for VoiceOver.

/// Bloom (and Daily, built on it) draw rings instead of steel panels.
extension DS {
  static var isBloom: Bool { [.bloom, .daily].contains(AppStyle.current) }
  /// The ring and progress colour. The handoff looks use their own accent, so no terracotta
  /// shows up where the owner asked for none.
  static var crema: Color {
    [.sundayStudio, .morningEdition, .steelBlue, .precisionAtelier].contains(AppStyle.current)
      ? accent : Color(P(0xB8652A, 0xE0A06A))
  }
  static let espresso = Color(P(0x4A2C1D, 0xD9C2AE))
  static let sage = Color(P(0x7C8C6A, 0xA9BC97))
  static let ringTrack = Color(P(0xEDE3D6, 0x2E241C))
}

/// Concentric rings, outermost first. Each fraction is clamped to 0...1.
struct BrewRings: View {
  let rings: [(fraction: Double, color: Color)]
  var width: CGFloat = 11

  var body: some View {
    ZStack {
      ForEach(Array(rings.enumerated()), id: \.offset) { index, ring in
        let inset = CGFloat(index) * (width + 9)
        Circle().stroke(DS.ringTrack, lineWidth: width).padding(inset + width / 2)
        Circle().trim(from: 0, to: min(1, max(0, ring.fraction)))
          .stroke(ring.color, style: StrokeStyle(lineWidth: width, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .padding(inset + width / 2)
      }
    }
    .accessibilityHidden(true)
  }
}

/// One day in the week strip: a coffee-ring mark, solid when a brew was logged.
struct CupMark: View {
  let filled: Bool
  var body: some View {
    Circle()
      .strokeBorder(
        filled ? DS.crema : DS.line.opacity(0.6),
        style: StrokeStyle(lineWidth: 3, dash: filled ? [] : [3, 4])
      )
      .background(Circle().fill(filled ? DS.crema.opacity(0.15) : .clear))
      .frame(width: 34, height: 34)
      .accessibilityHidden(true)
  }
}

/// A small ring leading a journal row, tinted by how the cup was graded.
struct RingGlyph: View {
  let color: Color
  var body: some View {
    ZStack {
      Circle().stroke(color, lineWidth: 5).padding(2.5)
      Circle().fill(color.opacity(0.18)).padding(12)
    }
    .frame(width: 38, height: 38)
    .accessibilityHidden(true)
  }
}

/// The timer's ring: progress, a dot at each step change, and a marker at now.
struct TimerRing: View {
  let fraction: Double
  let stepFractions: [Double]
  var color = DS.crema
  var track = DS.ringTrack

  var body: some View {
    GeometryReader { g in
      let size = min(g.size.width, g.size.height)
      let r = size / 2 - 9
      let center = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
      let point = { (f: Double) -> CGPoint in
        let a = (f * 360 - 90) * .pi / 180
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
      }
      ZStack {
        Circle().stroke(track, lineWidth: 14).frame(width: r * 2, height: r * 2)
        Circle().trim(from: 0, to: min(1, max(0, fraction)))
          .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
          .rotationEffect(.degrees(-90)).frame(width: r * 2, height: r * 2)
        ForEach(stepFractions.indices, id: \.self) { i in
          Circle().fill(stepFractions[i] <= fraction ? DS.paper : DS.ink2)
            .frame(width: 7, height: 7).position(point(stepFractions[i]))
        }
        Circle().fill(DS.paper).overlay(Circle().stroke(color, lineWidth: 4))
          .frame(width: 20, height: 20).position(point(min(1, max(0, fraction))))
      }
      .frame(width: g.size.width, height: g.size.height)
    }
    .accessibilityHidden(true)
  }
}
