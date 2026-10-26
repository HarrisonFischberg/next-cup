/// Roast level as the starter recipes see it; raw values match the app's `RoastLevel`.
public enum StarterRoast: String, CaseIterable, Sendable {
  case ultraLight, light, mediumLight, medium, mediumDark, dark

  /// Three bands drive every number: light roasts get hotter water and longer
  /// contact, dark roasts the opposite.
  var band: Band {
    switch self {
    case .ultraLight, .light: .light
    case .mediumLight, .medium: .medium
    case .mediumDark, .dark: .dark
    }
  }

  enum Band: Int { case light, medium, dark }
}

/// Raw values match the app's `BrewStyle`.
public enum StarterStyle: String, CaseIterable, Sendable {
  case pourOver, immersion, espresso, cold
}

/// A step as the app stores it; `kind` is the raw value of the app's `StepKind`.
public struct StarterStep: Equatable, Sendable {
  public var kind: String
  public var startOffsetS: Int
  public var targetCumulativeWaterG: Double?
  public var instruction: String
}

/// One generated starting recipe. Next Cup's own, never the roaster's.
public struct StarterRecipe: Equatable, Sendable {
  public var style: StarterStyle
  /// The built-in method (`methods.json` key) the recipe is brewed with.
  public var methodKey: String
  public var name: String
  public var doseG: Double
  public var waterG: Double
  public var tempC: Double?
  public var totalTimeS: Int
  /// What the numbers were based on, and what to change first.
  public var note: String
  public var steps: [StarterStep]
}

/// Pure starting recipes from a coffee's roast level and process: one per brew style.
public enum StarterRecipes {
  public static func recipes(roast: StarterRoast?, process: String?) -> [StarterRecipe] {
    StarterStyle.allCases.map { recipe(style: $0, roast: roast, process: process) }
  }

  public static func recipe(style: StarterStyle, roast: StarterRoast?, process: String?)
    -> StarterRecipe
  {
    let band = (roast ?? .medium).band
    let i = band.rawValue
    let fermented = isFermented(process)
    // Fruit-forward processes taste harsh quickly when hot, so they start 1 °C cooler.
    let cooler = fermented ? 1.0 : 0

    var recipe: StarterRecipe
    switch style {
    case .pourOver:
      let dose = 20.0
      let water = (dose * [16.5, 16, 15.5][i]).rounded()
      recipe = StarterRecipe(
        style: style, methodKey: "cone-dripper", name: "Next Cup starting pour over",
        doseG: dose, waterG: water, tempC: [96.0, 93, 90][i] - cooler,
        totalTimeS: [210, 180, 165][i], note: "",
        steps: [
          step("bloom", 0, dose * 2, "Wet every ground with twice the dose in water; swirl once."),
          step("pour", 40, (water * 0.6).rounded(), "Pour in slow circles to 60% of the water."),
          step("pour", 85, water, "Pour the rest, keeping the bed level."),
          step("drawdown", 130, nil, "Let it drain. Finish by the end of the timer."),
        ])
    case .immersion:
      let dose = 20.0
      let water = (dose * [16.0, 15, 14][i]).rounded()
      let steep = [270, 240, 210][i]
      recipe = StarterRecipe(
        style: style, methodKey: "press", name: "Next Cup starting immersion",
        doseG: dose, waterG: water, tempC: [96.0, 93, 90][i] - cooler, totalTimeS: steep + 45,
        note: "",
        steps: [
          step("pour", 0, water, "Add all the water, wetting every ground."),
          step("stir", 30, nil, "Stir once to break the crust, then cover."),
          step("wait", 60, nil, "Let it steep undisturbed."),
          step("press", steep, nil, "Press slowly and pour at once."),
        ])
    case .espresso:
      let dose = 18.0
      let yield = [45.0, 36, 32][i]
      recipe = StarterRecipe(
        style: style, methodKey: "espresso", name: "Next Cup starting espresso",
        doseG: dose, waterG: yield, tempC: [95.0, 93, 90][i] - cooler,
        totalTimeS: [32, 28, 25][i], note: "",
        steps: [
          step(
            "pour", 0, yield, "Start the shot; stop when the cup reaches the yield on the scale.")
        ])
    case .cold:
      let dose = 60.0
      let water = dose * 10
      let steep = [57_600, 50_400, 43_200][i]
      recipe = StarterRecipe(
        style: style, methodKey: "cold-brew", name: "Next Cup starting cold brew",
        doseG: dose, waterG: water, tempC: nil, totalTimeS: steep,
        note: "",
        steps: [
          step("pour", 0, water, "Add cold water and wet every ground."),
          step("stir", 60, nil, "Stir, cover, and move it to the fridge."),
          step("wait", 300, nil, "Steep cold. Check back at the end of the timer."),
          step("drawdown", steep - 600, nil, "Filter the concentrate; dilute to taste."),
        ])
    }
    recipe.note = note(style: style, roast: roast, process: process)
    return recipe
  }

  private static func step(_ kind: String, _ offset: Int, _ target: Double?, _ text: String)
    -> StarterStep
  {
    StarterStep(
      kind: kind, startOffsetS: offset, targetCumulativeWaterG: target, instruction: text)
  }

  private static func isFermented(_ process: String?) -> Bool {
    guard let process = process?.lowercased() else { return false }
    return ["natural", "honey", "anaerobic", "carbonic"].contains { process.contains($0) }
  }

  private static func note(style: StarterStyle, roast: StarterRoast?, process: String?) -> String {
    let basis: String
    switch (roast, process) {
    case (let roast?, let process?): basis = "\(label(roast)) roast, \(process) process"
    case (let roast?, nil): basis = "\(label(roast)) roast"
    case (nil, _): basis = "no roast level listed, so a medium roast is assumed"
    }
    let fix =
      style == .cold
      ? "Too weak: use less water. Too harsh: steep shorter."
      : "Sour: grind finer or brew hotter. Bitter: grind coarser or cool the water."
    return "Next Cup's starting point from \(basis). \(fix)"
  }

  private static func label(_ roast: StarterRoast) -> String {
    switch roast {
    case .ultraLight: "Ultra-light"
    case .light: "Light"
    case .mediumLight: "Medium-light"
    case .medium: "Medium"
    case .mediumDark: "Medium-dark"
    case .dark: "Dark"
    }
  }
}
