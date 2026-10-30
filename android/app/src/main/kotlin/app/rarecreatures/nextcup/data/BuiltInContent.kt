package app.rarecreatures.nextcup.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Decoded form of the bundled `methods.json` and `recipes.json`, shared with iOS. `version` only grows; the
 * seeder keys on `key`, never on version, so it stays idempotent.
 */
data class BuiltInContent(
    val methodsVersion: Int,
    val methods: List<MethodEntry>,
    val recipesVersion: Int,
    val recipes: List<RecipeEntry>,
) {
    @Serializable
    data class MethodEntry(
        val key: String,
        val name: String,
        val style: String,
        val symbol: String,
        val trackedParameters: List<String>,
        val defaultStepKinds: List<String>,
    )

    @Serializable
    data class StepEntry(val kind: String, val startOffsetS: Int, val targetCumulativeWaterG: Double? = null, val instruction: String)

    @Serializable
    data class RecipeEntry(
        val key: String,
        val methodKey: String,
        val name: String,
        val doseG: Double,
        val waterG: Double,
        val tempC: Double? = null,
        val totalTimeS: Int? = null,
        val tuningNote: String? = null,
        val includesIce: Boolean,
        val iceG: Double? = null,
        val credit: String? = null,
        val creditURL: String? = null,
        val steps: List<StepEntry>,
    )

    @Serializable private data class MethodsFile(val version: Int, val methods: List<MethodEntry>)
    @Serializable private data class RecipesFile(val version: Int, val recipes: List<RecipeEntry>)

    class UnknownValue(message: String) : Exception(message)

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Parses both documents. Throws on an unknown enum value so a bad bundle fails in tests, not at seed time. */
        fun parse(methodsJSON: String, recipesJSON: String): BuiltInContent {
            val m = json.decodeFromString(MethodsFile.serializer(), methodsJSON)
            val r = json.decodeFromString(RecipesFile.serializer(), recipesJSON)
            for (method in m.methods) {
                require<BrewStyle>(method.style)
                method.trackedParameters.forEach { require<BrewParameter>(it) }
                method.defaultStepKinds.forEach { require<StepKind>(it) }
            }
            r.recipes.forEach { recipe -> recipe.steps.forEach { require<StepKind>(it.kind) } }
            return BuiltInContent(m.version, m.methods, r.version, r.recipes)
        }

        private inline fun <reified E> require(raw: String): E where E : Enum<E>, E : RawEnum =
            rawOf<E>(raw) ?: throw UnknownValue("${E::class.simpleName}: $raw")
    }
}
