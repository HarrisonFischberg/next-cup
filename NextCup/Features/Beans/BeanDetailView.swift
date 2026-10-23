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
        attributes
        if !bean.bagFlavorNotes.isEmpty { flavor }
        brews
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
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

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text(bean.name.uppercased()).font(DS.Font.display).foregroundStyle(DS.ink)
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
        Text("FLAVOR NOTES ON THE BAG").font(DS.Font.label).foregroundStyle(DS.onKraft)
        Text(bean.bagFlavorNotes.joined(separator: ", ")).font(DS.Font.note)
          .foregroundStyle(DS.onKraft)
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
        Text((brew.method?.name ?? "Brew").uppercased()).font(DS.Font.headline)
          .foregroundStyle(DS.ink)
        Text(brew.date.formatted(date: .abbreviated, time: .shortened))
          .font(.footnote).foregroundStyle(DS.ink2)
        Text("Used \(RecipeFormat.weight(grams, units))").font(DS.Font.mono(.footnote))
          .foregroundStyle(DS.ink2)
      }
      Spacer(minLength: DS.Space.sm)
      if let grade = brew.ratingHalfSteps, grade > 0 { GradeBadge(halfSteps: grade) }
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
