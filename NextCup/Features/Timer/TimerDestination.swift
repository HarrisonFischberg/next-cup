import SwiftData
import SwiftUI

/// Opens the guided timer from a `nextcup://timer` link (the Live Activity tap).
/// The timer picks up the saved run when the plan matches; a recipe that is gone
/// or cannot be timed lands on a screen that says so. The bean and grinder chosen
/// for that run come back with it, so a brew rated later still has them.
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
      TimerView(
        setup: setup.withRememberedChoices(
          resuming: TimerEnvironment.stateStore.load(), now: TimerEnvironment.clock.now())
      ).accessibilityIdentifier(link.identifier)
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
