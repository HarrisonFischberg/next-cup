package app.rarecreatures.nextcup.kit

import java.time.Instant

/** One taxonomy bucket together with its dimension, so a bean and a past brew can be compared bucket by bucket. */
data class BucketRef(val dimension: Taxonomy.Dimension, val key: String, val name: String) {
    constructor(bucket: Taxonomy.Bucket, dimension: Taxonomy.Dimension) : this(dimension, bucket.key, bucket.name)

    /** Identity for matching: two refs are the same bucket when dimension and key agree. */
    internal val identity: String get() = "${dimension.raw}:$key"
}

/** One saved brew, reduced to what the recommender reads. Canonical units. */
data class RecommenderBrew(
    val date: Instant,
    val ratingTenths: Int? = null,
    /** The method's `builtInKey`, `null` for a method the user made. */
    val methodKey: String? = null,
    val methodName: String,
    val recipeName: String? = null,
    val doseG: Double? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val grindSetting: String? = null,
    val buckets: List<BucketRef> = emptyList(),
) {
    internal val isRated: Boolean get() = (ratingTenths ?: 0) > 0
    /** Brews of the same method group together: by built-in key, else by name. */
    internal val methodID: String get() = methodKey ?: ("name:" + Taxonomy.normalize(methodName))
}

/** The values a brew can start from. Any of them may be missing. */
data class StartParameters(
    val doseG: Double? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val grindSetting: String? = null,
)

/** The computed facts a history-based recommendation stands on. */
data class HistoryFacts(
    val methodBrews: Int,
    val similarBrews: Int,
    val averageTenths: Double,
    val bestTenths: Int,
    val bestDate: Instant,
    val sharedBuckets: List<String>,
)

data class Recommendation(
    val methodKey: String?,
    val methodName: String,
    val recipeName: String?,
    val start: StartParameters,
    val basis: Basis,
) {
    sealed interface Basis {
        data class History(val facts: HistoryFacts) : Basis
        /** Bundled starting point for a roast band; `roast` is null when the medium default was used. */
        data class BundledDefault(val roast: String?) : Basis
    }

    val isDefault: Boolean get() = basis is Basis.BundledDefault

    /** One sentence made only from the computed facts, or the label that says this is a default. */
    val explanation: String get() = when (val b = basis) {
        is Basis.History -> {
            val f = b.facts
            val brews = if (f.methodBrews == 1) "1 brew" else "${f.methodBrews} brews"
            val similar = if (f.similarBrews == f.methodBrews) "" else " of ${f.similarBrews} similar rated brews"
            val shared = if (f.sharedBuckets.isEmpty()) "" else " (${f.sharedBuckets.joinToString(", ")})"
            "Your $brews$similar with beans like this$shared averaged ${Recommender.grade(f.averageTenths)} of 10; the best was ${Recommender.grade(f.bestTenths.toDouble())}."
        }
        is Basis.BundledDefault -> {
            val band = b.roast?.let { "${it.lowercase()} roasts" } ?: "a bean with no roast level"
            "A default starting point for $band. It is not based on your brews yet; grade a few similar brews and this changes."
        }
    }
}

data class RecommendationResult(val items: List<Recommendation>, val isDefault: Boolean, val similarRatedCount: Int)

object Recommender {
    /** How many rated, similar brews it takes before history replaces the default. */
    const val MINIMUM_SIMILAR_BREWS = 3

    /** Flavor and brewer are too loose to decide whether two beans are alike. */
    private val similarityDimensions = setOf(Taxonomy.Dimension.ORIGIN, Taxonomy.Dimension.PROCESS, Taxonomy.Dimension.ROAST)

    private data class Default(val key: String, val name: String, val start: StartParameters)

    /** Bundled starting points by roast band, written for Next Cup. */
    private val defaults = mapOf(
        "light" to Default("cone-dripper", "Cone dripper", StartParameters(15.0, 250.0, 96.0, 165)),
        "medium" to Default("cone-dripper", "Cone dripper", StartParameters(15.0, 250.0, 93.0, 180)),
        "dark" to Default("press", "Press pot", StartParameters(16.0, 250.0, 90.0, 240)),
    )

    /** Ranks the methods that worked best for brews of similar beans, or the bundled default with too little history. */
    fun recommend(beanBuckets: List<BucketRef>, history: List<RecommenderBrew>, limit: Int = 3): RecommendationResult {
        val wanted = beanBuckets.filter { it.dimension in similarityDimensions }
        val wantedIDs = wanted.map { it.identity }.toSet()
        // A bean with only a roast level needs one match; with more it needs two.
        val required = minOf(2, wantedIDs.size)
        val similar = mutableListOf<Pair<RecommenderBrew, Set<BucketRef>>>()
        if (required > 0) for (brew in history) if (brew.isRated) {
            val shared = brew.buckets.filter { it.identity in wantedIDs }.toSet()
            if (shared.size >= required) similar += brew to shared
        }
        if (similar.size < MINIMUM_SIMILAR_BREWS) {
            return RecommendationResult(listOf(bundledDefault(beanBuckets)), true, similar.size)
        }
        val sharedNames = similar.flatMap { it.second }.groupBy { it.identity }.values.map { it.first() }
            .sortedWith(compareBy<BucketRef> { it.dimension.raw }.thenBy { it.name }).map { it.name }

        val groups = similar.map { it.first }.groupBy { it.methodID }
        val ranked = groups.values.map { group ->
            val grades = group.mapNotNull { it.ratingTenths }
            grades.sum().toDouble() / grades.size to group
        }.sortedWith { a, b ->
            when {
                a.first != b.first -> b.first.compareTo(a.first)
                a.second.size != b.second.size -> b.second.size.compareTo(a.second.size)
                else -> {
                    val x = a.second.maxOf { it.date }
                    val y = b.second.maxOf { it.date }
                    if (x != y) y.compareTo(x) else a.second[0].methodID.compareTo(b.second[0].methodID)
                }
            }
        }
        val items = ranked.take(maxOf(1, limit)).map { (average, group) ->
            val best = group.maxWith(compareBy<RecommenderBrew> { it.ratingTenths ?: 0 }.thenBy { it.date })
            val facts = HistoryFacts(group.size, similar.size, average, best.ratingTenths ?: 0, best.date, sharedNames)
            val grind = best.grindSetting?.trim()?.takeIf { it.isNotEmpty() }
            Recommendation(
                best.methodKey, best.methodName, best.recipeName,
                StartParameters(best.doseG, best.waterG, best.tempC, best.totalTimeS, grind),
                Recommendation.Basis.History(facts),
            )
        }
        return RecommendationResult(items, false, similar.size)
    }

    private fun bundledDefault(buckets: List<BucketRef>): Recommendation {
        val roast = buckets.firstOrNull { it.dimension == Taxonomy.Dimension.ROAST }
        val entry = roast?.let { defaults[it.key] }
        val chosen = entry ?: defaults.getValue("medium")
        return Recommendation(chosen.key, chosen.name, null, chosen.start, Recommendation.Basis.BundledDefault(if (entry == null) null else roast.name))
    }

    /** A rating out of 10 with at most one decimal: 74 → "7.4", 80 → "8". */
    internal fun grade(tenths: Double): String = Rating.text(tenths.roundHalfAway().toInt())
}
