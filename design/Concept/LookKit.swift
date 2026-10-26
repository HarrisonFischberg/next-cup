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
