import SwiftData
import SwiftUI

/// The Nespresso easter egg: its one style, "Brew", opens this page instead of a setup.
/// Back takes the method off the Brew page; it stays in the Methods list.
struct NespressoJokeView: View {
  static let methodKey = "nespresso"

  let method: BrewMethod
  let onBack: () -> Void
  @Environment(\.modelContext) private var context
  @Query(filter: #Predicate<BrewMethod> { !$0.isHidden }) private var shownMethods: [BrewMethod]

  var body: some View {
    VStack(spacing: DS.Space.xl) {
      Spacer()
      BrewGlyphView(glyph: method.glyph).frame(width: 120, height: 120)
        .accessibilityHidden(true)
      Text("You've come to the wrong app, Mr. Bean").font(DS.Font.display)
        .foregroundStyle(DS.ink).multilineTextAlignment(.center)
        .dynamicTypeSize(...DS.displayCap).accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("nespresso.joke")
      Spacer()
      Button {
        goBack()
      } label: {
        Text("Back").frame(maxWidth: .infinity, minHeight: DS.Size.primary)
      }
      .buttonStyle(SteelButtonStyle())
      .accessibilityIdentifier("nespresso.back")
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.bg)
  }

  private func goBack() {
    // Never leave the Brew page with no methods, the same rule as the Methods list.
    if !method.isHidden && shownMethods.count > 1 {
      _ = MethodsService(store: Store(context: context)).setHidden(method, true)
    }
    onBack()
  }
}
