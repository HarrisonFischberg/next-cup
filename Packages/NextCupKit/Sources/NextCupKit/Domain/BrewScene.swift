import Foundation

/// Which moving picture the timer shows. Built-in methods map by key; methods the
/// owner adds map by their brew style.
public enum BrewSceneKind: String, Sendable, CaseIterable {
  case pourOver, switchable, press, inverted, espresso, cold

  /// `methodKey` is the built-in key (methods.json); `style` is the BrewStyle raw value.
  public init(methodKey: String?, style: String?) {
    switch methodKey {
    case "cone-dripper", "flat-dripper", "iced-pour-over": self = .pourOver
    case "switchable-dripper": self = .switchable
    case "press": self = .press
    case "inverted-press": self = .inverted
    case "espresso": self = .espresso
    case "cold-brew": self = .cold
    default:
      switch style {
      case "immersion": self = .press
      case "espresso": self = .espresso
      case "cold": self = .cold
      default: self = .pourOver
      }
    }
  }
}

/// One recipe step as the scene needs it: when it starts and what kind it is
/// (a StepKind raw value such as "pour", "press" or "openValve").
public struct BrewSceneStep: Equatable, Sendable {
  public var startS: Double
  public var kind: String

  public init(startS: Double, kind: String) {
    self.startS = startS
    self.kind = kind
  }
}

/// Where everything in the picture should be at one moment. Fractions run 0...1.
public struct BrewSceneFrame: Equatable, Sendable {
  /// The kettle is tipped and water is falling.
  public var pouring = false
  /// The kettle is on screen (it lingers a moment after a pour).
  public var kettleShown = false
  /// Water and grounds sitting in the brewer (dripper bed, press chamber, cold jar).
  public var bed: Double = 0
  /// Coffee in the cup, server or beaker below.
  public var vessel: Double = 0
  /// Drops falling from the brewer.
  public var dripping = false
  /// Lid or filter cap in place.
  public var lidOn = false
  /// 0 is the plunger up, 1 fully pressed.
  public var plunger: Double = 0
  /// The inverted press is upside down.
  public var inverted = false
  /// Bubbles rise while it steeps.
  public var steeping = false
  /// Espresso gauge reading in bar.
  public var pressureBar: Double = 0
  /// Espresso is running into the cup.
  public var shot = false
  /// Cold brew strength, light to dark.
  public var darkness: Double = 0

  public init() {}
}

/// Turns a recipe's steps and the elapsed time into a `BrewSceneFrame`. Pure, so the
/// picture always agrees with the timer engine, including after the app comes back
/// from the background.
public enum BrewScene {
  private static let pourKinds: Set<String> = ["bloom", "pour"]

  public static func frame(
    _ kind: BrewSceneKind, steps: [BrewSceneStep], totalS: Double, elapsedS: Double
  ) -> BrewSceneFrame {
    var f = BrewSceneFrame()
    guard elapsedS > 0, !steps.isEmpty, totalS > 0 else { return f }
    let t = min(elapsedS, totalS)
    let steps = steps.sorted { $0.startS < $1.startS }
    let index = steps.lastIndex { $0.startS <= t } ?? 0
    let step = steps[index]
    let into = t - step.startS
    let running = elapsedS < totalS
    let poured = pouredFraction(steps, totalS: totalS, t: t)
    if pourKinds.contains(step.kind) && running && t >= step.startS {
      let window = pourWindow(steps, at: index, totalS: totalS)
      f.pouring = into < window
      f.kettleShown = into < window + 1.5
    }

    switch kind {
    case .pourOver:
      let firstPour = steps.first { pourKinds.contains($0.kind) }?.startS ?? 0
      let drainStart =
        steps.first { $0.kind == "drawdown" }?.startS ?? lastPourEnd(steps, totalS: totalS)
      let full = min(1, poured * 3)
      f.bed = t < drainStart ? full : full * (1 - clamp((t - drainStart) / max(1, totalS - drainStart)))
      f.vessel = clamp((t - firstPour - 10) / max(1, totalS - firstPour - 10)) * 0.92
      f.dripping = running && t > firstPour + 6 && f.bed > 0.05

    case .switchable:
      var open = steps.first?.kind != "closeValve"
      var openedAt = 0.0
      for s in steps where s.startS <= t {
        if s.kind == "closeValve" { open = false }
        if s.kind == "openValve" {
          open = true
          openedAt = s.startS
        }
      }
      let drain = max(20, (totalS - openedAt) * 0.85)
      f.bed = open ? poured * (1 - clamp((t - openedAt) / drain)) : poured
      f.vessel = max(0, poured - f.bed) * 0.9
      f.dripping = open && running && f.bed > 0.04
      f.lidOn = !open && (step.kind == "wait" || step.kind == "stir") && !f.pouring

    case .press:
      f.vessel = poured
      f.lidOn = !f.pouring && poured > 0.99
      f.plunger = pressProgress(steps, totalS: totalS, t: t)
      f.steeping = running && (step.kind == "stir" || step.kind == "wait")

    case .inverted:
      if let flip = steps.firstIndex(where: { $0.kind == "invert" }) {
        let end = flip + 1 < steps.count ? steps[flip + 1].startS : totalS
        f.inverted = t < steps[flip].startS + (end - steps[flip].startS) * 0.5
        f.lidOn = index >= flip || (!f.pouring && poured > 0.99)
      } else {
        f.lidOn = !f.pouring && poured > 0.99
      }
      f.bed = poured
      f.plunger = pressProgress(steps, totalS: totalS, t: t)
      f.vessel = f.plunger
      f.steeping = running && (step.kind == "stir" || step.kind == "wait")

    case .espresso:
      let pre = min(6, totalS * 0.2)
      f.pouring = false
      f.kettleShown = false
      f.pressureBar = !running ? 0 : t < pre ? 3 : 9
      f.shot = running && t >= pre
      f.vessel = clamp((t - pre) / max(1, totalS - pre))

    case .cold:
      f.bed = poured
      f.darkness = clamp(t / totalS)
    }
    return f
  }

  /// How long the kettle pours in a step: a short bloom, then most of a pour step.
  static func pourWindow(_ steps: [BrewSceneStep], at index: Int, totalS: Double) -> Double {
    let s = steps[index]
    let end = index + 1 < steps.count ? steps[index + 1].startS : totalS
    let length = max(0, end - s.startS)
    let window = s.kind == "bloom" ? min(length * 0.4, 12) : min(length * 0.7, 25)
    return max(min(3, length), window)
  }

  /// Share of the recipe's pours finished by `t`, each pour step weighing the same.
  static func pouredFraction(_ steps: [BrewSceneStep], totalS: Double, t: Double) -> Double {
    let pours = steps.indices.filter { pourKinds.contains(steps[$0].kind) }
    guard !pours.isEmpty else { return t > 0 ? 1 : 0 }
    let done = pours.reduce(0.0) { sum, i in
      let window = pourWindow(steps, at: i, totalS: totalS)
      return sum + clamp((t - steps[i].startS) / window)
    }
    return done / Double(pours.count)
  }

  private static func lastPourEnd(_ steps: [BrewSceneStep], totalS: Double) -> Double {
    guard let i = steps.lastIndex(where: { pourKinds.contains($0.kind) }) else { return 0 }
    return steps[i].startS + pourWindow(steps, at: i, totalS: totalS)
  }

  private static func pressProgress(_ steps: [BrewSceneStep], totalS: Double, t: Double) -> Double {
    guard let i = steps.firstIndex(where: { $0.kind == "press" }) else { return 0 }
    let end = i + 1 < steps.count ? steps[i + 1].startS : totalS
    return clamp((t - steps[i].startS) / max(1, end - steps[i].startS))
  }

  private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
