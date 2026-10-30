package app.rarecreatures.nextcup.kit

/** Derived brew numbers. Missing or non-positive inputs give `null`, never 0. */
object BrewMath {
    /** Water ÷ dose. On an iced recipe the ice counts toward water. */
    fun ratio(doseG: Double?, waterG: Double?, iceG: Double? = null): Double? {
        if (doseG == null || waterG == null || doseG <= 0 || waterG <= 0) return null
        return (waterG + maxOf(iceG ?: 0.0, 0.0)) / doseG
    }

    /** Yield ÷ dose for espresso. */
    fun espressoRatio(doseG: Double?, yieldG: Double?): Double? {
        if (doseG == null || yieldG == null || doseG <= 0 || yieldG <= 0) return null
        return yieldG / doseG
    }

    /** Extraction yield in percent: TDS percent × beverage weight ÷ dose. */
    fun extractionYield(tds: Double?, beverageG: Double?, doseG: Double?): Double? {
        if (tds == null || beverageG == null || doseG == null || tds <= 0 || beverageG <= 0 || doseG <= 0) return null
        return tds * beverageG / doseG
    }

    /** Grams of water each gram of grounds keeps. */
    const val ABSORPTION = 2.0

    /** The dose that makes [yieldG] of finished coffee at this recipe's ratio. */
    fun dose(forYieldG: Double, ratio: Double?): Double? {
        if (ratio == null || ratio <= 0 || forYieldG <= 0) return null
        return forYieldG / (if (ratio > 4) ratio - ABSORPTION else ratio)
    }

    /** What reaches the cup from [waterG] poured on [doseG]: the inverse of [dose]. */
    fun cupG(waterG: Double, doseG: Double): Double? {
        if (waterG <= 0 || doseG <= 0) return null
        return if (waterG / doseG > 4) waterG - ABSORPTION * doseG else waterG
    }

    /** "1:16.7" style label, one decimal place; `null` when the ratio is unknown. */
    fun ratioLabel(ratio: Double?): String? {
        if (ratio == null) return null
        val tenths = (ratio * 10).roundHalfAway() / 10
        return "1:$tenths"
    }
}
