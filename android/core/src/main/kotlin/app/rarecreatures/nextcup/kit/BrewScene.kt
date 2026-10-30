package app.rarecreatures.nextcup.kit

/** Which moving picture the timer shows. Built-in methods map by key; others by their brew style. */
enum class BrewSceneKind {
    POUR_OVER, SWITCHABLE, PRESS, INVERTED, ESPRESSO, COLD,
    /** The brewer's drawing as it fills (moka pot, AeroPress, Chemex, drip machine). */
    STILL;

    companion object {
        /** [methodKey] is the built-in key (methods.json); [style] is the BrewStyle raw value. */
        fun of(methodKey: String?, style: String?): BrewSceneKind = when (methodKey) {
            "cone-dripper", "flat-dripper", "iced-pour-over" -> POUR_OVER
            "switchable-dripper" -> SWITCHABLE
            "press" -> PRESS
            "inverted-press" -> INVERTED
            "espresso" -> ESPRESSO
            "cold-brew" -> COLD
            "moka-pot", "aeropress", "chemex", "drip-machine" -> STILL
            else -> when (style) {
                "immersion" -> PRESS
                "espresso" -> ESPRESSO
                "cold" -> COLD
                else -> POUR_OVER
            }
        }
    }
}

/** One recipe step as the scene needs it: when it starts and its StepKind raw value. */
data class BrewSceneStep(val startS: Double, val kind: String)

/** Where everything in the picture should be at one moment. Fractions run 0..1. */
data class BrewSceneFrame(
    var pouring: Boolean = false,
    var kettleShown: Boolean = false,
    var bed: Double = 0.0,
    var vessel: Double = 0.0,
    var dripping: Boolean = false,
    var lidOn: Boolean = false,
    var plunger: Double = 0.0,
    var inverted: Boolean = false,
    var steeping: Boolean = false,
    var pressureBar: Double = 0.0,
    var shot: Boolean = false,
    var darkness: Double = 0.0,
)

/** Turns a recipe's steps and the elapsed time into a [BrewSceneFrame]. Pure, so it always agrees with the timer. */
object BrewScene {
    private val pourKinds = setOf("bloom", "pour")

    fun frame(kind: BrewSceneKind, steps: List<BrewSceneStep>, totalS: Double, elapsedS: Double): BrewSceneFrame {
        val f = BrewSceneFrame()
        if (elapsedS <= 0 || steps.isEmpty() || totalS <= 0) return f
        val t = minOf(elapsedS, totalS)
        val sorted = steps.sortedBy { it.startS }
        val index = sorted.indexOfLast { it.startS <= t }.takeIf { it >= 0 } ?: 0
        val step = sorted[index]
        val into = t - step.startS
        val running = elapsedS < totalS
        val poured = pouredFraction(sorted, totalS, t)
        if (step.kind in pourKinds && running && t >= step.startS) {
            val window = pourWindow(sorted, index, totalS)
            f.pouring = into < window
            f.kettleShown = into < window + 1.5
        }
        when (kind) {
            BrewSceneKind.POUR_OVER -> {
                val firstPour = sorted.firstOrNull { it.kind in pourKinds }?.startS ?: 0.0
                val drainStart = sorted.firstOrNull { it.kind == "drawdown" }?.startS ?: lastPourEnd(sorted, totalS)
                val full = minOf(1.0, poured * 3)
                f.bed = if (t < drainStart) full else full * (1 - clamp((t - drainStart) / maxOf(1.0, totalS - drainStart)))
                f.vessel = clamp((t - firstPour - 10) / maxOf(1.0, totalS - firstPour - 10)) * 0.92
                f.dripping = running && t > firstPour + 6 && f.bed > 0.05
            }
            BrewSceneKind.SWITCHABLE -> {
                var open = sorted.first().kind != "closeValve"
                var openedAt = 0.0
                for (s in sorted) if (s.startS <= t) {
                    if (s.kind == "closeValve") open = false
                    if (s.kind == "openValve") { open = true; openedAt = s.startS }
                }
                val drain = maxOf(20.0, (totalS - openedAt) * 0.85)
                f.bed = if (open) poured * (1 - clamp((t - openedAt) / drain)) else poured
                f.vessel = maxOf(0.0, poured - f.bed) * 0.9
                f.dripping = open && running && f.bed > 0.04
                f.lidOn = !open && (step.kind == "wait" || step.kind == "stir") && !f.pouring
            }
            BrewSceneKind.PRESS -> {
                f.vessel = poured
                f.lidOn = !f.pouring && poured > 0.99
                f.plunger = pressProgress(sorted, totalS, t)
                f.steeping = running && (step.kind == "stir" || step.kind == "wait")
            }
            BrewSceneKind.INVERTED -> {
                val flip = sorted.indexOfFirst { it.kind == "invert" }
                if (flip >= 0) {
                    val end = if (flip + 1 < sorted.size) sorted[flip + 1].startS else totalS
                    f.inverted = t < sorted[flip].startS + (end - sorted[flip].startS) * 0.5
                    f.lidOn = index >= flip || (!f.pouring && poured > 0.99)
                } else {
                    f.lidOn = !f.pouring && poured > 0.99
                }
                f.bed = poured
                f.plunger = pressProgress(sorted, totalS, t)
                f.vessel = f.plunger
                f.steeping = running && (step.kind == "stir" || step.kind == "wait")
            }
            BrewSceneKind.ESPRESSO -> {
                val pre = minOf(6.0, totalS * 0.2)
                f.pouring = false
                f.kettleShown = false
                f.pressureBar = if (!running) 0.0 else if (t < pre) 3.0 else 9.0
                f.shot = running && t >= pre
                f.vessel = clamp((t - pre) / maxOf(1.0, totalS - pre))
            }
            BrewSceneKind.COLD -> {
                f.bed = poured
                f.darkness = clamp(t / totalS)
            }
            BrewSceneKind.STILL -> {
                f.pouring = false
                f.kettleShown = false
                f.vessel = clamp(t / totalS)
            }
        }
        return f
    }

    /** How long the kettle pours in a step: a short bloom, then most of a pour step. */
    internal fun pourWindow(steps: List<BrewSceneStep>, index: Int, totalS: Double): Double {
        val s = steps[index]
        val end = if (index + 1 < steps.size) steps[index + 1].startS else totalS
        val length = maxOf(0.0, end - s.startS)
        val window = if (s.kind == "bloom") minOf(length * 0.4, 12.0) else minOf(length * 0.7, 25.0)
        return maxOf(minOf(3.0, length), window)
    }

    /** Share of the recipe's pours finished by [t], each pour step weighing the same. */
    internal fun pouredFraction(steps: List<BrewSceneStep>, totalS: Double, t: Double): Double {
        val pours = steps.indices.filter { steps[it].kind in pourKinds }
        if (pours.isEmpty()) return if (t > 0) 1.0 else 0.0
        val done = pours.sumOf { clamp((t - steps[it].startS) / pourWindow(steps, it, totalS)) }
        return done / pours.size
    }

    private fun lastPourEnd(steps: List<BrewSceneStep>, totalS: Double): Double {
        val i = steps.indexOfLast { it.kind in pourKinds }
        if (i < 0) return 0.0
        return steps[i].startS + pourWindow(steps, i, totalS)
    }

    private fun pressProgress(steps: List<BrewSceneStep>, totalS: Double, t: Double): Double {
        val i = steps.indexOfFirst { it.kind == "press" }
        if (i < 0) return 0.0
        val end = if (i + 1 < steps.size) steps[i + 1].startS else totalS
        return clamp((t - steps[i].startS) / maxOf(1.0, end - steps[i].startS))
    }

    private fun clamp(x: Double) = minOf(1.0, maxOf(0.0, x))
}
