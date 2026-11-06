import Foundation
import Testing

@testable import NextCup

@Suite("Experiments")
struct ExperimentsTests {
  private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "evolve.experiments.test.\(UUID().uuidString)")!
  }

  @Test func appStoreBuildsCannotOverride() {
    #expect(!Experiments.canOverride(isDebug: false, receiptName: "receipt"))
    #expect(!Experiments.canOverride(isDebug: false, receiptName: nil))
    #expect(Experiments.canOverride(isDebug: false, receiptName: "sandboxReceipt"))
    #expect(Experiments.canOverride(isDebug: true, receiptName: nil))
  }

  /// A stored override or `-evolve_all YES` never turns a flag on in an App Store build.
  @Test func everyFlagIsOffInAppStoreBuilds() {
    let defaults = freshDefaults()
    Experiments.turnAllOn(defaults: defaults)
    for experiment in Experiment.allCases {
      #expect(
        !Experiments.isOn(
          experiment, canOverride: false, defaults: defaults,
          arguments: ["-evolve_all", "YES"]))
    }
  }

  @Test func flagsDefaultOffAndFollowOverrides() {
    let defaults = freshDefaults()
    for experiment in Experiment.allCases {
      #expect(!Experiments.isOn(experiment, canOverride: true, defaults: defaults, arguments: []))
      #expect(
        Experiments.isOn(
          experiment, canOverride: true, defaults: defaults, arguments: ["-evolve_all", "YES"]))
      #expect(
        !Experiments.isOn(
          experiment, canOverride: true, defaults: defaults, arguments: ["-evolve_all", "NO"]))
      Experiments.set(experiment, on: true, defaults: defaults)
      #expect(Experiments.isOn(experiment, canOverride: true, defaults: defaults, arguments: []))
    }
    Experiments.reset(defaults: defaults)
    for experiment in Experiment.allCases {
      #expect(!Experiments.isOn(experiment, canOverride: true, defaults: defaults, arguments: []))
    }
  }
}
