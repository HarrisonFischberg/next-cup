package app.rarecreatures.nextcup.ai

import app.rarecreatures.nextcup.brew.SuggestionApplication
import app.rarecreatures.nextcup.data.AIFeature
import app.rarecreatures.nextcup.data.AIRequest
import app.rarecreatures.nextcup.data.AIRequestStatus
import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.BrewMethod
import app.rarecreatures.nextcup.data.BrewParameter
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.data.Suggestion
import app.rarecreatures.nextcup.data.SuggestionSource
import app.rarecreatures.nextcup.data.rawOf
import app.rarecreatures.nextcup.kit.AIRequestPayload
import app.rarecreatures.nextcup.kit.JSONSchema
import app.rarecreatures.nextcup.kit.Rating
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Turns AI brew diagnosis into the same Suggestion cards the rules make, as on iOS. The model only picks a
 * field, a new value and a reason; the old value comes from the brew, and anything that does not validate stores nothing.
 */
object AISuggestions {
    val fields = listOf(BrewParameter.GRIND, BrewParameter.WATER, BrewParameter.TEMPERATURE, BrewParameter.TIME)

    val schema = JSONSchema.Obj(mapOf("field" to JSONSchema.Str(fields.map { it.raw }), "toValue" to JSONSchema.Str(), "rationale" to JSONSchema.Str()))
    private const val SCHEMA_NAME = "dial_in_suggestion"
    private const val SYSTEM = "You are a coffee brewing coach. Suggest exactly one change to try on the next brew. " +
        "Choose field from grind, water (grams), temperature (degrees Celsius) or time (seconds). " +
        "toValue is the new value: a number for water, temperature and time, a grind setting " +
        "in the user's own scale for grind. rationale is one or two plain sentences that use " +
        "only the brews given."

    /** One brew in the words a request sends: the same text the disclosure screen shows. */
    data class Described(val brew: Brew, val method: BrewMethod?, val beans: List<Bean>)

    fun payload(d: Described) = AIRequestPayload(SYSTEM, "Diagnose this brew.\n" + describe(d), SCHEMA_NAME, schema)

    fun payloadInsights(brews: List<Described>) = AIRequestPayload(
        SYSTEM, "Find the pattern in these brews of the same coffee, newest first.\n" + brews.sortedByDescending { it.brew.date }.take(8).joinToString("\n") { describe(it) },
        SCHEMA_NAME, schema,
    )

    private fun describe(d: Described): String {
        val b = d.brew
        val parts = mutableListOf(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.US).withZone(ZoneId.systemDefault()).format(Instant.ofEpochMilli(b.date)))
        d.method?.let { parts += "method ${it.name}" }
        d.beans.forEach { bean -> parts += "bean " + listOfNotNull(bean.originCountry, bean.process, bean.roastLevel?.raw).joinToString(", ") }
        b.doseG?.let { parts += "dose ${SuggestionApplication.number(it)} g" }
        b.waterG?.let { parts += "water ${SuggestionApplication.number(it)} g" }
        b.grindSetting?.takeIf { it.isNotEmpty() }?.let { parts += "grind $it" }
        b.tempC?.let { parts += "temperature ${SuggestionApplication.number(it)} C" }
        b.totalTimeS?.let { parts += "time $it s" }
        if (b.verdicts.isNotEmpty()) parts += "tasted " + b.verdicts.joinToString(" and ") { it.raw }
        b.ratingTenths?.let { parts += "rating ${Rating.text(it)} of 10" }
        if (b.notes.isNotEmpty()) parts += "notes: ${b.notes}"
        return "- " + parts.joinToString("; ")
    }

    private fun current(field: BrewParameter, b: Brew) = when (field) {
        BrewParameter.GRIND -> b.grindSetting ?: ""
        BrewParameter.WATER -> b.waterG?.let(SuggestionApplication::number) ?: ""
        BrewParameter.TEMPERATURE -> b.tempC?.let(SuggestionApplication::number) ?: ""
        BrewParameter.TIME -> b.totalTimeS?.toString() ?: ""
        else -> ""
    }

    private fun usable(text: String, field: BrewParameter) = when (field) {
        BrewParameter.GRIND -> text.isNotEmpty()
        BrewParameter.WATER -> (text.toDoubleOrNull() ?: 0.0) > 0
        BrewParameter.TEMPERATURE -> text.toDoubleOrNull() != null
        BrewParameter.TIME -> (text.toDoubleOrNull() ?: -1.0) >= 0
        else -> false
    }

    /** Makes the Suggestion for a finished diagnosis. It takes the request's id, so ingesting twice never doubles it. */
    suspend fun ingest(request: AIRequest, db: NextCupDatabase): Suggestion? {
        if (request.feature != AIFeature.DIAGNOSIS && request.feature != AIFeature.INSIGHTS) return null
        if (request.status != AIRequestStatus.DONE) return null
        val brew = request.brewId?.let { db.brews().find(it) } ?: return null
        val answer = runCatching { Json.parseToJsonElement(request.resultJSON ?: return null) }.getOrNull() as? JsonObject ?: return null
        if (!schema.validates(answer)) return null
        val field = rawOf<BrewParameter>(answer["field"]?.jsonPrimitive?.contentOrNull) ?: return null
        val toValue = answer["toValue"]?.jsonPrimitive?.contentOrNull?.trim() ?: return null
        val rationale = answer["rationale"]?.jsonPrimitive?.contentOrNull ?: return null
        if (!usable(toValue, field)) return null
        db.suggestions().find(request.id)?.let { return it }
        val s = Suggestion(
            id = request.id, source = SuggestionSource.AI, field = field, fromValue = current(field, brew), toValue = toValue,
            rationale = rationale, modelID = request.modelID, sourceBrewId = brew.id,
        )
        db.suggestions().upsert(s)
        return s
    }
}
