package app.rarecreatures.nextcup.kit

import kotlin.math.sqrt

/**
 * How step times follow the dose. Water targets always scale with the dose; times only partly do.
 * Pour-over timing stretches gently (the square root of the dose ratio, kept between 0.75 and 1.6).
 * Steeping, espresso and cold brew times stay as written.
 */
object RecipeTiming {
    fun factor(isPourOver: Boolean, recipeDoseG: Double, doseG: Double): Double {
        if (!isPourOver || recipeDoseG <= 0 || doseG <= 0) return 1.0
        return minOf(1.6, maxOf(0.75, sqrt(doseG / recipeDoseG)))
    }

    /** A time in seconds at this factor, to the nearest 5 seconds. */
    fun scaled(seconds: Int, factor: Double): Int {
        if (factor == 1.0) return seconds
        return (seconds * factor / 5).roundHalfAway().toInt() * 5
    }
}
