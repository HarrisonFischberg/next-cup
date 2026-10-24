import SwiftData
import SwiftUI

/// Opens the guided timer from a `nextcup://timer` link (the Live Activity tap).
/// The timer picks up the saved run when the plan matches; a recipe that is gone
/// or cannot be timed lands on a screen that says so.
struct TimerDestination: View {
  let link: DeepLink
  let doseG: Double
  @Query private var matches: [Recipe]

  init(link: DeepLink, recipeID: UUID, doseG: Double) {
    self.link = link
    self.doseG = doseG
    _matches = Query(filter: #Predicate<Recipe> { $0.id == recipeID })
  }

  var body: some View {
    if let recipe = matches.first,
      let setup = try? TimerPlanBuilder.setup(for: recipe, doseG: doseG)
    {
      TimerView(setup: setup).accessibilityIdentifier(link.identifier)
    } else {
      ScrollView {
        EmptyState(
          title: "Timer not available",
          message: "This brew's recipe is no longer in your library. Open Recipes to start again.")
      }
      .background(DS.bg)
      .navigationTitle(link.screenName)
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier(link.identifier)
    }
  }
}
