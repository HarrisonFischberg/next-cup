import SwiftUI

// Round 5 (Filtru + Beanconqueror): shared pieces for the clean looks 41...43.

/// Water in the cup at time t, poured evenly over the first 70% of each pour step.
func pouredGrams(_ r: Recipe, at t: Double) -> Double {
    var g = 0.0
    for st in r.steps where Double(st.startS) <= t {
        guard let target = st.cumulativeG else { continue }
        let span = Double(r.endS(of: st) - st.startS)
        g += (Double(target) - g) * min(1, (t - Double(st.startS)) / (span * 0.7))
    }
    return g
}

/// Filtru's scale gauge: a ring that fills toward this step's target, the live weight in the
/// middle, target and flow rate underneath a hairline.
struct ScaleGauge: View {
    let grams: Double
    let target: Int?
    let fraction: Double
    var tint: Color
    var track: Color
    var flow: Double = 3.5

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: 14)
            Circle().trim(from: 0, to: min(1, fraction)).stroke(tint, style: .init(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.spring(duration: 0.4), value: fraction)
            VStack(spacing: 10) {
                Text("\(Int(grams))g").font(.system(size: 64, weight: .light, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Rectangle().fill(.secondary.opacity(0.4)).frame(width: 150, height: 1)
                HStack(spacing: 36) {
                    VStack(spacing: 2) {
                        Text("TARGET").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                        Text(target.map { "\($0)g" } ?? "–").font(.subheadline.weight(.medium)).monospacedDigit()
                    }
                    VStack(spacing: 2) {
                        Text("FLOW").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                        Text("\(Fmt.num(flow)) g/s").font(.subheadline.weight(.medium)).monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement().accessibilityLabel("\(Int(grams)) grams poured\(target.map { ", target \($0) grams" } ?? "")")
    }
}

/// The brew methods as thin line icons in circles (Filtru's method grid).
enum MethodIcons {
    static let all: [(String, String)] = [("Cone", "drop"), ("Immersion", "cup.and.saucer"), ("Press", "cylinder"),
                                          ("Espresso", "cup.and.heat.waves"), ("Moka", "flame"), ("Cold brew", "snowflake")]
}
