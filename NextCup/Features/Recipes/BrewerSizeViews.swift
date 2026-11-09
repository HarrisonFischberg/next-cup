import SwiftData
import SwiftUI

/// Asked the first time an AI recipe is made for a method with sizes: which one the user owns,
/// so the AI never writes more water than it holds. Skipping assumes the most common size.
struct BrewerSizeQuestion: View {
  let method: BrewMethod
  let done: () -> Void

  private var key: String { method.builtInKey ?? "" }

  var body: some View {
    let fallback = BrewerCapacity.defaultSize(for: key)
    NavigationStack {
      List {
        Section {
          ForEach(BrewerCapacity.sizes(for: key)) { size in
            Button {
              pick(size)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(size.name).font(DS.Font.headline).foregroundStyle(DS.ink)
                Text(BrewerSizeQuestion.holds(size, methodKey: key)).font(.footnote)
                  .foregroundStyle(DS.ink2)
              }
              .frame(maxWidth: .infinity, minHeight: DS.Size.control, alignment: .leading)
              .contentShape(Rectangle())
            }
            .accessibilityIdentifier("brewerSize.\(size.id)")
          }
        } header: {
          Text("Which size is your \(method.name.lowercased())?")
        } footer: {
          Text(
            "AI recipes are kept within what it holds, so it never overflows. Change it any "
              + "time in Settings > Brewer sizes.")
        }
        .listRowBackground(DS.paper)
        if let fallback {
          Section {
            Button("Not sure, use the \(fallback.name)") { pick(fallback) }
              .frame(minHeight: DS.Size.control)
              .accessibilityIdentifier("brewerSize.skip")
          } footer: {
            Text("The \(fallback.name) is the most common size.")
          }
          .listRowBackground(DS.paper)
        }
      }
      .scrollContentBackground(.hidden)
      .background(DS.bg)
      .navigationTitle("Brewer size")
      .navigationBarTitleDisplayMode(.inline)
    }
    .accessibilityIdentifier("brewerSize.question")
  }

  private func pick(_ size: BrewerSize) {
    BrewerCapacity.choose(size, for: key)
    UISelectionFeedbackGenerator().selectionChanged()
    done()
  }

  /// "Holds about 410 g closed, 480 g while pouring".
  static func holds(_ size: BrewerSize, methodKey: String) -> String {
    switch BrewerCapacity.methods[methodKey]?.kind {
    case .switchable:
      "Holds about \(BrewerFit.grams(size.heldG)) g closed, \(BrewerFit.grams(size.pourG)) g "
        + "while pouring"
    case .pourThrough: "Holds about \(BrewerFit.grams(size.pourG)) g at once"
    default: "Holds about \(BrewerFit.grams(size.heldG)) g"
    }
  }
}

/// Settings > Brewer sizes: the size of each brewer that has sizes.
struct BrewerSizesView: View {
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]

  var body: some View {
    Form {
      Section {
        ForEach(methods.filter { !BrewerCapacity.sizes(for: $0.builtInKey).isEmpty }) { method in
          BrewerSizePicker(method: method)
        }
      } footer: {
        Text(
          "AI recipes keep within what your brewer holds. A brewer you have not set uses its "
            + "most common size.")
      }
      .listRowBackground(DS.paper)
    }
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("Brewer sizes")
    .accessibilityIdentifier("settings.brewerSizes.list")
  }
}

private struct BrewerSizePicker: View {
  let method: BrewMethod
  @AppStorage private var sizeID: String

  init(method: BrewMethod) {
    self.method = method
    let key = method.builtInKey ?? ""
    _sizeID = AppStorage(
      wrappedValue: BrewerCapacity.defaultSize(for: key)?.id ?? "",
      BrewerCapacity.storageKey(key))
  }

  var body: some View {
    let key = method.builtInKey ?? ""
    Picker(method.name, selection: $sizeID) {
      ForEach(BrewerCapacity.sizes(for: key)) { size in
        Text(size.name).tag(size.id)
      }
    }
    .frame(minHeight: DS.Size.control)
    .accessibilityIdentifier("settings.brewerSize.\(key)")
  }
}

/// Under a recipe: "Fits your Hario Switch 03 (max ~410 g closed)" on an AI recipe, or a
/// warning on any recipe that would overfill the user's brewer. Nothing for brewers without
/// sizes.
struct BrewerFitLine: View {
  let draft: RecipeDraft
  let methodKey: String?
  let isAI: Bool

  var body: some View {
    if let fit = BrewerFit.current(methodKey) {
      if let overfill = fit.overfills(draft).first {
        StateBanner(kind: .error, message: fit.warning(overfill))
          .accessibilityIdentifier("recipe.fit.warning")
      } else if isAI {
        Label(fit.fitsLine, systemImage: "checkmark.circle")
          .font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("recipe.fit")
      }
    }
  }

  /// AI recipes are credited "AI, …" or named "… (AI)".
  static func isAI(name: String, credit: String?) -> Bool {
    credit?.hasPrefix("AI") == true || name.hasSuffix("(AI)")
  }
}
