import SwiftUI
import UIKit

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

/// A labelled row: a small icon, a label over its value, and whatever sits on the right.
struct LabeledRow<Trailing: View>: View {
  let symbol: String
  let label: String
  let value: String
  var valueColor = DS.ink
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: DS.Space.md) {
      Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(DS.accent)
        .frame(width: 28).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.footnote).foregroundStyle(DS.ink2)
        Text(value).font(DS.Font.headline).foregroundStyle(valueColor)
          .lineLimit(2).minimumScaleFactor(0.8)
      }
      Spacer(minLength: DS.Space.sm)
      trailing
    }
    .padding(DS.Space.md)
    .frame(maxWidth: .infinity, minHeight: DS.Size.primary, alignment: .leading)
  }
}

/// A big number with its label, for the calculated grid on the setup page.
struct Figure: View {
  let symbol: String
  let label: String
  let value: String
  var body: some View {
    HStack(alignment: .top, spacing: DS.Space.sm) {
      Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(DS.accent)
        .frame(width: 20).padding(.top, 3).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 0) {
        Text(label).font(.footnote).foregroundStyle(DS.ink2)
        Text(value).font(DS.Font.dataLarge).foregroundStyle(DS.ink)
          .minimumScaleFactor(0.6).lineLimit(1)
      }
    }
    .padding(.vertical, DS.Space.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Where a hero sits, which picks its photograph when the look has one.
enum HeroRole: String { case card, setup, brew }

/// A recipe's hero: the look's coffee photograph when the asset catalog has one
/// (`hero.<style>.<role>`), otherwise the method's drawing as a small still life with a
/// sun disc in the accent. Decorative: the name beside it carries the meaning.
struct BrewHero: View {
  let glyph: BrewGlyph
  var methodKey: String?
  var role: HeroRole = .card
  var size: CGFloat = 132

  private var photo: UIImage? { heroPhoto(methodKey: methodKey, role: role) }

  var body: some View {
    Group {
      if let photo {
        Image(uiImage: photo).resizable().scaledToFill()
          .frame(width: size, height: size).clipped()
          .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
      } else {
        ZStack {
          Circle().fill(DS.signal.opacity(0.9)).frame(width: size * 0.78, height: size * 0.78)
            .offset(x: -size * 0.18, y: -size * 0.1)
          RoundedRectangle(cornerRadius: size * 0.06, style: .continuous).fill(DS.paper)
            .frame(width: size * 0.3, height: size * 0.3)
            .offset(x: size * 0.36, y: size * 0.22)
          BrewGlyphView(glyph: glyph).frame(width: size * 0.82, height: size * 0.82)
            .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
      }
    }
    .accessibilityHidden(true)
  }
}

/// The brew method's photograph (`method.<key>`) when there is one, else the look's
/// hero for this slot (`hero.<style>.<role>`), else nil.
func heroPhoto(methodKey: String?, role: HeroRole) -> UIImage? {
  methodKey.flatMap { UIImage(named: "method.\($0)") }
    ?? UIImage(named: "hero.\(AppStyle.current.rawValue).\(role.rawValue)")
}

/// The hero photograph stretched across a card, when the look has one.
struct HeroBanner: View {
  var methodKey: String?
  var role: HeroRole = .card
  var height: CGFloat = 230
  var body: some View {
    if let photo = heroPhoto(methodKey: methodKey, role: role) {
      Image(uiImage: photo).resizable().scaledToFill()
        .frame(maxWidth: .infinity).frame(height: height).clipped()
        .accessibilityHidden(true)
    }
  }
}
