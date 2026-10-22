import Foundation

// Shared value types for the F01 brew-and-log flow. Sample data only; no real
// users, beans or roasters. Every concept imports this module and nothing else
// besides its own presentation code.

enum StepKind: String, CaseIterable, Sendable {
    case bloom, pour, wait, swirl, stir, drawdown

    var label: String {
        switch self {
        case .bloom: "Bloom"
        case .pour: "Pour"
        case .wait: "Wait"
        case .swirl: "Swirl"
        case .stir: "Stir"
        case .drawdown: "Drawdown"
        }
    }

    var symbol: String {
        switch self {
        case .bloom: "drop.fill"
        case .pour: "arrow.down.to.line"
        case .wait: "hourglass"
        case .swirl: "arrow.triangle.2.circlepath"
        case .stir: "scribble.variable"
        case .drawdown: "arrow.down.circle"
        }
    }
}

struct RecipeStep: Identifiable, Sendable, Equatable {
    let id: Int
    let kind: StepKind
    let startS: Int
    let cumulativeG: Int?
    let instruction: String
}

struct Recipe: Sendable, Equatable {
    let name: String
    let method: String
    let credit: String
    let doseG: Double
    let waterG: Double
    let tempC: Double
    let totalS: Int
    let tuningNote: String
    let steps: [RecipeStep]

    var ratioText: String { "1:\(Fmt.num(waterG / doseG))" }

    func endS(of step: RecipeStep) -> Int {
        guard let next = steps.first(where: { $0.startS > step.startS }) else { return totalS }
        return next.startS
    }
}

enum Verdict: String, CaseIterable, Identifiable, Sendable {
    case sour, bitter, weak, strong, balanced
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct JournalEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let date: Date
    let bean: String
    let method: String
    let doseG: Double
    let waterG: Double
    let grind: Int
    let tempC: Double
    let timeS: Int
    let ratingHalfSteps: Int
    let verdict: Verdict?
    let note: String

    var ratio: Double { waterG / doseG }
}

/// What the log form edits. Actual values are what is saved; recipe targets
/// are shown beside them, never locked.
struct BrewDraft: Sendable, Equatable {
    var bean = "Kenya Kiambu AA"
    var doseG: Double = 20
    var waterG: Double = 320
    var grind: Int = 22
    var tempC: Double = 94
    var timeS: Int = 180
    var ratingHalfSteps: Int = 0
    var verdict: Verdict?
    var notes = ""

    var ratio: Double? { doseG > 0 ? waterG / doseG : nil }

    /// The first thing wrong with the draft, in plain words, or nil.
    var problem: String? {
        if doseG <= 0 { return "Dose must be more than 0 g." }
        if waterG <= 0 { return "Water must be more than 0 g." }
        if tempC < 50 || tempC > 100 { return "Temperature must be between 50 and 100 °C." }
        if timeS <= 0 { return "Brew time must be more than 0 seconds." }
        return nil
    }

    var canSave: Bool { problem == nil }
}

enum Fmt {
    static func num(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func stars(_ halfSteps: Int) -> String {
        halfSteps == 0 ? "Unrated" : num(Double(halfSteps) / 2) + " of 5"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
