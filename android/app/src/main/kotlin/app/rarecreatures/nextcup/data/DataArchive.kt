package app.rarecreatures.nextcup.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.Base64

/**
 * The whole export, in exactly the JSON iOS's DataArchive writes (Swift JSONEncoder defaults, sorted keys):
 * dates are seconds since 2001-01-01, bytes are base64, ids are uppercase UUIDs and relationships are ids.
 * An export from either app imports into the other. `version` 2 has ratings in tenths out of 10.
 */
data class DataArchive(
    val version: Int = CURRENT_VERSION,
    val exportedAt: Long = now(),
    val methods: List<BrewMethod> = emptyList(),
    val grinders: List<Grinder> = emptyList(),
    val roasters: List<Roaster> = emptyList(),
    val waterProfiles: List<WaterProfile> = emptyList(),
    val aliases: List<TaxonomyAlias> = emptyList(),
    val recipes: List<Recipe> = emptyList(),
    val steps: List<RecipeStep> = emptyList(),
    val beans: List<Bean> = emptyList(),
    val brews: List<Brew> = emptyList(),
    val brewBeans: List<BrewBean> = emptyList(),
    val suggestions: List<Suggestion> = emptyList(),
) {
    class Unreadable : Exception("That file isn't a Next Cup export.")
    class NewerVersion(val version: Int) : Exception("This export is from a newer version of Next Cup. Update the app, then import it.")

    companion object {
        const val CURRENT_VERSION = 2
        /** Seconds between 1970-01-01 and Swift's reference date, 2001-01-01. */
        private const val REFERENCE_OFFSET_S = 978_307_200.0

        fun swiftDate(millis: Long): Double = millis / 1000.0 - REFERENCE_OFFSET_S
        fun millis(swift: Double): Long = Math.round((swift + REFERENCE_OFFSET_S) * 1000)

        // Writing

        private fun s(v: String?): JsonElement = v?.let(::JsonPrimitive) ?: JsonNull
        private fun n(v: Number?): JsonElement = v?.let(::JsonPrimitive) ?: JsonNull
        private fun d(v: Long?): JsonElement = v?.let { JsonPrimitive(swiftDate(it)) } ?: JsonNull
        private fun b(v: ByteArray?): JsonElement = v?.let { JsonPrimitive(Base64.getEncoder().encodeToString(it)) } ?: JsonNull
        private fun list(v: List<String>?): JsonElement = v?.let { JsonArray(it.map(::JsonPrimitive)) } ?: JsonNull

        /** Swift's encoder leaves nil optionals out entirely; so does this. */
        private fun obj(vararg pairs: Pair<String, JsonElement>) = JsonObject(sortedMapOf(*pairs.filter { it.second !is JsonNull }.toTypedArray()))

        private fun base(id: String, created: Long, updated: Long) = arrayOf("id" to s(id), "createdAt" to d(created), "updatedAt" to d(updated))

        fun encode(a: DataArchive): String = obj(
            "version" to n(a.version), "exportedAt" to d(a.exportedAt),
            "methods" to JsonArray(a.methods.map { m ->
                obj(*base(m.id, m.createdAt, m.updatedAt), "name" to s(m.name), "style" to s(m.style.raw), "symbol" to s(m.symbol),
                    "trackedParameters" to list(m.trackedParameters.map { it.raw }), "defaultStepKinds" to list(m.defaultStepKinds.map { it.raw }),
                    "sortOrder" to n(m.sortOrder), "isHidden" to JsonPrimitive(m.isHidden), "builtInKey" to s(m.builtInKey))
            }),
            "grinders" to JsonArray(a.grinders.map { g -> obj(*base(g.id, g.createdAt, g.updatedAt), "name" to s(g.name), "notes" to s(g.notes)) }),
            "roasters" to JsonArray(a.roasters.map { r ->
                obj(*base(r.id, r.createdAt, r.updatedAt), "name" to s(r.name), "city" to s(r.city), "website" to s(r.website),
                    "latitude" to n(r.latitude), "longitude" to n(r.longitude), "savedFromMap" to JsonPrimitive(r.savedFromMap))
            }),
            "waterProfiles" to JsonArray(a.waterProfiles.map { w ->
                obj(*base(w.id, w.createdAt, w.updatedAt), "name" to s(w.name), "ppmHardness" to n(w.ppmHardness), "ppmAlkalinity" to n(w.ppmAlkalinity),
                    "calcium" to n(w.calcium), "magnesium" to n(w.magnesium), "sodium" to n(w.sodium))
            }),
            "aliases" to JsonArray(a.aliases.map { x -> obj(*base(x.id, x.createdAt, x.updatedAt), "dimension" to s(x.dimension.raw), "rawValue" to s(x.rawValue), "bucketKey" to s(x.bucketKey)) }),
            "recipes" to JsonArray(a.recipes.map { r ->
                obj(*base(r.id, r.createdAt, r.updatedAt), "name" to s(r.name), "credit" to s(r.credit), "creditURL" to s(r.creditURL), "doseG" to n(r.doseG),
                    "waterG" to n(r.waterG), "tempC" to n(r.tempC), "totalTimeS" to n(r.totalTimeS), "tuningNote" to s(r.tuningNote),
                    "includesIce" to JsonPrimitive(r.includesIce), "iceG" to n(r.iceG), "builtInKey" to s(r.builtInKey), "methodID" to s(r.methodId))
            }),
            "steps" to JsonArray(a.steps.map { x ->
                obj(*base(x.id, x.createdAt, x.updatedAt), "order" to n(x.order), "kind" to s(x.kind.raw), "startOffsetS" to n(x.startOffsetS),
                    "targetCumulativeWaterG" to n(x.targetCumulativeWaterG), "instruction" to s(x.instruction), "recipeID" to s(x.recipeId))
            }),
            "beans" to JsonArray(a.beans.map { x ->
                obj(*base(x.id, x.createdAt, x.updatedAt), "name" to s(x.name), "originCountry" to s(x.originCountry), "region" to s(x.region),
                    "farm" to s(x.farm), "process" to s(x.process), "varietal" to s(x.varietal), "roastLevel" to s(x.roastLevel?.raw),
                    "roastDate" to d(x.roastDate), "bagFlavorNotes" to list(x.bagFlavorNotes), "bagWeightG" to n(x.bagWeightG),
                    "remainingAdjustmentG" to n(x.remainingAdjustmentG), "status" to s(x.status.raw), "isDecaf" to JsonPrimitive(x.isDecaf),
                    "frozenOn" to d(x.frozenOn), "thawedOn" to d(x.thawedOn), "ratingTenths" to n(x.ratingTenths), "photo" to b(x.photo), "roasterID" to s(x.roasterId))
            }),
            "brews" to JsonArray(a.brews.map { x ->
                obj(*base(x.id, x.createdAt, x.updatedAt), "date" to d(x.date), "doseG" to n(x.doseG), "waterG" to n(x.waterG), "yieldG" to n(x.yieldG),
                    "grindSetting" to s(x.grindSetting), "grindValue" to n(x.grindValue), "tempC" to n(x.tempC), "totalTimeS" to n(x.totalTimeS),
                    "tds" to n(x.tds), "ratingTenths" to n(x.ratingTenths), "verdict" to s(x.verdict?.raw), "alsoTasted" to list(x.alsoTasted),
                    "notes" to s(x.notes), "photo" to b(x.photo), "targetsJSON" to b(x.targetsJSON?.toByteArray()), "isDraft" to JsonPrimitive(x.isDraft),
                    "methodID" to s(x.methodId), "recipeID" to s(x.recipeId), "grinderID" to s(x.grinderId), "waterProfileID" to s(x.waterProfileId),
                    "suggestionFollowedID" to s(x.suggestionFollowedId))
            }),
            "brewBeans" to JsonArray(a.brewBeans.map { x ->
                obj(*base(x.id, x.createdAt, x.updatedAt), "grams" to n(x.grams), "beanNameSnapshot" to s(x.beanNameSnapshot), "brewID" to s(x.brewId), "beanID" to s(x.beanId))
            }),
            "suggestions" to JsonArray(a.suggestions.map { x ->
                obj(*base(x.id, x.createdAt, x.updatedAt), "source" to s(x.source.raw), "field" to s(x.field.raw), "fromValue" to s(x.fromValue),
                    "toValue" to s(x.toValue), "rationale" to s(x.rationale), "state" to s(x.state.raw), "modelID" to s(x.modelID), "sourceBrewID" to s(x.sourceBrewId))
            }),
        ).toString()

        // Reading

        private class R(val o: JsonObject) {
            fun str(k: String) = (o[k] as? JsonPrimitive)?.takeIf { it.isString }?.content
            fun req(k: String) = str(k) ?: throw Unreadable()
            fun id(k: String) = str(k)?.uppercase()
            fun dbl(k: String) = (o[k] as? JsonPrimitive)?.takeIf { !it.isString }?.doubleOrNull
            fun int(k: String) = (o[k] as? JsonPrimitive)?.takeIf { !it.isString }?.intOrNull ?: dbl(k)?.toInt()
            fun bool(k: String) = (o[k] as? JsonPrimitive)?.booleanOrNull ?: false
            fun date(k: String) = dbl(k)?.let(::millis)
            fun bytes(k: String) = str(k)?.let { runCatching { Base64.getDecoder().decode(it) }.getOrNull() }
            fun strings(k: String) = (o[k] as? JsonArray)?.mapNotNull { it.jsonPrimitive.contentOrNull }
            val idv get() = req("id").uppercase()
            val created get() = date("createdAt") ?: now()
            val updated get() = date("updatedAt") ?: now()
            /** Version 1 archives held half points out of 5. */
            fun rating() = int("ratingTenths") ?: int("ratingHalfSteps")?.let { it * 10 }
        }

        private inline fun <reified E> enumOr(raw: String?, fallback: E): E where E : Enum<E>, E : RawEnum = rawOf<E>(raw) ?: fallback

        fun decode(text: String): DataArchive {
            val root = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrNull() ?: throw Unreadable()
            val version = (root["version"] as? JsonPrimitive)?.intOrNull ?: throw Unreadable()
            if (version > CURRENT_VERSION) throw NewerVersion(version)
            fun rows(key: String): List<R> = (root[key] as? JsonArray)?.map { R(it.jsonObject) } ?: emptyList()
            return try {
                DataArchive(
                    version = version,
                    exportedAt = R(root).date("exportedAt") ?: now(),
                    methods = rows("methods").map { r ->
                        BrewMethod(r.idv, r.created, r.updated, r.req("name"), enumOr(r.str("style"), BrewStyle.POUR_OVER), r.str("symbol") ?: "cup.and.saucer",
                            r.strings("trackedParameters").orEmpty().mapNotNull { rawOf<BrewParameter>(it) }, r.strings("defaultStepKinds").orEmpty().mapNotNull { rawOf<StepKind>(it) },
                            r.int("sortOrder") ?: 0, r.bool("isHidden"), r.str("builtInKey"))
                    },
                    grinders = rows("grinders").map { r -> Grinder(r.idv, r.created, r.updated, r.req("name"), r.str("notes")) },
                    roasters = rows("roasters").map { r ->
                        Roaster(r.idv, r.created, r.updated, r.req("name"), r.str("city"), r.str("website"), r.dbl("latitude"), r.dbl("longitude"), r.bool("savedFromMap"))
                    },
                    waterProfiles = rows("waterProfiles").map { r ->
                        WaterProfile(r.idv, r.created, r.updated, r.req("name"), r.dbl("ppmHardness"), r.dbl("ppmAlkalinity"), r.dbl("calcium"), r.dbl("magnesium"), r.dbl("sodium"))
                    },
                    aliases = rows("aliases").map { r -> TaxonomyAlias(r.idv, r.created, r.updated, enumOr(r.str("dimension"), TaxonomyDimension.ORIGIN), r.req("rawValue"), r.req("bucketKey")) },
                    recipes = rows("recipes").map { r ->
                        Recipe(r.idv, r.created, r.updated, r.req("name"), r.str("credit"), r.str("creditURL"), r.dbl("doseG") ?: 0.0, r.dbl("waterG") ?: 0.0, r.dbl("tempC"),
                            r.int("totalTimeS"), r.str("tuningNote"), r.bool("includesIce"), r.dbl("iceG"), r.str("builtInKey"), r.id("methodID"))
                    },
                    steps = rows("steps").map { r ->
                        RecipeStep(r.idv, r.created, r.updated, r.int("order") ?: 0, enumOr(r.str("kind"), StepKind.POUR), r.int("startOffsetS") ?: 0,
                            r.dbl("targetCumulativeWaterG"), r.str("instruction") ?: "", r.id("recipeID"))
                    },
                    beans = rows("beans").map { r ->
                        Bean(r.idv, r.created, r.updated, r.req("name"), r.str("originCountry"), r.str("region"), r.str("farm"), r.str("process"), r.str("varietal"),
                            rawOf<RoastLevel>(r.str("roastLevel")), r.date("roastDate"), r.strings("bagFlavorNotes").orEmpty(), r.dbl("bagWeightG"),
                            r.dbl("remainingAdjustmentG") ?: 0.0, enumOr(r.str("status"), BeanStatus.IN_USE), r.bool("isDecaf"), r.date("frozenOn"), r.date("thawedOn"),
                            r.rating(), r.bytes("photo"), null, r.id("roasterID"))
                    },
                    brews = rows("brews").map { r ->
                        Brew(r.idv, r.created, r.updated, r.date("date") ?: r.created, r.dbl("doseG"), r.dbl("waterG"), r.dbl("yieldG"), r.str("grindSetting"),
                            r.dbl("grindValue"), r.dbl("tempC"), r.int("totalTimeS"), r.dbl("tds"), r.rating(), rawOf<Verdict>(r.str("verdict")), r.strings("alsoTasted"),
                            r.str("notes") ?: "", r.bytes("photo"), r.bytes("targetsJSON")?.decodeToString(), r.bool("isDraft"), r.id("methodID"), r.id("recipeID"),
                            r.id("grinderID"), r.id("waterProfileID"), r.id("suggestionFollowedID"))
                    },
                    brewBeans = rows("brewBeans").map { r -> BrewBean(r.idv, r.created, r.updated, r.dbl("grams") ?: 0.0, r.str("beanNameSnapshot") ?: "", r.id("brewID"), r.id("beanID")) },
                    suggestions = rows("suggestions").map { r ->
                        Suggestion(r.idv, r.created, r.updated, enumOr(r.str("source"), SuggestionSource.RULES), enumOr(r.str("field"), BrewParameter.GRIND),
                            r.str("fromValue") ?: "", r.str("toValue") ?: "", r.str("rationale") ?: "", enumOr(r.str("state"), SuggestionState.PROPOSED), r.str("modelID"), r.id("sourceBrewID"))
                    },
                )
            } catch (e: Unreadable) {
                throw e
            } catch (e: Exception) {
                throw Unreadable()
            }
        }
    }
}
