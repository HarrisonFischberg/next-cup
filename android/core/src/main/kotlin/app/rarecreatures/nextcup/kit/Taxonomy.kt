package app.rarecreatures.nextcup.kit

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.text.Normalizer

/**
 * Maps the raw words on a bag (origin, process, roast, flavor notes) and the brewer name onto a small set
 * of shared buckets. A user alias always wins over the bundle, so the owner's correction is never undone.
 */
class Taxonomy private constructor(
    val version: Int,
    private val bucketsByDimension: Map<Dimension, List<Bucket>>,
    private val bundledMap: Map<Dimension, Map<String, String>>,
) {
    enum class Dimension(val raw: String) {
        ORIGIN("origin"), PROCESS("process"), ROAST("roast"), FLAVOR("flavor"), BREWER("brewer");

        companion object {
            fun of(raw: String) = entries.firstOrNull { it.raw == raw }
        }
    }

    @Serializable
    data class Bucket(val key: String, val name: String)

    /** A user's own mapping of a raw value to a bucket. `rawValue` is stored normalized. */
    class Alias(val dimension: Dimension, rawValue: String, val bucketKey: String) {
        val rawValue: String = normalize(rawValue)
        override fun equals(other: Any?) =
            other is Alias && other.dimension == dimension && other.rawValue == rawValue && other.bucketKey == bucketKey
        override fun hashCode() = listOf(dimension, rawValue, bucketKey).hashCode()
        override fun toString() = "Alias($dimension, $rawValue -> $bucketKey)"
    }

    /** The result of mapping one raw value. */
    sealed interface Mapping {
        enum class Source { BUNDLE, USER_ALIAS }
        data class Mapped(override val bucket: Bucket, val source: Source) : Mapping
        /** Not in the bundle or the aliases. Offered to the user for mapping. */
        data class Unmapped(val raw: String) : Mapping {
            override val bucket: Bucket? get() = null
        }

        val bucket: Bucket?
    }

    class LoadError(message: String) : Exception(message)

    @Serializable
    private data class Section(val buckets: List<Bucket>, val map: Map<String, String>)

    @Serializable
    private data class File(val version: Int, val dimensions: Map<String, Section>)

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Parses `taxonomy.json`. Throws on an unknown dimension or a map entry pointing at a missing bucket. */
        fun fromJson(text: String): Taxonomy {
            val file = json.decodeFromString(File.serializer(), text)
            val buckets = mutableMapOf<Dimension, List<Bucket>>()
            val maps = mutableMapOf<Dimension, Map<String, String>>()
            for ((name, section) in file.dimensions) {
                val dimension = Dimension.of(name) ?: throw LoadError("unknownDimension($name)")
                val keys = section.buckets.map { it.key }.toSet()
                val normalized = mutableMapOf<String, String>()
                for ((raw, key) in section.map) {
                    if (key !in keys) throw LoadError("unknownBucket($name, $key)")
                    normalized[normalize(raw)] = key
                }
                buckets[dimension] = section.buckets
                maps[dimension] = normalized
            }
            return Taxonomy(file.version, buckets, maps)
        }

        /** Lowercased, accents and punctuation folded, whitespace collapsed: "Costa  Rica" == "costa-rica". */
        fun normalize(raw: String): String {
            val folded = Normalizer.normalize(raw, Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").lowercase()
            return folded.map { if (it.isLetterOrDigit()) it else ' ' }.joinToString("").split(' ').filter { it.isNotEmpty() }.joinToString(" ")
        }
    }

    fun buckets(dimension: Dimension): List<Bucket> = bucketsByDimension[dimension] ?: emptyList()

    /** The bundled words that map to a bucket, normalized and sorted, for the flavor explorer. */
    fun words(bucketKey: String, dimension: Dimension): List<String> =
        (bundledMap[dimension] ?: emptyMap()).filterValues { it == bucketKey }.keys.sorted()

    fun bucket(key: String, dimension: Dimension): Bucket? = buckets(dimension).firstOrNull { it.key == key }

    /** Maps one raw value. Empty input is `Unmapped("")` so a caller can skip it. */
    fun map(raw: String, dimension: Dimension, aliases: List<Alias> = emptyList()): Mapping {
        val normalized = normalize(raw)
        if (normalized.isEmpty()) return Mapping.Unmapped("")
        aliases.lastOrNull { it.dimension == dimension && it.rawValue == normalized }?.let { alias ->
            bucket(alias.bucketKey, dimension)?.let { return Mapping.Mapped(it, Mapping.Source.USER_ALIAS) }
        }
        bundledMap[dimension]?.get(normalized)?.let { key ->
            bucket(key, dimension)?.let { return Mapping.Mapped(it, Mapping.Source.BUNDLE) }
        }
        return Mapping.Unmapped(normalized)
    }

    /** The distinct buckets for a list of raw values, in first-seen order. */
    fun buckets(raws: List<String>, dimension: Dimension, aliases: List<Alias> = emptyList()): List<Bucket> =
        raws.mapNotNull { map(it, dimension, aliases).bucket }.distinct()

    /** Raw values that map nowhere, normalized and de-duplicated, for the "Unmapped" list. */
    fun unmapped(raws: List<String>, dimension: Dimension, aliases: List<Alias> = emptyList()): List<String> =
        raws.mapNotNull { (map(it, dimension, aliases) as? Mapping.Unmapped)?.raw?.takeIf { r -> r.isNotEmpty() } }.distinct()

    /** A new alias list, or `null` when the bucket does not exist or the raw value is empty. */
    fun alias(raw: String, bucketKey: String, dimension: Dimension, replacing: List<Alias> = emptyList()): List<Alias>? {
        val normalized = normalize(raw)
        if (normalized.isEmpty() || bucket(bucketKey, dimension) == null) return null
        return replacing.filterNot { it.dimension == dimension && it.rawValue == normalized } + Alias(dimension, normalized, bucketKey)
    }

    override fun equals(other: Any?) =
        other is Taxonomy && other.version == version && other.bucketsByDimension == bucketsByDimension && other.bundledMap == bundledMap
    override fun hashCode() = version
}
