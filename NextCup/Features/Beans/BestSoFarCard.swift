import NextCupKit
import SwiftUI

extension Bean {
  /// True from the day the bag goes into the freezer until it is taken out.
  var isFrozen: Bool { frozenOn != nil && thawedOn == nil }

  /// Every saved brew that used this bean, once each, as the plain values the
  /// best-so-far summary reads. A blend brew counts for each bean in it.
  var brewSamples: [BrewSample] {
    var seen = Set<UUID>()
    return (brewUses ?? []).compactMap(\.brew)
      .filter { !$0.isDraft && seen.insert($0.id).inserted }
      .map { brew in
        BrewSample(
          date: brew.date, ratingHalfSteps: brew.ratingHalfSteps, doseG: brew.doseG,
          waterG: brew.waterG, tempC: brew.tempC, totalTimeS: brew.totalTimeS,
          grindSetting: brew.grindSetting, grinder: brew.grinder?.name)
      }
  }

  var bestSoFar: BestSoFarSummary { BestSoFar.summarize(brewSamples) }
}

private func gradeText(_ halfSteps: Int) -> String {
  halfSteps % 2 == 0 ? "\(halfSteps / 2)" : String(format: "%.1f", Double(halfSteps) / 2)
}

/// X3: what has worked so far with one bean. How its grades are spread, the
/// settings of the best brew, and the grind used on each grinder at each dose.
struct BestSoFarCard: View {
  let summary: BestSoFarSummary
  let units: UnitPreferences

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("BEST SO FAR").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      if summary.brewCount == 0 {
        Text("Brew with this bean to see what works for it.")
          .font(.callout).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("bean.best.empty")
      } else {
        PaperBox {
          VStack(alignment: .leading, spacing: 0) {
            if let best = summary.best {
              bestSettings(best)
              Hairline()
              spread
            } else {
              Text(
                "Grade a brew with this bean to see its best settings and how its grades spread."
              )
              .font(.callout).foregroundStyle(DS.ink2).padding(DS.Space.md)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("bean.best.ungraded")
            }
            if !summary.grindHistory.isEmpty {
              Hairline()
              grindHistory
            }
          }
        }
        .accessibilityIdentifier("bean.best")
      }
    }
  }

  // MARK: Best settings

  private func bestSettings(_ best: BrewSample) -> some View {
    let rows: [(String, String)] = [
      ("Dose", best.doseG.map { RecipeFormat.weight($0, units) }),
      ("Water", best.waterG.map { RecipeFormat.weight($0, units) }),
      ("Temperature", best.tempC.map { RecipeFormat.temperature($0, units) }),
      ("Time", best.totalTimeS.map(RecipeFormat.clock)),
      ("Grind", best.grindSetting.flatMap { $0.isEmpty ? nil : $0 }),
      ("Grinder", best.grinder),
    ].compactMap { label, value in value.map { (label, $0) } }

    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(alignment: .center, spacing: DS.Space.sm) {
        GradeBadge(halfSteps: best.ratingHalfSteps ?? 0)
        VStack(alignment: .leading, spacing: 2) {
          Text("BEST BREW").font(DS.Font.label).foregroundStyle(DS.ink2)
          Text(best.date.formatted(date: .abbreviated, time: .omitted))
            .font(.footnote).foregroundStyle(DS.ink2)
        }
      }
      .accessibilityElement(children: .combine)
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .firstTextBaseline) {
          Text(row.0.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
          Spacer(minLength: DS.Space.sm)
          Text(row.1).font(DS.Font.data).foregroundStyle(DS.ink)
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("bean.best.settings")
  }

  // MARK: Spread

  private var spread: some View {
    let most = summary.spread.map(\.brews).max() ?? 1
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack {
        Text("GRADES").font(DS.Font.label).foregroundStyle(DS.ink2)
        Spacer(minLength: DS.Space.sm)
        if let average = summary.averageHalfSteps {
          Text("Average \(String(format: "%.1f", average / 2))")
            .font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
        }
      }
      ForEach(summary.spread.reversed(), id: \.halfSteps) { entry in
        HStack(spacing: DS.Space.sm) {
          Text(gradeText(entry.halfSteps)).font(DS.Font.data).foregroundStyle(DS.ink)
            .frame(minWidth: 36, alignment: .leading)
          GeometryReader { proxy in
            Rectangle().fill(DS.ink2)
              .frame(width: proxy.size.width * Double(entry.brews) / Double(most))
          }
          .frame(height: 12)
          Text("\(entry.brews)").font(DS.Font.data).foregroundStyle(DS.ink)
            .frame(minWidth: 28, alignment: .trailing)
        }
        .frame(minHeight: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "Grade \(gradeText(entry.halfSteps)), \(entry.brews) \(entry.brews == 1 ? "brew" : "brews")"
        )
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("bean.best.spread")
  }

  // MARK: Grind history

  private var grindHistory: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("GRIND BY GRINDER AND DOSE").font(DS.Font.label).foregroundStyle(DS.ink2)
      ForEach(Array(summary.grindHistory.enumerated()), id: \.offset) { _, entry in
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.grinder ?? "No grinder noted").font(.subheadline.weight(.semibold))
            .foregroundStyle(DS.ink)
          HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
            Text(entry.setting).font(DS.Font.data).foregroundStyle(DS.ink)
            Text(entry.doseG.map { "at \(RecipeFormat.weight($0, units))" } ?? "dose not noted")
              .font(DS.Font.mono(.footnote)).foregroundStyle(DS.ink2)
          }
          Text(detail(entry)).font(.footnote).foregroundStyle(DS.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("bean.best.grind")
  }

  private func detail(_ entry: GrindEntry) -> String {
    let count = "\(entry.brews) \(entry.brews == 1 ? "brew" : "brews")"
    guard let average = entry.averageHalfSteps else { return "\(count), not graded" }
    return "\(count), average grade \(String(format: "%.1f", average / 2))"
  }
}
