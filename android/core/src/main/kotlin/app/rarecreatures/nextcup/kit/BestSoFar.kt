package app.rarecreatures.nextcup.kit

import java.time.Instant

/** One saved brew of a bean, reduced to the values the best-so-far card reads. */
data class BrewSample(
    val date: Instant,
    val ratingTenths: Int? = null,
    val doseG: Double? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val grindSetting: String? = null,
    val grinder: String? = null,
) {
    internal val isRated: Boolean get() = (ratingTenths ?: 0) > 0
}

data class RatingCount(val tenths: Int, val brews: Int)

/** One grind setting used at one dose on one grinder, with how it turned out. */
data class GrindEntry(
    val grinder: String?,
    val doseG: Double?,
    val setting: String,
    val brews: Int,
    val averageTenths: Double?,
    val lastUsed: Instant,
)

data class BestSoFarSummary(
    val brewCount: Int,
    val ratedCount: Int,
    val spread: List<RatingCount>,
    val averageTenths: Double?,
    /** The highest-graded brew (the newest of any tie); `null` until a brew is graded. */
    val best: BrewSample?,
    /** Sorted by grinder (unnamed last), then dose, then newest first. */
    val grindHistory: List<GrindEntry>,
)

object BestSoFar {
    fun summarize(samples: List<BrewSample>): BestSoFarSummary {
        val rated = samples.filter { it.isRated }
        val counts = rated.groupBy { it.ratingTenths ?: 0 }.map { RatingCount(it.key, it.value.size) }.sortedBy { it.tenths }
        val average = if (rated.isEmpty()) null else rated.sumOf { it.ratingTenths ?: 0 }.toDouble() / rated.size
        val best = rated.maxWithOrNull(compareBy<BrewSample> { it.ratingTenths ?: 0 }.thenBy { it.date })
        return BestSoFarSummary(samples.size, rated.size, counts, average, best, grindHistory(samples))
    }

    private data class Key(val grinder: String?, val dose: Int?, val setting: String)

    private fun grindHistory(samples: List<BrewSample>): List<GrindEntry> {
        val groups = linkedMapOf<Key, MutableList<BrewSample>>()
        for (sample in samples) {
            val setting = sample.grindSetting?.trim().orEmpty()
            if (setting.isEmpty()) continue
            val grinder = sample.grinder?.trim()?.takeIf { it.isNotEmpty() }
            val key = Key(grinder, sample.doseG?.let { (it * 10).roundHalfAway().toInt() }, setting)
            groups.getOrPut(key) { mutableListOf() } += sample
        }
        val entries = groups.map { (key, group) ->
            val grades = group.mapNotNull { if (it.isRated) it.ratingTenths else null }
            GrindEntry(
                key.grinder, key.dose?.let { it / 10.0 }, key.setting, group.size,
                if (grades.isEmpty()) null else grades.sum().toDouble() / grades.size,
                group.maxOf { it.date },
            )
        }
        return entries.sortedWith { a, b ->
            val ga = a.grinder
            val gb = b.grinder
            when {
                ga != null && gb != null && ga != gb -> Strings.localizedStandardCompare(ga, gb)
                ga != null && gb == null -> -1
                ga == null && gb != null -> 1
                a.doseG != b.doseG -> (a.doseG ?: -1.0).compareTo(b.doseG ?: -1.0)
                else -> b.lastUsed.compareTo(a.lastUsed)
            }
        }
    }
}

internal object Strings {
    /** Finder-style compare: case-insensitive, with digit runs compared as numbers. */
    fun localizedStandardCompare(a: String, b: String): Int {
        val ra = Regex("\\d+|\\D+").findAll(a.lowercase()).map { it.value }.toList()
        val rb = Regex("\\d+|\\D+").findAll(b.lowercase()).map { it.value }.toList()
        for (i in 0 until minOf(ra.size, rb.size)) {
            val x = ra[i]
            val y = rb[i]
            val c = if (x[0].isDigit() && y[0].isDigit()) x.toBigInteger().compareTo(y.toBigInteger()) else x.compareTo(y)
            if (c != 0) return c
        }
        return ra.size.compareTo(rb.size)
    }
}
