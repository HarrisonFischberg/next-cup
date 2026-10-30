package app.rarecreatures.nextcup.kit

enum class StockLevel { UNKNOWN, OK, LOW, EMPTY }

/**
 * How much of a bag is left: the bag weight, minus every brew that used it, plus the owner's manual
 * correction. Derived on demand and never stored.
 */
object BeanStock {
    /** A bag at or below this share of its weight counts as running low. */
    const val LOW_SHARE = 0.2

    /** Grams left, never below zero. `null` without a bag weight: an unknown amount is not zero. */
    fun remainingG(bagWeightG: Double?, usedG: List<Double>, adjustmentG: Double = 0.0): Double? {
        if (bagWeightG == null || bagWeightG <= 0) return null
        return maxOf(0.0, bagWeightG - usedG.sum() + adjustmentG)
    }

    /** The correction that makes the remaining amount equal [remainingG]. */
    fun adjustmentG(settingRemainingTo: Double, bagWeightG: Double?, usedG: List<Double>): Double? {
        if (bagWeightG == null || bagWeightG <= 0 || settingRemainingTo < 0) return null
        return settingRemainingTo - (bagWeightG - usedG.sum())
    }

    fun level(remainingG: Double?, bagWeightG: Double?): StockLevel {
        if (remainingG == null || bagWeightG == null || bagWeightG <= 0) return StockLevel.UNKNOWN
        if (remainingG <= 0) return StockLevel.EMPTY
        return if (remainingG <= bagWeightG * LOW_SHARE) StockLevel.LOW else StockLevel.OK
    }
}
