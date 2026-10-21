import Foundation

enum SampleData {
    /// Fixed "today" so screenshots are stable.
    static let today = Date(timeIntervalSince1970: 1_792_000_000) // 2026-10-14-ish, midmorning UTC

    static let recipe = Recipe(
        name: "Cone dripper, bright and clean",
        method: "Cone dripper",
        credit: "Written for Next Cup",
        doseG: 20,
        waterG: 320,
        tempC: 94,
        totalS: 180,
        tuningNote: "Sour or thin: grind one step finer. Bitter or heavy: one step coarser.",
        steps: [
            RecipeStep(id: 0, kind: .bloom, startS: 0, cumulativeG: 60, instruction: "Wet every bit of the grounds. Pour to 60 g."),
            RecipeStep(id: 1, kind: .swirl, startS: 30, cumulativeG: nil, instruction: "Give the dripper one gentle swirl."),
            RecipeStep(id: 2, kind: .pour, startS: 45, cumulativeG: 160, instruction: "Pour in slow circles to 160 g."),
            RecipeStep(id: 3, kind: .pour, startS: 75, cumulativeG: 240, instruction: "Pour to 240 g, keep the water level steady."),
            RecipeStep(id: 4, kind: .pour, startS: 105, cumulativeG: 320, instruction: "Pour to 320 g and stop."),
            RecipeStep(id: 5, kind: .drawdown, startS: 135, cumulativeG: nil, instruction: "Let it drain. Done at about 3:00."),
        ]
    )

    static func entry(_ daysAgo: Int, _ bean: String, _ method: String, dose: Double, water: Double,
                      grind: Int, temp: Double, time: Int, stars: Int, _ verdict: Verdict, _ note: String) -> JournalEntry {
        JournalEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", daysAgo * 7 + stars))!,
            date: today.addingTimeInterval(-Double(daysAgo) * 86_400),
            bean: bean, method: method, doseG: dose, waterG: water, grind: grind, tempC: temp,
            timeS: time, ratingHalfSteps: stars, verdict: verdict, note: note)
    }

    static let journal: [JournalEntry] = [
        entry(1, "Kenya Kiambu AA", "Cone dripper", dose: 20, water: 320, grind: 23, temp: 94, time: 184, stars: 8, .balanced,
              "Blackcurrant and a stone-fruit finish. Clean."),
        entry(2, "Ethiopia Guji natural", "Cone dripper", dose: 18, water: 288, grind: 24, temp: 92, time: 170, stars: 7, .sour,
              "Bright, a little sharp at the end. Try one step finer."),
        entry(4, "Colombia Huila", "Immersion dripper", dose: 22, water: 330, grind: 20, temp: 96, time: 240, stars: 6, .bitter,
              "Heavy and a bit dry. Shorten the steep."),
        entry(5, "Kenya Kiambu AA", "Inverted press", dose: 15, water: 225, grind: 18, temp: 90, time: 120, stars: 9, .balanced,
              "Syrupy, cola and citrus. Best of the week."),
        entry(8, "Guatemala Antigua", "Cone dripper", dose: 20, water: 340, grind: 22, temp: 94, time: 195, stars: 5, .weak,
              "Thin. Use less water next time."),
        entry(9, "Ethiopia Guji natural", "Espresso", dose: 18, water: 36, grind: 9, temp: 93, time: 28, stars: 7, .strong,
              "36 g out in 28 s. Rich, slightly harsh."),
    ]
}
