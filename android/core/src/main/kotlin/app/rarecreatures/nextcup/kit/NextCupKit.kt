package app.rarecreatures.nextcup.kit

/** Pure-Kotlin domain logic for Next Cup, ported from the iOS NextCupKit package. No Android types. */
object NextCupKit {
    /** Semantic version of the domain module, shown in Settings > About. */
    const val VERSION = "0.1.0"
}

/** Swift's `%.1f` and friends always use a dot here, whatever the device locale. */
internal fun fmt(format: String, vararg args: Any?): String = String.format(java.util.Locale.ROOT, format, *args)

/** Swift's `.rounded()`: half away from zero (Kotlin's `round` is half-even). */
internal fun Double.roundHalfAway(): Double = if (this < 0) -Math.round(-this).toDouble() else Math.round(this).toDouble()
