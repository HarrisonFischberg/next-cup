import SwiftUI

// The redesign's page furniture (docs/design/handoff): a kicker over a big title, a
// labelled section rule, a colour block, and a labelled row. One layout for every
// flavor; the flavor sets the type, corners, colour and motion.

extension DS.Font {
  /// The page title on a tab root: big, in the flavor's display face.
  static var pageTitle: SwiftUI.Font {
    DS.flavor.caps
      ? din(56, relativeTo: .largeTitle) : DS.flavor.display(44, relativeTo: .largeTitle)
  }
  /// The current instruction on the brew screen.
  static var instruction: SwiftUI.Font {
    DS.flavor.caps ? din(40, relativeTo: .title) : DS.flavor.display(34, relativeTo: .title)
  }
}

/// "NEXT CUP" over "Brew", with room on the right for one action.
struct PageHeader<Trailing: View>: View {
  let title: String
  var kicker = "Next Cup"
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(alignment: .bottom, spacing: DS.Space.md) {
      VStack(alignment: .leading, spacing: 0) {
        Kicker(kicker)
        Text(title.dsTitle).font(DS.Font.pageTitle).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap).lineLimit(1).minimumScaleFactor(0.6)
          .accessibilityAddTraits(.isHeader)
      }
      Spacer(minLength: 0)
      trailing
    }
    .accessibilityElement(children: .contain)
  }
}

extension PageHeader where Trailing == EmptyView {
  init(_ title: String, kicker: String = "Next Cup") {
    self.init(title: title, kicker: kicker) { EmptyView() }
  }
}

/// Settings, from the top of every tab: a gear on the left of the page's add button.
/// `large` matches a page that draws its own round add button instead of a bar.
struct SettingsGear: View {
  let id: String
  var large = false

  var body: some View {
    NavigationLink(value: DeepLink.settings) {
      if large {
        Image(systemName: "gearshape").font(.title2.weight(.semibold)).foregroundStyle(DS.ink)
          .frame(width: 52, height: 52).background(DS.paper, in: Circle())
          .overlay(Circle().strokeBorder(DS.line.opacity(0.5)))
      } else {
        Image(systemName: "gearshape")
      }
    }
    .accessibilityLabel("Settings")
    .accessibilityIdentifier(id)
  }
}

/// Small tracked label in the accent: a kicker over a title, "03 / WAIT" over a step.
struct Kicker: View {
  let text: String
  var color = DS.accent
  init(_ text: String, color: Color = DS.accent) {
    self.text = text
    self.color = color
  }
  var body: some View {
    Text(text.uppercased()).font(DS.Font.label).tracking(1.2).foregroundStyle(color)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// A section heading on a rule, with an optional action on the right.
struct SectionRule<Trailing: View>: View {
  let title: String
  @ViewBuilder var trailing: Trailing

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Hairline().opacity(0.6)
      HStack(alignment: .firstTextBaseline) {
        Text(title.dsTitle).font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: DS.Space.sm)
        trailing
      }
    }
  }
}

extension SectionRule where Trailing == EmptyView {
  init(_ title: String) { self.init(title: title) { EmptyView() } }
}

/// A block of the flavor's second colour (butter, ivory, a midnight panel) behind
/// a hero or a group of rows.
struct ColorBlock: ViewModifier {
  var fill = DS.kraft
  func body(content: Content) -> some View {
    content.background(fill, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
  }
}

extension View {
  func colorBlock(_ fill: Color = DS.kraft) -> some View { modifier(ColorBlock(fill: fill)) }
}

/// A recipe's hero: the method's drawing on a disc of the screen colour, to sit on a block
/// of the look's second colour. Decorative: the name beside it carries the meaning.
struct BrewHero: View {
  let glyph: BrewGlyph
  var size: CGFloat = 148

  var body: some View {
    ZStack {
      Circle().fill(DS.bg)
      BrewGlyphView(glyph: glyph).padding(size * 0.06)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
