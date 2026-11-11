import Foundation

/// One size of a brewer and the most water it holds at once.
struct BrewerSize: Hashable, Identifiable {
  let id: String
  let name: String
  /// Most water in the brewer at once while it is held: valve closed, or steeping in a press,
  /// AeroPress, moka boiler, jar or reservoir.
  let heldG: Double
  /// Most water in the brewer at once while it drains: one pour on a cone, or a pour with a
  /// switchable dripper's valve open (hybrid).
  let pourG: Double
}

/// How each built-in method holds water, its sizes, and checks that keep a recipe inside them.
///
/// Sources and assumptions: makers' stated capacities (Hario Switch 02/03 and V60 01/02/03,
/// Clever Dripper S/L, Kalita Wave 155/185, Chemex 3/6/8/10-cup, Bodum French press 3/4/8/12-cup,
/// AeroPress Original/Go/XL, Bialetti Moka 1/3/6/9-cup) cut to what holds without spilling once
/// the coffee bed is in. Switch figures are measured: 03 about 410 g closed and 480 g hybrid, 02
/// about 240 g and 300 g. Cone figures are brim volume less the bed, rounded down. Jar and
/// drip-machine reservoirs are typical sizes. Every number errs small: splitting a pour that
/// would have fit costs a few seconds, an overfilled brewer spills hot water.
enum BrewerCapacity {
  enum Kind {
    /// Cones and flat beds: water drains as it is poured, so each pour must fit on its own.
    case pourThrough
    /// Valve closed holds everything poured until it opens; open, it acts as a cone.
    case switchable
    /// Every gram poured stays until the brew ends (press, AeroPress, moka, jar, reservoir).
    case immersion
  }

  struct Method {
    let kind: Kind
    let sizes: [BrewerSize]
    /// The most common size, assumed until the user picks one.
    let defaultID: String
  }

  private static let cones = [
    BrewerSize(id: "v60-01", name: "V60 01 size", heldG: 220, pourG: 220),
    BrewerSize(id: "v60-02", name: "V60 02 size", heldG: 360, pourG: 360),
    BrewerSize(id: "v60-03", name: "V60 03 size", heldG: 500, pourG: 500),
  ]
  private static let aeropress = [
    BrewerSize(id: "aeropress-go", name: "AeroPress Go", heldG: 200, pourG: 200),
    BrewerSize(id: "aeropress", name: "AeroPress Original", heldG: 240, pourG: 240),
    BrewerSize(id: "aeropress-xl", name: "AeroPress XL", heldG: 500, pourG: 500),
  ]

  /// Keyed by `BrewMethod.builtInKey`. Espresso and Nespresso hold no poured water. A method the
  /// user made has no key, so it gets no size and no check.
  static let methods: [String: Method] = [
    "cone-dripper": Method(kind: .pourThrough, sizes: cones, defaultID: "v60-02"),
    "iced-pour-over": Method(kind: .pourThrough, sizes: cones, defaultID: "v60-02"),
    "flat-dripper": Method(
      kind: .pourThrough,
      sizes: [
        BrewerSize(id: "wave-155", name: "Kalita Wave 155", heldG: 220, pourG: 220),
        BrewerSize(id: "wave-185", name: "Kalita Wave 185", heldG: 400, pourG: 400),
      ], defaultID: "wave-185"),
    "chemex": Method(
      kind: .pourThrough,
      sizes: [
        BrewerSize(id: "chemex-3", name: "Chemex 3-cup", heldG: 300, pourG: 300),
        BrewerSize(id: "chemex-6", name: "Chemex 6-cup", heldG: 550, pourG: 550),
        BrewerSize(id: "chemex-8", name: "Chemex 8-cup", heldG: 650, pourG: 650),
        BrewerSize(id: "chemex-10", name: "Chemex 10-cup", heldG: 750, pourG: 750),
      ], defaultID: "chemex-6"),
    "switchable-dripper": Method(
      kind: .switchable,
      sizes: [
        BrewerSize(id: "switch-02", name: "Hario Switch 02", heldG: 240, pourG: 300),
        BrewerSize(id: "switch-03", name: "Hario Switch 03", heldG: 410, pourG: 480),
        BrewerSize(id: "clever-s", name: "Clever Dripper S", heldG: 250, pourG: 300),
        BrewerSize(id: "clever-l", name: "Clever Dripper L", heldG: 450, pourG: 500),
      ], defaultID: "switch-03"),
    "press": Method(
      kind: .immersion,
      sizes: [
        BrewerSize(id: "press-3", name: "3-cup press (350 ml)", heldG: 300, pourG: 300),
        BrewerSize(id: "press-4", name: "4-cup press (500 ml)", heldG: 430, pourG: 430),
        BrewerSize(id: "press-8", name: "8-cup press (1 L)", heldG: 850, pourG: 850),
        BrewerSize(id: "press-12", name: "12-cup press (1.5 L)", heldG: 1_300, pourG: 1_300),
      ], defaultID: "press-8"),
    "aeropress": Method(kind: .immersion, sizes: aeropress, defaultID: "aeropress"),
    "inverted-press": Method(kind: .immersion, sizes: aeropress, defaultID: "aeropress"),
    "moka-pot": Method(
      kind: .immersion,
      sizes: [
        BrewerSize(id: "moka-1", name: "1-cup moka pot", heldG: 50, pourG: 50),
        BrewerSize(id: "moka-3", name: "3-cup moka pot", heldG: 130, pourG: 130),
        BrewerSize(id: "moka-6", name: "6-cup moka pot", heldG: 280, pourG: 280),
        BrewerSize(id: "moka-9", name: "9-cup moka pot", heldG: 450, pourG: 450),
      ], defaultID: "moka-3"),
    "cold-brew": Method(
      kind: .immersion,
      sizes: [
        BrewerSize(id: "jar-1l", name: "1 L jar", heldG: 900, pourG: 900),
        BrewerSize(id: "jar-2l", name: "2 L jar", heldG: 1_800, pourG: 1_800),
      ], defaultID: "jar-1l"),
    "drip-machine": Method(
      kind: .immersion,
      sizes: [
        BrewerSize(id: "drip-5", name: "5-cup machine", heldG: 650, pourG: 650),
        BrewerSize(id: "drip-8", name: "8-cup machine", heldG: 1_000, pourG: 1_000),
        BrewerSize(id: "drip-10", name: "10-cup machine", heldG: 1_250, pourG: 1_250),
        BrewerSize(id: "drip-12", name: "12-cup machine", heldG: 1_500, pourG: 1_500),
      ], defaultID: "drip-10"),
  ]

  static func sizes(for methodKey: String?) -> [BrewerSize] {
    methodKey.flatMap { methods[$0]?.sizes } ?? []
  }

  static func defaultSize(for methodKey: String?) -> BrewerSize? {
    guard let method = methodKey.flatMap({ methods[$0] }) else { return nil }
    return method.sizes.first { $0.id == method.defaultID }
  }

  static func storageKey(_ methodKey: String) -> String { "brewer.size.\(methodKey)" }

  /// The size the user picked (or accepted as the default); nil until then.
  static func chosen(for methodKey: String?, defaults: UserDefaults = .standard) -> BrewerSize? {
    guard let methodKey, let id = defaults.string(forKey: storageKey(methodKey)) else {
      return nil
    }
    return sizes(for: methodKey).first { $0.id == id }
  }

  /// True the first time an AI recipe is asked for on a method that has sizes.
  static func needsAsking(_ methodKey: String?, defaults: UserDefaults = .standard) -> Bool {
    !sizes(for: methodKey).isEmpty && chosen(for: methodKey, defaults: defaults) == nil
  }

  static func choose(_ size: BrewerSize, for methodKey: String, defaults: UserDefaults = .standard)
  {
    defaults.set(size.id, forKey: storageKey(methodKey))
  }
}

/// A method's kind with the user's size (or the default): what an AI recipe must fit.
@MainActor
struct BrewerFit: Equatable {
  var kind: BrewerCapacity.Kind
  var size: BrewerSize
  /// The user never picked a size, so the most common one is assumed.
  var assumed = false

  /// Within this many grams counts as fitting: the capacities are rounded estimates.
  static let slackG = 2.0

  static func current(_ methodKey: String?, defaults: UserDefaults = .standard) -> BrewerFit? {
    guard let methodKey, let method = BrewerCapacity.methods[methodKey],
      let fallback = BrewerCapacity.defaultSize(for: methodKey)
    else { return nil }
    let chosen = BrewerCapacity.chosen(for: methodKey, defaults: defaults)
    return BrewerFit(kind: method.kind, size: chosen ?? fallback, assumed: chosen == nil)
  }

  struct Overfill: Equatable {
    /// Index in the recipe's steps sorted by time.
    var step: Int
    var heldG: Double
    var limitG: Double
    /// Over the closed (held) limit rather than the per-pour limit.
    var whileHeld: Bool
  }

  /// Walks the steps in time order tracking the water in the brewer: pours add to it, a
  /// switchable's open valve and a drawdown let it go, and bypass water goes to the cup. Every
  /// point over the limit, in step order.
  func overfills(_ draft: RecipeDraft) -> [Overfill] {
    var found: [Overfill] = []
    var held = 0.0
    var poured = 0.0
    var closed = false
    for (index, step) in RecipeEditorService.sorted(draft.steps).enumerated() {
      switch step.kind {
      case .closeValve:
        // What was poured with the valve open has drained; `split` assumes the same.
        closed = true
        held = 0
      case .openValve:
        closed = false
        held = 0
      case .drawdown: if kind != .immersion { held = 0 }
      case .bypass: poured = max(poured, step.targetCumulativeWaterG ?? poured)
      case .bloom, .pour:
        guard let target = step.targetCumulativeWaterG else { continue }
        let added = max(0, target - poured)
        poured = max(poured, target)
        let holds = kind == .immersion || (kind == .switchable && closed)
        held = holds ? held + added : added
        let limit = holds ? size.heldG : size.pourG
        if held > limit + Self.slackG {
          found.append(Overfill(step: index, heldG: held, limitG: limit, whileHeld: holds))
        }
      default: break
      }
    }
    return found
  }

  private var heldPhrase: String {
    kind == .switchable ? "with the valve closed" : "at once"
  }

  /// For the AI prompt: the brewer's size, its limits and the rule.
  var promptLine: String {
    let held = BrewerFit.grams(size.heldG)
    let pour = BrewerFit.grams(size.pourG)
    let limits: String
    switch kind {
    case .switchable:
      limits =
        "it holds at most \(held) g with the valve closed and \(pour) g at once while pouring "
        + "with the valve open. Never pour more than \(held) g in total while the valve is "
        + "closed; split the pour, or open the valve earlier and pour the rest over in pulses "
        + "of at most \(pour) g"
    case .pourThrough:
      limits =
        "it holds at most \(pour) g at once, so no single pour may add more than \(pour) g; "
        + "split bigger pours and let it drain between them"
    case .immersion:
      limits =
        "it holds at most \(held) g of water at once, so the water poured into it must never "
        + "add up to more than \(held) g; use less water and dose to keep the ratio"
    }
    return "Brewer size: \(size.name)" + (assumed ? " (assumed, the most common size)" : "")
      + "; \(limits). The brewer must never hold more than its capacity."
  }

  /// What went wrong, for asking the AI again; nil when the recipe fits.
  func problem(_ draft: RecipeDraft) -> String? {
    guard let first = overfills(draft).first else { return nil }
    return "Your last recipe overfilled the \(size.name): at step \(first.step + 1) it would "
      + "hold \(BrewerFit.grams(first.heldG)) g but it holds at most "
      + "\(BrewerFit.grams(first.limitG)) g \(first.whileHeld ? heldPhrase : "per pour"). "
      + "Rewrite the recipe so it never holds more than that."
  }

  /// "Fits your Hario Switch 03 (max ~410 g closed)".
  var fitsLine: String {
    switch kind {
    case .switchable:
      "Fits your \(size.name) (max ~\(BrewerFit.grams(size.heldG)) g closed)"
    case .pourThrough:
      "Fits your \(size.name) (max ~\(BrewerFit.grams(size.pourG)) g per pour)"
    case .immersion:
      "Fits your \(size.name) (max ~\(BrewerFit.grams(size.heldG)) g)"
    }
  }

  /// "Your Hario Switch 03 holds about 410 g with the valve closed; step 3 would hold 614 g."
  func warning(_ overfill: Overfill) -> String {
    "Your \(size.name) holds about \(BrewerFit.grams(overfill.limitG)) g "
      + (overfill.whileHeld ? heldPhrase : "per pour") + "; step \(overfill.step + 1) would "
      + "hold \(BrewerFit.grams(overfill.heldG)) g. Split that pour or pick your size in "
      + "Settings > Brewer sizes."
  }

  /// The recipe changed to fit, with a sentence saying how; nil when it already fits.
  /// Immersion brewers keep everything poured, so the whole recipe is scaled down to the
  /// capacity at the same ratio. Otherwise the total water stays the same: water past the
  /// closed limit is poured after the valve opens (opening it at that point when the recipe
  /// never does), and a pour too big for the brewer is split into pours that fit.
  func fitted(_ draft: RecipeDraft) -> (draft: RecipeDraft, note: String)? {
    guard !overfills(draft).isEmpty else { return nil }
    var fixed = kind == .immersion ? scaled(draft) : split(draft)
    if let last = fixed.steps.map(\.startOffsetS).max(), let total = fixed.totalTimeS,
      last > total
    {
      fixed.totalTimeS = last + 30
    }
    let note =
      kind == .immersion
      ? "Scaled to \(BrewerFit.grams(fixed.waterG)) g of water so your \(size.name) "
        + "(holds about \(BrewerFit.grams(size.heldG)) g) never overflows."
      : "Pours were split so your \(size.name) never holds more than "
        + (kind == .switchable
          ? "\(BrewerFit.grams(size.heldG)) g with the valve closed or "
            + "\(BrewerFit.grams(size.pourG)) g while pouring."
          : "\(BrewerFit.grams(size.pourG)) g at once.")
    return (fixed, "Adjusted to fit your brewer: \(note)")
  }

  private func scaled(_ draft: RecipeDraft) -> RecipeDraft {
    let peak = overfills(draft).map(\.heldG).max() ?? size.heldG
    let factor = size.heldG / peak
    var fixed = draft
    fixed.doseG = (draft.doseG * factor * 10).rounded(.down) / 10
    fixed.waterG = (draft.waterG * factor).rounded(.down)
    fixed.iceG = draft.iceG.map { ($0 * factor).rounded(.down) }
    fixed.steps = draft.steps.map { step in
      var step = step
      step.targetCumulativeWaterG = step.targetCumulativeWaterG.map {
        min(fixed.waterG, ($0 * factor).rounded(.down))
      }
      step.instruction = Self.scaleGrams(in: step.instruction, by: factor)
      return step
    }
    // The last pour still reaches the recipe's water after rounding.
    if let last = fixed.steps.indices.last(where: { fixed.steps[$0].targetCumulativeWaterG != nil })
    {
      fixed.steps[last].targetCumulativeWaterG = fixed.waterG
    }
    return fixed
  }

  /// "Pour 307 g" becomes "Pour 204 g": every gram amount in an instruction, scaled.
  static func scaleGrams(in text: String, by factor: Double) -> String {
    guard let pattern = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s?g\b"#) else {
      return text
    }
    let source = text as NSString
    let result = NSMutableString(string: text)
    for match in pattern.matches(in: text, range: NSRange(location: 0, length: source.length))
      .reversed()
    {
      guard let value = Double(source.substring(with: match.range(at: 1))) else { continue }
      result.replaceCharacters(in: match.range(at: 1), with: grams((value * factor).rounded(.down)))
    }
    return result as String
  }

  private func split(_ draft: RecipeDraft) -> RecipeDraft {
    let sorted = RecipeEditorService.sorted(draft.steps)
    var out: [RecipeStepDraft] = []
    var poured = 0.0  // the original running total
    var total = 0.0  // the new running total
    var held = 0.0
    var closed = false
    var carry = 0.0  // water held back until the valve opens

    /// Pours `amount` as pulses that each fit, spread from `start` toward the next step.
    func pourOpen(_ amount: Double, at start: Int, before next: Int?, kind: StepKind = .pour) {
      let count = Int((amount / size.pourG).rounded(.up))
      guard count > 0 else { return }
      let each = (amount / Double(count)).rounded(.down)
      let gap = next.map { min(20, max(0, ($0 - start) / count)) } ?? 20
      for index in 0..<count {
        let part = index == count - 1 ? amount - each * Double(count - 1) : each
        total += part
        out.append(
          RecipeStepDraft(
            kind: index == 0 ? kind : .pour, startOffsetS: start + index * gap,
            targetCumulativeWaterG: total,
            instruction: "Pour \(BrewerFit.grams(part)) g, to \(BrewerFit.grams(total)) g in total."
          ))
      }
    }

    for (index, step) in sorted.enumerated() {
      let next = sorted[(index + 1)...].first { $0.startOffsetS > step.startOffsetS }?.startOffsetS
      switch step.kind {
      case .closeValve:
        closed = true
        out.append(step)
      case .openValve:
        closed = false
        held = 0
        out.append(step)
        pourOpen(carry, at: step.startOffsetS, before: next)
        carry = 0
      case .drawdown:
        held = 0
        out.append(step)
      case .bloom, .pour, .bypass:
        guard let target = step.targetCumulativeWaterG else {
          out.append(step)
          continue
        }
        let added = max(0, target - poured)
        poured = max(poured, target)
        if step.kind == .bypass {
          total += added
          var kept = step
          kept.targetCumulativeWaterG = total
          out.append(kept)
        } else if closed {
          let keep = min(added, max(0, size.heldG - held))
          held += keep
          if keep > 0 {
            total += keep
            var kept = step
            kept.targetCumulativeWaterG = total
            if keep < added {
              kept.instruction =
                "Pour \(BrewerFit.grams(keep)) g, to \(BrewerFit.grams(total)) g in total."
            }
            out.append(kept)
          }
          let over = added - keep
          guard over > 0 else { continue }
          if sorted[(index + 1)...].contains(where: { $0.kind == .openValve }) {
            carry += over
          } else {
            // The recipe never opens the valve: open it now and pour the rest over.
            closed = false
            held = 0
            out.append(
              RecipeStepDraft(
                kind: .openValve, startOffsetS: step.startOffsetS,
                instruction: "Open the valve to drain."))
            pourOpen(over, at: step.startOffsetS, before: next)
          }
        } else if added > size.pourG + Self.slackG {
          pourOpen(added, at: step.startOffsetS, before: next, kind: step.kind)
        } else {
          total += added
          var kept = step
          kept.targetCumulativeWaterG = total
          out.append(kept)
        }
      default: out.append(step)
      }
    }
    var fixed = draft
    fixed.steps = out
    return fixed
  }

  static func grams(_ value: Double) -> String {
    value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
  }
}
