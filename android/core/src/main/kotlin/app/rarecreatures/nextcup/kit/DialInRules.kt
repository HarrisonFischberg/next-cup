package app.rarecreatures.nextcup.kit

/** How a cup tasted. Mirrors the app's stored verdict by raw value. */
enum class DialInVerdict(val raw: String) {
    SOUR("sour"), BITTER("bitter"), WEAK("weak"), BRIGHT("bright"), STRONG("strong"), BALANCED("balanced");

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

/** The brewing family, which decides which levers make sense. Mirrors the app's brew style. */
enum class DialInStyle(val raw: String) {
    POUR_OVER("pourOver"), IMMERSION("immersion"), ESPRESSO("espresso"), COLD("cold");

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

/** The one thing a suggestion changes. Raw values match the app's brew parameters. */
enum class DialInParameter(val raw: String) {
    GRIND("grind"), WATER("water"), YIELD("yield"), TEMPERATURE("temperature"), TIME("time");

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

/** What the rules look at: the verdict and the values the cup was brewed with, in canonical units. */
data class DialInInput(
    val verdict: DialInVerdict,
    val style: DialInStyle,
    /** A change is only proposed on a parameter the form actually shows. */
    val tracked: Set<DialInParameter>,
    val grindSetting: String? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
)

/** One proposed change, in canonical text; the app formats it for the user's units. */
data class SuggestionDraft(val parameter: DialInParameter, val fromValue: String, val toValue: String, val rationale: String)

sealed interface DialInOutcome {
    /** Change this one thing before the next cup. */
    data class Change(val draft: SuggestionDraft) : DialInOutcome
    /** Nothing to change: the cup was right, or no tracked lever applies. */
    data class Keep(val message: String) : DialInOutcome
}

/** Rule-based dial-in: from how a cup tasted, one change to try next. One lever at a time. */
object DialInRules {
    const val TEMPERATURE_STEP_C = 2.0
    const val TEMPERATURE_CEILING_C = 99.0
    const val TEMPERATURE_FLOOR_C = 80.0
    const val IMMERSION_TIME_STEP_S = 30
    const val COLD_TIME_STEP_S = 7_200
    const val COLD_TIME_FLOOR_S = 3_600
    const val WEAK_CUT = 0.06
    const val STRONG_ADD = 0.08
    const val ESPRESSO_YIELD_SHIFT = 0.10

    fun suggest(input: DialInInput): DialInOutcome = when (input.verdict) {
        DialInVerdict.BALANCED -> DialInOutcome.Keep("This cup was balanced. Brew it again the same way.")
        DialInVerdict.SOUR -> firstChange(listOf(grind(input, true), temperature(input, true), time(input, true)), input.verdict)
        DialInVerdict.BITTER -> firstChange(listOf(grind(input, false), temperature(input, false), time(input, false)), input.verdict)
        DialInVerdict.WEAK -> firstChange(listOf(strength(input, true)), input.verdict)
        DialInVerdict.STRONG -> firstChange(listOf(strength(input, false)), input.verdict)
        DialInVerdict.BRIGHT -> DialInOutcome.Keep("A bright cup is lively, not sour. Brew it again the same way.")
    }

    private fun firstChange(options: List<SuggestionDraft?>, verdict: DialInVerdict): DialInOutcome =
        options.firstNotNullOfOrNull { it }?.let { DialInOutcome.Change(it) }
            ?: DialInOutcome.Keep("No setting for this ${verdict.raw} cup can be changed from here.")

    private fun grind(input: DialInInput, finer: Boolean): SuggestionDraft? {
        if (DialInParameter.GRIND !in input.tracked) return null
        val why = if (finer) "Sour usually means the coffee was under-extracted. A finer grind slows the water and pulls more out."
        else "Bitter usually means the coffee was over-extracted. A coarser grind lets the water through faster and pulls less out."
        val current = input.grindSetting?.trim().orEmpty()
        GrindStep.moved(current, finer)?.let {
            return SuggestionDraft(DialInParameter.GRIND, current, it, "$why On most grinders a lower number is finer.")
        }
        return SuggestionDraft(DialInParameter.GRIND, current, if (finer) "one step finer" else "one step coarser", why)
    }

    private fun temperature(input: DialInInput, warmer: Boolean): SuggestionDraft? {
        val current = input.tempC
        if (DialInParameter.TEMPERATURE !in input.tracked || input.style == DialInStyle.COLD || input.style == DialInStyle.ESPRESSO || current == null) return null
        val next = if (warmer) minOf(current + TEMPERATURE_STEP_C, TEMPERATURE_CEILING_C) else maxOf(current - TEMPERATURE_STEP_C, TEMPERATURE_FLOOR_C)
        if (next == current) return null
        val why = if (warmer) "Hotter water extracts more, which helps a sour cup." else "Cooler water extracts less, which calms a bitter cup."
        return SuggestionDraft(DialInParameter.TEMPERATURE, number(current), number(next), why)
    }

    private fun time(input: DialInInput, longer: Boolean): SuggestionDraft? {
        val current = input.totalTimeS
        if (DialInParameter.TIME !in input.tracked || current == null) return null
        val next = when (input.style) {
            DialInStyle.IMMERSION -> maxOf(60, current + if (longer) IMMERSION_TIME_STEP_S else -IMMERSION_TIME_STEP_S)
            DialInStyle.COLD -> maxOf(COLD_TIME_FLOOR_S, current + if (longer) COLD_TIME_STEP_S else -COLD_TIME_STEP_S)
            else -> return null
        }
        if (next == current) return null
        val why = if (longer) "A longer steep extracts more, which helps a sour cup." else "A shorter steep extracts less, which calms a bitter cup."
        return SuggestionDraft(DialInParameter.TIME, current.toString(), next.toString(), why)
    }

    /** Weak and strong are about concentration. Espresso moves the output weight, everything else the water. */
    private fun strength(input: DialInInput, stronger: Boolean): SuggestionDraft? {
        val current = input.waterG
        if (current == null || current <= 0) return null
        val isEspresso = input.style == DialInStyle.ESPRESSO
        val share = if (isEspresso) ESPRESSO_YIELD_SHIFT else if (stronger) WEAK_CUT else STRONG_ADD
        val factor = if (stronger) 1 - share else 1 + share
        val next = if (isEspresso) (current * factor * 2).roundHalfAway() / 2 else (current * factor).roundHalfAway()
        if (next == current || next <= 0) return null
        val amount = if (isEspresso) "output weight" else "water"
        val why = if (stronger) "A weak cup is too dilute. Less $amount for the same coffee makes it stronger."
        else "A strong cup is too concentrated. More $amount for the same coffee makes it lighter."
        return SuggestionDraft(if (isEspresso) DialInParameter.YIELD else DialInParameter.WATER, number(current), number(next), why)
    }

    /** Whole numbers without a trailing ".0", otherwise one decimal. */
    internal fun number(value: Double): String =
        if (value == value.roundHalfAway()) value.toLong().toString() else fmt("%.1f", value)
}

/** Moves a typed grind setting one step, keeping the text around the number ("21 clicks" → "20 clicks"). */
internal object GrindStep {
    private val leading = Regex("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?")

    fun moved(setting: String, finer: Boolean): String? {
        val match = leading.find(setting) ?: return null
        val value = match.value.toDoubleOrNull() ?: return null
        val rest = setting.substring(match.range.last + 1)
        val next = if (finer) value - 1 else value + 1
        if (next < 0) return null
        return DialInRules.number(next) + rest
    }
}
