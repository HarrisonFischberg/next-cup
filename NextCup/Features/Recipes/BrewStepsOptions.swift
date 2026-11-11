import NextCupKit
import SwiftUI

/// One step as the Start brew screen shows it, already scaled to the cup being made.
struct BrewStepRow: Identifiable {
  let index: Int
  let step: RecipeStep
  let startS: Int
  let target: Double?
  var id: RecipeStep.ID { step.id }
  var time: String { RecipeFormat.clock(startS) }
  var name: String { RecipeFormat.title(step.kind) }
}

/// Design options for the Brew steps section (`-stepsLook 1|2|3`); 0 is the current strip.
enum BrewStepsLook {
  static var current: Int { UserDefaults.standard.integer(forKey: "stepsLook") }
}

/// Header shared by the options: title, a one-line summary and a quiet Edit.
private struct StepsHeader: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Brew steps".dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(summary).font(.footnote).foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      Button(action: onEdit) {
        Label("Edit", systemImage: "slider.horizontal.3")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, DS.Space.md).frame(minHeight: 36)
          .overlay(Capsule().strokeBorder(DS.line, lineWidth: 1))
          .contentShape(Capsule())
      }
      .buttonStyle(.plain).foregroundStyle(DS.ink)
      .frame(minHeight: DS.Size.minTap)
      .accessibilityLabel("Edit steps")
      .accessibilityHint("Add or change steps, with optional AI suggestions")
      .accessibilityIdentifier("recipe.steps.change")
    }
  }

  private var summary: String {
    var parts = ["\(rows.count) steps"]
    if let water = rows.compactMap(\.target).max() {
      parts.append(RecipeFormat.weight(water, units))
    }
    parts.append(RecipeFormat.clock(totalS))
    return parts.joined(separator: " · ")
  }
}

// MARK: 1 · Recipe card

/// A single card of numbered rows, Apple-list style. Time leads, the pour target sits in a
/// trailing pill, and the first line of the instruction is always there; tap to read it all.
struct StepsRecipeCard: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void
  @State private var open: RecipeStep.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      StepsHeader(rows: rows, totalS: totalS, units: units, onEdit: onEdit)
      VStack(spacing: 0) {
        ForEach(rows) { row in
          let expanded = open == row.id
          Button {
            withAnimation(.snappy(duration: 0.25)) { open = expanded ? nil : row.id }
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.md) {
              Text(row.time).font(DS.Font.mono(.subheadline, .semibold))
                .foregroundStyle(DS.accent).frame(width: 44, alignment: .leading)
              VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.body.weight(.semibold)).foregroundStyle(DS.ink)
                if !row.step.instruction.isEmpty {
                  Text(row.step.instruction).font(.subheadline).foregroundStyle(DS.ink2)
                    .lineLimit(expanded ? nil : 1)
                    .multilineTextAlignment(.leading)
                }
              }
              Spacer(minLength: DS.Space.sm)
              if let target = row.target {
                Text(RecipeFormat.weight(target, units))
                  .font(DS.Font.mono(.footnote, .bold)).foregroundStyle(DS.onSignal)
                  .padding(.horizontal, 10).padding(.vertical, 4)
                  .background(DS.signal, in: Capsule())
              }
            }
            .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          if row.index < rows.count - 1 {
            Rectangle().fill(DS.line.opacity(0.35)).frame(height: DS.hairline)
              .padding(.leading, DS.Space.lg + 44 + DS.Space.md)
          }
        }
      }
      .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }
    .padding(.horizontal, DS.Space.lg)
  }
}

// MARK: 2 · Pour curve

/// The water in the brewer over time, drawn as a stepped curve with a dot at each step.
/// The steps sit under it as a tight legend, so the whole brew reads as one shape.
struct StepsPourCurve: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void

  private var maxWater: Double { max(rows.compactMap(\.target).max() ?? 1, 1) }

  /// (seconds, grams) corners of the curve: flat while waiting, a ramp while pouring.
  private var points: [(Double, Double)] {
    var result: [(Double, Double)] = [(0, 0)]
    var water = 0.0
    for (i, row) in rows.enumerated() {
      let start = Double(row.startS)
      let end = Double(i + 1 < rows.count ? rows[i + 1].startS : totalS)
      result.append((start, water))
      if let target = row.target, target > water {
        // A pour takes most of its slot, at most 30 s.
        result.append((start + min(max(end - start, 1) * 0.8, 30), target))
        water = target
      }
    }
    result.append((Double(totalS), water))
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      StepsHeader(rows: rows, totalS: totalS, units: units, onEdit: onEdit)
      VStack(alignment: .leading, spacing: DS.Space.md) {
        chart.frame(height: 160)
        HStack {
          Text("0:00")
          Spacer()
          Text(RecipeFormat.clock(totalS))
        }
        .font(DS.Font.mono(.caption2)).foregroundStyle(DS.ink2)
        .accessibilityHidden(true)
        Rectangle().fill(DS.line.opacity(0.35)).frame(height: DS.hairline)
        VStack(spacing: DS.Space.sm) {
          ForEach(rows) { row in
            HStack(spacing: DS.Space.sm) {
              Text("\(row.index + 1)").font(DS.Font.mono(.caption, .bold))
                .foregroundStyle(DS.onSignal).frame(width: 22, height: 22)
                .background(DS.signal, in: Circle())
              Text(row.name).font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
              Spacer(minLength: DS.Space.sm)
              Text(
                [row.time, row.target.map { RecipeFormat.weight($0, units) }]
                  .compactMap { $0 }.joined(separator: "  →  ")
              )
              .font(DS.Font.mono(.subheadline)).foregroundStyle(DS.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(row.step.instruction)
          }
        }
      }
      .padding(DS.Space.lg)
      .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }
    .padding(.horizontal, DS.Space.lg)
  }

  private var chart: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height - 34
      let total = max(Double(totalS), 1)
      let pos = { (p: (Double, Double)) in
        CGPoint(x: w * p.0 / total, y: 6 + h * (1 - p.1 / maxWater))
      }
      let line = Path { path in
        for (i, p) in points.enumerated() {
          i == 0 ? path.move(to: pos(p)) : path.addLine(to: pos(p))
        }
      }
      ZStack(alignment: .topLeading) {
        // Fill under the curve.
        Path { path in
          path.addPath(line)
          path.addLine(to: CGPoint(x: w, y: h + 6))
          path.addLine(to: CGPoint(x: 0, y: h + 6))
          path.closeSubpath()
        }
        .fill(
          LinearGradient(
            colors: [DS.signal.opacity(0.35), DS.signal.opacity(0.02)],
            startPoint: .top, endPoint: .bottom))
        line.stroke(DS.signal, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        // Step numbers sit on the time axis, nudged apart where steps start together.
        let xs = rows.reduce(into: [CGFloat]()) { acc, row in
          let x = min(max(w * Double(row.startS) / total, 11), w - 11)
          acc.append(max(x, (acc.last ?? -100) + 24))
        }
        ForEach(rows) { row in
          Rectangle().fill(DS.line.opacity(0.4)).frame(width: 1, height: h + 6)
            .position(x: w * Double(row.startS) / total, y: (h + 6) / 2)
          Text("\(row.index + 1)").font(DS.Font.mono(.caption2, .bold))
            .foregroundStyle(DS.onSignal).frame(width: 22, height: 22)
            .background(DS.signal, in: Circle())
            .position(x: min(xs[row.index], w - 11), y: h + 20)
        }
      }
    }
    .accessibilityHidden(true)
  }
}

// MARK: 3 · Brew bar

/// One full-width bar split by how long each step lasts, like a run's splits. Tap a segment
/// to read that step; the first step is selected to start.
struct StepsBrewBar: View {
  let rows: [BrewStepRow]
  let totalS: Int
  let units: UnitPreferences
  let onEdit: () -> Void
  @State private var selected = 0

  private func duration(_ i: Int) -> Int {
    let end = i + 1 < rows.count ? rows[i + 1].startS : totalS
    return max(end - rows[i].startS, 0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.md) {
      StepsHeader(rows: rows, totalS: totalS, units: units, onEdit: onEdit)
      GeometryReader { geo in
        let gap: CGFloat = 4
        let usable = geo.size.width - gap * CGFloat(max(rows.count - 1, 0))
        // Every step keeps room for its number, even a 0 s one.
        let minW: CGFloat = 36
        let weights = rows.indices.map { Double(max(duration($0), 1)) }
        let sum = weights.reduce(0, +)
        let raw = weights.map { CGFloat($0 / sum) * usable }
        let short = raw.filter { $0 < minW }.count
        let spare = raw.filter { $0 >= minW }.reduce(0, +)
        let widths = raw.map {
          $0 < minW ? minW : $0 / max(spare, 1) * (usable - minW * CGFloat(short))
        }
        HStack(spacing: gap) {
          ForEach(rows) { row in
            let on = row.index == selected
            Button {
              withAnimation(.snappy(duration: 0.2)) { selected = row.index }
            } label: {
              Text("\(row.index + 1)").font(DS.Font.mono(.subheadline, .bold))
                .foregroundStyle(on ? DS.onSignal : DS.ink)
                .frame(width: widths[row.index], height: 52)
                .background(
                  on ? DS.signal : DS.paper,
                  in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Step \(row.index + 1), \(row.name)")
            .accessibilityAddTraits(on ? .isSelected : [])
          }
        }
      }
      .frame(height: 52)
      if rows.indices.contains(selected) {
        let row = rows[selected]
        VStack(alignment: .leading, spacing: DS.Space.sm) {
          HStack(alignment: .firstTextBaseline) {
            Text(row.name).font(DS.Font.headline).foregroundStyle(DS.ink)
            Spacer()
            Text("Step \(selected + 1) of \(rows.count)")
              .font(.footnote).foregroundStyle(DS.ink2)
          }
          HStack(spacing: DS.Space.xl) {
            figure("Starts", row.time)
            figure("Lasts", RecipeFormat.clock(duration(selected)))
            if let target = row.target { figure("Pour to", RecipeFormat.weight(target, units)) }
          }
          if !row.step.instruction.isEmpty {
            Text(row.step.instruction).font(.subheadline).foregroundStyle(DS.ink2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.paper, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        .id(selected)
        .transition(.opacity)
      }
    }
    .padding(.horizontal, DS.Space.lg)
  }

  private func figure(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(DS.ink2)
      Text(value).font(DS.Font.mono(.title3, .semibold)).foregroundStyle(DS.accent)
    }
  }
}
