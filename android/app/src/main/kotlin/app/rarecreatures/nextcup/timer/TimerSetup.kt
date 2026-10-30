package app.rarecreatures.nextcup.timer

import app.rarecreatures.nextcup.data.BrewMethod
import app.rarecreatures.nextcup.data.BrewStyle
import app.rarecreatures.nextcup.data.Recipe
import app.rarecreatures.nextcup.data.RecipeStep
import app.rarecreatures.nextcup.kit.BrewSceneKind
import app.rarecreatures.nextcup.kit.BrewSceneStep
import app.rarecreatures.nextcup.kit.RecipeScaler
import app.rarecreatures.nextcup.kit.RecipeTiming
import app.rarecreatures.nextcup.kit.ScalableRecipe
import app.rarecreatures.nextcup.kit.TimerPlan
import app.rarecreatures.nextcup.kit.TimerStep
import app.rarecreatures.nextcup.scalable
import kotlinx.serialization.Serializable

/** What starts a run: the recipe at a dose, and what was picked on the setup page. Persisted so a run survives process death. */
@Serializable
data class TimerRun(
    val sessionKey: String,
    val recipeId: String,
    val doseG: Double,
    val beanId: String? = null,
    val beanName: String? = null,
    val grinderId: String? = null,
    val grindSetting: String = "",
)

/** Everything the guided timer needs for one run, as iOS's TimerSetup. */
data class TimerSetup(
    val run: TimerRun,
    val plan: TimerPlan,
    val recipeName: String,
    val methodName: String?,
    val tempC: Double?,
    /** The recipe after scaling to the dose the user chose. */
    val scaled: ScalableRecipe,
    /** Each step's kind (StepKind raw value) by the step's `order`. */
    val stepKinds: List<String>,
    val sceneKind: BrewSceneKind,
) {
    val sceneSteps: List<BrewSceneStep>
        get() = plan.steps.map { BrewSceneStep(it.startOffsetS.toDouble(), stepKinds.getOrElse(it.order) { "wait" }) }

    companion object {
        /** Seconds the brew runs after the last step when the recipe gives no total time. */
        const val TAIL_S = 30

        /** Water targets scale with the dose and pour-over times stretch gently. */
        fun build(run: TimerRun, recipe: Recipe, steps: List<RecipeStep>, method: BrewMethod?): TimerSetup {
            val ordered = steps.sortedWith(compareBy({ it.order }, { it.startOffsetS }))
            val scaled = RecipeScaler.scale(recipe.scalable(ordered), run.doseG).recipe
            val factor = RecipeTiming.factor(method?.style == BrewStyle.POUR_OVER, recipe.doseG, run.doseG)
            val timerSteps = ordered.mapIndexed { i, s ->
                TimerStep(
                    order = i, label = s.kind.label, instruction = s.instruction,
                    startOffsetS = RecipeTiming.scaled(s.startOffsetS, factor),
                    targetCumulativeWaterG = scaled.steps.getOrNull(i)?.targetCumulativeWaterG,
                )
            }
            val last = timerSteps.maxOfOrNull { it.startOffsetS } ?: 0
            val declared = RecipeTiming.scaled(recipe.totalTimeS ?: 0, factor)
            val total = if (declared > last) declared else last + TAIL_S
            return TimerSetup(
                run, TimerPlan.of(timerSteps, total), recipe.name, method?.name, recipe.tempC, scaled,
                ordered.map { it.kind.raw }, BrewSceneKind.of(method?.builtInKey, method?.style?.raw),
            )
        }
    }
}
