package app.rarecreatures.nextcup.kit

import kotlin.math.abs

/** One timeline step as the scaler sees it. */
data class ScalableStep(val order: Int, val startOffsetS: Int, val targetCumulativeWaterG: Double?)

/** A recipe reduced to the numbers that scale with dose. On an iced recipe `waterG` is the hot water. */
data class ScalableRecipe(
    val doseG: Double,
    val waterG: Double,
    val iceG: Double? = null,
    val includesIce: Boolean = false,
    val steps: List<ScalableStep> = emptyList(),
) {
    /** Hot water plus ice when the recipe is iced. */
    val totalWaterG: Double get() = waterG + if (includesIce) maxOf(iceG ?: 0.0, 0.0) else 0.0
}

class RecipeScalerError(val kind: Kind) : Exception(kind.name) {
    enum class Kind { INVALID_DOSE, INVALID_RECIPE_DOSE }
}

data class ScaledRecipe(
    val recipe: ScalableRecipe,
    val factor: Double,
    /** Plain-language notes about rounding, ready to show under the targets. */
    val notes: List<String>,
)

object RecipeScaler {
    /** Scales dose, water, ice and every step target by `newDose ÷ recipe.doseG`. Step times never change. */
    fun scale(recipe: ScalableRecipe, toDose: Double): ScaledRecipe {
        if (!toDose.isFinite() || toDose <= 0) throw RecipeScalerError(RecipeScalerError.Kind.INVALID_DOSE)
        if (recipe.doseG <= 0) throw RecipeScalerError(RecipeScalerError.Kind.INVALID_RECIPE_DOSE)
        val factor = toDose / recipe.doseG
        var largestShift = 0.0
        fun grams(exact: Double): Double {
            val rounded = exact.roundHalfAway()
            largestShift = maxOf(largestShift, abs(rounded - exact))
            return rounded
        }
        val scaled = recipe.copy(
            doseG = (toDose * 10).roundHalfAway() / 10,
            waterG = grams(recipe.waterG * factor),
            iceG = recipe.iceG?.let { grams(it * factor) },
            steps = recipe.steps.map { s -> s.copy(targetCumulativeWaterG = s.targetCumulativeWaterG?.let { grams(it * factor) }) },
        )
        val notes = mutableListOf<String>()
        if (largestShift > 0.0001) {
            val shift = (largestShift * 10).roundHalfAway() / 10
            notes += "Water targets are rounded to whole grams (up to $shift g off)."
        }
        if (scaled.doseG != toDose) notes += "Dose is rounded to 0.1 g."
        return ScaledRecipe(scaled, factor, notes)
    }
}
