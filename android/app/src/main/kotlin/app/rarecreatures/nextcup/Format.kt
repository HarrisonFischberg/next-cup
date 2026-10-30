package app.rarecreatures.nextcup

import app.rarecreatures.nextcup.data.BrewParameter
import app.rarecreatures.nextcup.data.Recipe
import app.rarecreatures.nextcup.data.RecipeStep
import app.rarecreatures.nextcup.kit.ScalableRecipe
import app.rarecreatures.nextcup.kit.ScalableStep
import app.rarecreatures.nextcup.kit.UnitPreferences
import app.rarecreatures.nextcup.kit.WeightUnit
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.roundToInt

/** Display strings. Storage is grams, °C and seconds; conversion happens here, as iOS's RecipeFormat. */
object Fmt {
    private fun f(format: String, vararg args: Any?) = String.format(Locale.getDefault(), format, *args)

    /** "3:05" for 185 seconds; hours when a cold brew runs that long. */
    fun clock(seconds: Int): String {
        val s = maxOf(seconds, 0)
        return if (s >= 3600) f("%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) else f("%d:%02d", s / 60, s % 60)
    }

    /** "1 min 5 seconds" for TalkBack. */
    fun spokenTime(seconds: Int): String {
        val s = maxOf(seconds, 0)
        val m = s / 60
        val r = s % 60
        return when {
            m == 0 -> "$r seconds"
            r == 0 -> if (m == 1) "1 minute" else "$m minutes"
            else -> "$m min $r seconds"
        }
    }

    /** Weight in the user's unit: whole grams (one decimal when needed), two-decimal ounces. */
    fun weight(grams: Double, units: UnitPreferences, withSymbol: Boolean = true): String {
        val v = units.displayWeight(grams)
        val text = if (units.weight == WeightUnit.GRAMS) {
            if (v.roundToInt().toDouble() == v) f("%.0f", v) else f("%.1f", v)
        } else f("%.2f", v)
        return if (withSymbol) "$text ${units.weightSymbol}" else text
    }

    fun temperature(celsius: Double, units: UnitPreferences) = f("%.0f%s", units.displayTemperature(celsius), units.temperatureSymbol)

    fun number(value: Double) = if (value == value.roundToInt().toDouble()) value.roundToInt().toString() else f("%.1f", value)

    fun date(millis: Long): String =
        DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(millis))

    fun day(millis: Long): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(millis))

    fun parameter(p: BrewParameter) = when (p) {
        BrewParameter.DOSE -> "Dose"
        BrewParameter.WATER -> "Water"
        BrewParameter.YIELD -> "Output weight"
        BrewParameter.GRIND -> "Grind"
        BrewParameter.TEMPERATURE -> "Temperature"
        BrewParameter.TIME -> "Time"
        BrewParameter.TDS -> "TDS"
        BrewParameter.RATING -> "Rating"
        BrewParameter.NOTES -> "Notes"
        BrewParameter.PHOTO -> "Photo"
    }
}

/** The fields the brew form shows for a method: what it tracks plus dose and water, which every brew needs. */
object MethodParameters {
    val required = listOf(BrewParameter.DOSE, BrewParameter.WATER)
    fun shown(tracked: List<BrewParameter>?): Set<BrewParameter> = (tracked ?: BrewParameter.entries).toSet() + required
}

fun Recipe.scalable(steps: List<RecipeStep>) = ScalableRecipe(
    doseG, waterG, iceG, includesIce,
    steps.sortedWith(compareBy({ it.order }, { it.startOffsetS })).map { ScalableStep(it.order, it.startOffsetS, it.targetCumulativeWaterG) },
)
