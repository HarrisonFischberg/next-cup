import SwiftUI

// Shared pieces for the ten Liquid Glass looks (round 2). Each look lives in its own
// LookNN file and only supplies presentation; data, timer and validation stay in Shared/.
// Pick one with `-look <1...10>`; no flag runs the shipped Steel & Kraft concept.

struct LookRoot: View {
    private let look = ProcessInfo.processInfo.arguments
        .firstIndex(of: "-look").flatMap { i in
            ProcessInfo.processInfo.arguments.dropFirst(i + 1).first.flatMap(Int.init)
        }

    var body: some View {
        switch look {
        case 1: Look01()
        case 2: Look02()
        case 3: Look03()
        case 4: Look04()
        case 5: Look05()
        case 6: Look06()
        case 7: Look07()
        case 8: Look08()
        case 9: Look09()
        case 10: Look10()
        case 11: Look11()
        case 12: Look12()
        case 13: Look13()
        case 14: Look14()
        case 15: Look15()
        case 16: Look16()
        case 17: Look17()
        case 18: Look18()
        case 19: Look19()
        case 20: Look20()
        case 21: Look21()
        case 22: Look22()
        case 23: Look23()
        case 24: Look24()
        case 25: Look25()
        case 26: Look26()
        case 27: Look27()
        case 28: Look28()
        case 29: Look29()
        case 30: Look30()
        case 31: Look31()
        case 32: Look32()
        case 33: Look33()
        case 34: Look34()
        case 35: Look35()
        case 36: Look36()
        case 37: Look37()
        case 38: Look38()
        case 39: Look39()
        case 40: Look40()
        case 41: Look41()
        case 42: Look42()
        case 43: Look43()
        default: ConceptRoot()
        }
    }
}

extension Color {
    init(_ light: UInt32, _ dark: UInt32) { self.init(light: light, dark: dark) }
}

/// Liquid Glass on a control, in the look's shape and tint. Reduce Transparency swaps it
/// for a solid fill so the label keeps its contrast (ui-ux-pro-max: opaque fallback).
struct LookGlass<S: Shape>: ViewModifier {
    var tint: Color?
    var shape: S
    var fallback: Color
    var clear = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(tint ?? fallback, in: shape)
        } else {
            content.glassEffect((clear ? Glass.clear : .regular).tint(tint).interactive(), in: shape)
        }
    }
}

extension View {
    func lookGlass<S: Shape>(_ tint: Color?, in shape: S, fallback: Color, clear: Bool = false) -> some View {
        modifier(LookGlass(tint: tint, shape: shape, fallback: fallback, clear: clear))
    }
}

extension FlowModel {
    /// Screenshots freeze the clock mid-brew; show that as running so the sheet reads "Pause".
    var showsRunning: Bool { isRunning || (hasStarted && ProcessInfo.processInfo.arguments.contains("-elapsed")) }
    var primaryTitle: String { showsRunning ? "Pause" : (hasStarted ? "Resume" : "Start") }
}

/// The Recipes tab is not part of the sheets; every look reuses this plain launcher.
struct LookRecipe: View {
    let model: FlowModel
    var body: some View {
        List {
            Section(model.recipe.method) {
                Text(model.recipe.name).font(.title3.weight(.semibold))
                Button("Start brew") { model.showTimer = true }.frame(minHeight: 44)
            }
        }
        .navigationTitle("Recipes")
    }
}

/// Half-star rating as five tappable marks; VoiceOver gets one adjustable element.
struct LookRating: View {
    @Binding var halfSteps: Int
    var color: Color
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                let name = halfSteps >= i * 2 ? "star.fill" : (halfSteps == i * 2 - 1 ? "star.leadinghalf.filled" : "star")
                Image(systemName: name).font(.system(size: size)).foregroundStyle(color)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                    .onTapGesture { halfSteps = halfSteps == i * 2 ? i * 2 - 1 : i * 2 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue(Fmt.stars(halfSteps))
        .accessibilityAdjustableAction { dir in
            halfSteps = dir == .increment ? min(10, halfSteps + 1) : max(0, halfSteps - 1)
        }
    }
}

// MARK: Round 3 craft pieces (heyimjames final-5%, swiftui-microinteractions)

/// Press: scale to 0.96 on touch-down with a light haptic on the down edge only.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.16, bounce: 0), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new }
    }
}

/// Rows rise in once, 60 ms apart; Reduce Motion shows them in place.
struct Assemble: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.12).delay(0.08 + Double(min(index, 8)) * 0.06)) { shown = true }
            }
    }
}

extension View {
    func assemble(_ index: Int) -> some View { modifier(Assemble(index: index)) }
}

/// Shared sample beans with a colour each, for looks that show beans as artwork.
enum BeanArt {
    static func color(_ bean: String) -> Color {
        switch bean.split(separator: " ").first ?? "" {
        case "Kenya": Color(0xB23A2E, 0xD9574A)
        case "Ethiopia": Color(0xC7862B, 0xE3A447)
        case "Colombia": Color(0x2F6B4F, 0x4E9C76)
        case "Guatemala": Color(0x4B4A8C, 0x7473C2)
        default: Color(0x6B4A33, 0x9C7457)
        }
    }
    static func origin(_ bean: String) -> String { String(bean.split(separator: " ").first ?? "") }
}
