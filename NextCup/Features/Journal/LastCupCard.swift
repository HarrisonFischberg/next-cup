import NextCupKit
import SwiftUI

/// Bloom's journal header: the last cup as three rings (rating, time, ratio) with
/// the real numbers beneath, Brew again and Quick log, and this week's cup marks.
struct LastCupCard: View {
  let brew: Brew
  /// Days (start of day) in the last week that have at least one logged brew.
  let brewedDays: Set<Date>
  let brewAgain: () -> Void
  let quickLog: () -> Void

  private var ratio: Double? { BrewMath.ratio(doseG: brew.doseG, waterG: brew.waterG) }
  private var title: String { brew.beanNames.first ?? brew.method?.name ?? "Brew" }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.xl) {
      VStack(spacing: DS.Space.md) {
        Text("Last cup · \(brew.date.formatted(date: .omitted, time: .shortened))".uppercased())
          .font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(DS.ink2)
          .frame(maxWidth: .infinity, alignment: .leading)
        ZStack {
          BrewRings(rings: [
            (Double(brew.ratingHalfSteps ?? 0) / 10, DS.crema),
            // A 5-minute dial: long enough for pour over and immersion.
            (Double(brew.totalTimeS ?? 0) / 300, DS.espresso),
            // Ratio on a 1:10 to 1:20 dial.
            (((ratio ?? 10) - 10) / 10, DS.sage),
          ])
          VStack(spacing: 2) {
            Text(title).font(.system(.title3, design: .serif)).foregroundStyle(DS.ink)
              .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
              .fixedSize(horizontal: false, vertical: true)
            if let method = brew.method?.name, method != title {
              Text(method).font(.footnote).foregroundStyle(DS.ink2)
            }
          }
          .padding(54)
        }
        .frame(width: 220, height: 220)
        HStack {
          stat(
            brew.ratingHalfSteps.map { String(format: "%.1f", Double($0) / 2) }, "rating", DS.crema)
          stat(brew.totalTimeS.map(RecipeFormat.clock), "time", DS.espresso)
          stat(BrewMath.ratioLabel(ratio), "ratio", DS.sage)
        }
      }
      .padding(DS.Space.lg)
      .background(DS.paper, in: RoundedRectangle(cornerRadius: 32, style: .continuous))

      HStack(spacing: DS.Space.sm) {
        Button(action: brewAgain) {
          Label("Brew again", systemImage: "arrow.right").labelStyle(TrailingIcon())
            .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(DS.bg).background(DS.ink, in: Capsule())
        }
        .accessibilityIdentifier("journal.brewAgain")
        Button(action: quickLog) {
          Text("Quick log").font(.body.weight(.semibold)).padding(.horizontal, DS.Space.xl)
            .frame(minHeight: 54).foregroundStyle(DS.ink)
            .overlay(Capsule().strokeBorder(DS.line, lineWidth: 1))
        }
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: DS.Space.sm) {
        HStack(alignment: .firstTextBaseline) {
          Text("This week").font(.system(.title3, design: .serif)).foregroundStyle(DS.ink)
          Spacer()
          Text("\(brewedDays.count) of 7 days").font(.footnote).foregroundStyle(DS.ink2)
        }
        HStack(spacing: 0) {
          ForEach(week, id: \.self) { day in
            VStack(spacing: 6) {
              CupMark(filled: brewedDays.contains(day))
              Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption).foregroundStyle(
                DS.ink2)
            }
            .frame(maxWidth: .infinity)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brewed on \(brewedDays.count) of the last 7 days")
      }
    }
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
  }

  private var week: [Date] {
    let today = Calendar.current.startOfDay(for: .now)
    return (0..<7).reversed().compactMap {
      Calendar.current.date(byAdding: .day, value: -$0, to: today)
    }
  }

  private func stat(_ value: String?, _ name: String, _ color: Color) -> some View {
    VStack(spacing: 2) {
      Text(value ?? "–").font(.system(.title2, design: .serif)).foregroundStyle(DS.ink)
      HStack(spacing: 5) {
        Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
        Text(name).font(.footnote).foregroundStyle(DS.ink2)
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }

  /// Days of the last week with a logged brew, for `brewedDays`.
  static func brewedDays(_ brews: [Brew]) -> Set<Date> {
    let cal = Calendar.current
    guard let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now)) else {
      return []
    }
    return Set(brews.map { cal.startOfDay(for: $0.date) }.filter { $0 >= start })
  }
}

private struct TrailingIcon: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 8) {
      configuration.title
      configuration.icon.accessibilityHidden(true)
    }
  }
}
