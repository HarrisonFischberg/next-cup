package app.rarecreatures.nextcup.kit

/**
 * Splits a brew's dose between the beans in a blend. Each bean has a number of parts (1 part each is
 * an even split), and every bean is charged its share of the dose.
 */
object BlendShares {
    private fun Double.cents() = (this * 100).roundHalfAway() / 100

    /** Grams per bean, in the order of [parts], summing to [dose] (to 0.01 g). */
    fun grams(dose: Double, parts: List<Double>): List<Double> {
        if (parts.isEmpty() || dose <= 0) return parts.map { 0.0 }
        val cleaned = parts.map { if (it.isFinite() && it > 0) it else 0.0 }
        val weights = if (cleaned.sum() > 0) cleaned else parts.map { 1.0 }
        val weightTotal = weights.sum()
        val result = weights.map { (dose * it / weightTotal).cents() }.toMutableList()
        // Rounding can leave a hundredth over or under; the largest share takes it.
        val drift = (dose - result.sum()).cents()
        if (drift != 0.0) {
            val largest = result.indices.maxBy { result[it] }
            result[largest] = maxOf(0.0, (result[largest] + drift).cents())
        }
        return result
    }

    /** [parts] as percentages that add up to 100. Zero or invalid parts split evenly. */
    fun percentages(parts: List<Double>): List<Double> {
        if (parts.isEmpty()) return emptyList()
        val cleaned = parts.map { if (it.isFinite() && it > 0) it else 0.0 }
        val total = cleaned.sum()
        if (total <= 0) return parts.map { 100.0 / parts.size }
        return cleaned.map { it / total * 100 }
    }

    /** Adds one more bean at an even share. */
    fun appending(shares: List<Double>): List<Double> {
        val current = percentages(shares)
        val count = (current.size + 1).toDouble()
        return current.map { it * (count - 1) / count } + (100 / count)
    }

    /** Takes the bean at [index] out and spreads its share across the others. */
    fun removing(index: Int, shares: List<Double>): List<Double> {
        if (index !in shares.indices) return percentages(shares)
        return percentages(shares.filterIndexed { i, _ -> i != index })
    }

    /** Sets one bean's share (kept within 5–95%) and scales the others to fill the rest. */
    fun rebalanced(shares: List<Double>, index: Int, percent: Double): List<Double> {
        val current = percentages(shares)
        if (current.size <= 1 || index !in current.indices) return current
        val target = minOf(95.0, maxOf(5.0, if (percent.isFinite()) percent else current[index]))
        val others = current.indices.filter { it != index }
        val othersTotal = others.sumOf { current[it] }
        val result = current.toMutableList()
        for (other in others) {
            result[other] = if (othersTotal > 0) current[other] / othersTotal * (100 - target)
            else (100 - target) / others.size
        }
        result[index] = target
        return result
    }
}
