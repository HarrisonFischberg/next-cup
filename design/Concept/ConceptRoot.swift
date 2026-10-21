import SwiftUI

/// Baseline: stock SwiftUI, no design. Each concept branch replaces this file
/// (and adds its own presentation files) in this folder.
struct ConceptRoot: View {
    var body: some View {
        ConceptShell(tint: .accentColor) { model in
            List {
                Text(model.recipe.name)
                Button("Brew this") { model.showTimer = true }
            }
            .navigationTitle("Recipe")
        } timer: { model in
            VStack {
                TimerClock(model: model) { elapsed, _ in Text(Fmt.clock(Int(elapsed))).font(.largeTitle) }
                Button("Start") { model.toggleTimer() }
                Button("Finish") { model.finishBrew() }
            }
        } log: { model in
            Text("Log")
        } journal: { model in
            List(model.journal) { Text($0.bean) }.navigationTitle("Journal")
        }
    }
}
