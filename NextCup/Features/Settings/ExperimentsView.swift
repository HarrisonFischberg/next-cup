import SwiftUI

/// Hidden screen for Debug and TestFlight builds: one switch per experiment flag.
/// Reached by long-pressing the version row in Settings.
struct ExperimentsView: View {
  @State private var flags = Self.read()

  var body: some View {
    List {
      Section {
        ForEach(Experiment.allCases) { experiment in
          Toggle(
            experiment.title,
            isOn: Binding(
              get: { flags[experiment] ?? false },
              set: {
                Experiments.set(experiment, on: $0)
                flags = Self.read()
              })
          )
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("experiments.\(experiment.rawValue)")
        }
      } footer: {
        Text("Off in App Store builds. The launch argument -evolve_all YES turns every flag on.")
      }
      Section {
        Button("Turn all on") {
          Experiments.turnAllOn()
          flags = Self.read()
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("experiments.allOn")
        Button("Reset", role: .destructive) {
          Experiments.reset()
          flags = Self.read()
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("experiments.reset")
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("Experiments")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("settings.experiments")
  }

  private static func read() -> [Experiment: Bool] {
    Dictionary(uniqueKeysWithValues: Experiment.allCases.map { ($0, Experiments.isOn($0)) })
  }
}
