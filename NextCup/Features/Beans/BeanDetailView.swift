import NextCupKit
import SwiftData
import SwiftUI

/// Opens a bean by id. A link to a bean that no longer exists lands on a screen
/// that says so, never on a blank detail.
struct BeanDestination: View {
  let link: DeepLink
  let beanID: UUID
  @Environment(\.modelContext) private var context

  var body: some View {
    if let bean = try? Store(context: context).find(Bean.self, id: beanID) {
      BeanDetailView(bean: bean).background {
        Color.clear.accessibilityElement().accessibilityIdentifier(link.identifier)
      }
    } else {
      ScrollView {
        EmptyState(
          title: "Bean not found",
          message: "This bean is no longer in your library. It may have been deleted.")
      }
      .background(DS.bg)
      .navigationTitle(link.screenName)
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier(link.identifier)
    }
  }
}

/// S04: one bean. Where it is from, how fresh it is, how much is left (with a
/// manual correction), its status, and every brew that used it.
struct BeanDetailView: View {
  let bean: Bean

  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue
  @State private var editor: BeanEditorTarget?
  @State private var correcting = false
  @State private var correctionText = ""
  @State private var error: String?

  private var units: UnitPreferences {
    UnitPreferences(
      weight: WeightUnit(rawValue: weightUnit) ?? .grams,
      temperature: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
  }

  private var service: BeanService { BeanService(store: Store(context: context)) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.lg) {
        if let error {
          StateBanner(kind: .error, message: error, actionTitle: "Dismiss") { self.error = nil }
            .accessibilityIdentifier("bean.error")
        }
        header
        readouts
        if let trend { trendLine(trend) }
        BestSoFarCard(summary: bean.bestSoFar, units: units)
        attributes
        if !bean.bagFlavorNotes.isEmpty { flavor }
        freezer
        brews
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .safeAreaInset(edge: .bottom, spacing: 0) { brewBar }
    .navigationTitle(bean.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Edit") { editor = .edit(bean.id) }
          .accessibilityIdentifier("bean.edit")
      }
    }
    .sheet(item: $editor) { target in
      BeanEditorView(target: target) { editor = nil }
    }
    .alert("Correct the amount left", isPresented: $correcting) {
      TextField("Amount left", text: $correctionText).keyboardType(.decimalPad)
      Button("Cancel", role: .cancel) {}
      Button("Save", action: applyCorrection)
    } message: {
      Text(
        "Weigh the bag and enter what is left in \(units.weight == .grams ? "grams" : "ounces").")
    }
  }

  // MARK: Brew this bean

  /// The brew to repeat: the best graded one (newest on a tie), else the newest.
  private var bestBrew: Brew? {
    let used = (bean.brewUses ?? []).compactMap(\.brew)
    return used.max {
      ($0.ratingTenths ?? 0, $0.date) < ($1.ratingTenths ?? 0, $1.date)
    }
  }

  /// The screen's one primary action: brew with this bag, starting from what worked.
  private var brewBar: some View {
    Group {
      if let best = bestBrew {
        NavigationLink(value: DeepLink.brewAgain(best.id)) { brewLabel }
      } else {
        NavigationLink {
          BrewFormView(seed: nil, startingBean: bean)
        } label: {
          brewLabel
        }
      }
    }
    .buttonStyle(SteelButtonStyle())
    .accessibilityHint(
      bestBrew == nil ? "Opens a new brew with this bean" : "Starts from its best brew"
    )
    .accessibilityIdentifier("bean.brew")
    .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.md)
    .background(DS.bg, ignoresSafeAreaEdges: .bottom)
    .overlay(alignment: .top) { Hairline() }
  }

  private var brewLabel: some View {
    Text("Brew this bean".dsTitle).font(DS.Font.din(26, relativeTo: .title2)).tracking(1)
      .dynamicTypeSize(...DS.displayCap)
      .frame(maxWidth: .infinity, minHeight: DS.Size.primary)
  }

  // MARK: Dial-in trend

  /// First and latest grade of this bean's graded brews, oldest first. Needs two.
  private var trend: (first: Int, last: Int, count: Int)? {
    let graded = bean.brewSamples.filter { ($0.ratingTenths ?? 0) > 0 }.sorted {
      $0.date < $1.date
    }
    guard graded.count >= 2, let first = graded.first?.ratingTenths,
      let last = graded.last?.ratingTenths
    else { return nil }
    return (first, last, graded.count)
  }

  private func trendLine(_ trend: (first: Int, last: Int, count: Int)) -> some View {
    let grade = { (h: Int) in Rating.text(h) }
    return VStack(alignment: .leading, spacing: 2) {
      Text("DIAL-IN").font(DS.Font.label).foregroundStyle(DS.ink2)
      Text("Rating \(grade(trend.first)) → \(grade(trend.last)) over \(trend.count) brews")
        .font(DS.Font.mono(.title3, .bold)).foregroundStyle(DS.ink)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("bean.trend")
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text(bean.name.dsTitle).font(DS.Font.display).foregroundStyle(DS.ink)
        .accessibilityAddTraits(.isHeader)
      if !bean.subtitle.isEmpty {
        Text(bean.subtitle).font(.callout).foregroundStyle(DS.ink2)
      }
      HStack(spacing: DS.Space.sm) {
        Menu {
          Picker("Status", selection: statusBinding) {
            ForEach(BeanStatus.allCases, id: \.self) { Text($0.title).tag($0) }
          }
        } label: {
          HStack(spacing: DS.Space.xs) {
            Text("Status: \(bean.status.title)").font(.subheadline.weight(.semibold))
            Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold))
              .accessibilityHidden(true)
          }
          .foregroundStyle(DS.ink)
          .padding(.horizontal, DS.Space.md)
          .frame(minHeight: DS.Size.minTap)
          .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
        }
        .accessibilityLabel("Status")
        .accessibilityValue(bean.status.title)
        .accessibilityIdentifier("bean.status")
        if bean.isDecaf { Tag(text: "Decaf") }
      }
    }
  }

  private var statusBinding: Binding<BeanStatus> {
    Binding(
      get: { bean.status },
      set: { status in
        if case .failure(let failure) = service.setStatus(bean, status) { error = failure.message }
      })
  }

  private var readouts: some View {
    let layout =
      dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.md))
      : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
    return VStack(alignment: .leading, spacing: DS.Space.md) {
      layout {
        PaperBox {
          SpecCell(label: "Freshness", value: bean.freshness().title)
        }
        .accessibilityIdentifier("bean.freshness")
        PaperBox {
          SpecCell(label: "Since roast", value: ageText)
        }
      }
      PaperBox {
        VStack(alignment: .leading, spacing: 0) {
          SpecCell(label: "Left in the bag", value: remainingText)
            .accessibilityIdentifier("bean.remaining")
          Hairline()
          Button {
            correctionText =
              bean.remainingG.map {
                RecipeFormat.weight($0, units, withSymbol: false)
              } ?? ""
            correcting = true
          } label: {
            Text("CORRECT THE AMOUNT").font(DS.Font.label).foregroundStyle(DS.ink)
              .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
              .padding(.horizontal, DS.Space.md)
          }
          .disabled(bean.bagWeightG == nil)
          .accessibilityIdentifier("bean.correct")
        }
      }
      if bean.bagWeightG == nil {
        Text("Add the bag weight (Edit) to track how much is left.")
          .font(.footnote).foregroundStyle(DS.ink2)
      } else if bean.stockLevel == .low || bean.stockLevel == .empty {
        Text(bean.stockLevel == .empty ? "This bag is empty." : "This bag is running low.")
          .font(.footnote.weight(.semibold)).foregroundStyle(DS.error)
      }
    }
  }

  /// X6: a bag in the freezer stops aging. One freezer stay is kept per bag.
  private var freezer: some View {
    let stayedOnce = bean.frozenOn != nil && bean.thawedOn != nil
    return VStack(alignment: .leading, spacing: DS.Space.xs) {
      PaperBox {
        VStack(alignment: .leading, spacing: 0) {
          SpecCell(label: "Freezer", value: freezerText)
            .accessibilityIdentifier("bean.freezer")
          Hairline()
          Button {
            toggleFreezer()
          } label: {
            Text((bean.isFrozen ? "TAKE OUT OF THE FREEZER" : "PUT IN THE FREEZER"))
              .font(DS.Font.label).foregroundStyle(DS.ink)
              .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
              .padding(.horizontal, DS.Space.md)
          }
          .disabled(stayedOnce)
          .accessibilityIdentifier("bean.freezer.toggle")
        }
      }
      Text(
        stayedOnce
          ? "This bag has had its freezer stay. Frozen days were left out of its age."
          : "Days in the freezer do not count toward the bag's age."
      )
      .font(.footnote).foregroundStyle(DS.ink2)
    }
  }

  private var freezerText: String {
    guard let frozenOn = bean.frozenOn else { return "Not frozen" }
    let day = Date.FormatStyle().month(.abbreviated).day()
    let start = frozenOn.formatted(day)
    guard let thawedOn = bean.thawedOn else { return "Since \(start)" }
    return "\(start) to \(thawedOn.formatted(day))"
  }

  private func toggleFreezer() {
    let result = bean.isFrozen ? service.thaw(bean) : service.freeze(bean)
    if case .failure(let failure) = result { error = failure.message }
  }

  private var ageText: String {
    guard let age = bean.ageDays() else { return "—" }
    return age == 1 ? "1 day" : "\(age) days"
  }

  private var remainingText: String {
    guard let left = bean.remainingG, let bag = bean.bagWeightG else { return "—" }
    return "\(RecipeFormat.weight(left, units)) of \(RecipeFormat.weight(bag, units))"
  }

  private var attributes: some View {
    let rows: [(String, String?)] = [
      ("Country", bean.originCountry), ("Region", bean.region), ("Farm", bean.farm),
      ("Process", bean.process), ("Varietal", bean.varietal),
      ("Roast", bean.roastLevel?.title),
      ("Roasted on", bean.roastDate?.formatted(date: .abbreviated, time: .omitted)),
    ]
    let present = rows.compactMap { label, value in value.map { (label, $0) } }
    return Group {
      if !present.isEmpty {
        PaperBox {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(present.enumerated()), id: \.offset) { index, row in
              if index > 0 { Hairline() }
              SpecCell(label: row.0, value: row.1)
            }
          }
        }
      }
    }
  }

  private var flavor: some View {
    KraftNote {
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        Text("FLAVOR NOTES ON THE BAG").font(DS.Font.label).foregroundStyle(DS.ink)
        Text(bean.bagFlavorNotes.joined(separator: ", ")).font(DS.Font.note)
          .foregroundStyle(DS.ink)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var brews: some View {
    let uses = (bean.brewUses ?? []).compactMap { use in
      use.brew.map { (brew: $0, grams: use.grams) }
    }
    .sorted { $0.brew.date > $1.brew.date }
    return VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text("BREWS WITH THIS BEAN").font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      if uses.isEmpty {
        Text("No brew has used this bean yet.").font(.callout).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("bean.brews.empty")
      } else {
        PaperBox {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(uses.enumerated()), id: \.element.brew.id) { index, use in
              if index > 0 { Hairline() }
              NavigationLink(value: DeepLink.brew(use.brew.id)) {
                BrewUseRow(brew: use.brew, grams: use.grams, units: units)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("bean.brew.\(use.brew.id.uuidString)")
            }
          }
        }
      }
    }
  }

  // MARK: Actions

  private func applyCorrection() {
    let text = correctionText.replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    guard let value = Double(text) else {
      error = "The amount is not a number."
      return
    }
    switch service.setRemaining(bean, grams: units.grams(fromDisplayWeight: value)) {
    case .success: error = nil
    case .failure(let failure): error = failure.message
    }
  }
}

private struct BrewUseRow: View {
  let brew: Brew
  let grams: Double
  let units: UnitPreferences

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
      VStack(alignment: .leading, spacing: 2) {
        Text((brew.method?.name ?? "Brew").dsTitle).font(DS.Font.headline)
          .foregroundStyle(DS.ink)
        Text(brew.date.formatted(date: .abbreviated, time: .shortened))
          .font(.footnote).foregroundStyle(DS.ink2)
        Text("Used \(RecipeFormat.weight(grams, units))").font(DS.Font.mono(.footnote))
          .foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      if let grade = brew.ratingTenths, grade > 0 { GradeBadge(tenths: grade) }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
