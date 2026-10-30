package app.rarecreatures.nextcup.kit

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/** One line of text read from a photographed journal page, with how sure the reader was of it (0 to 1). */
data class PaperLine(val text: String, val confidence: Double)

enum class PaperField(val raw: String) { METHOD("method"), BEAN("bean"), DOSE("dose"), WATER("water"), TEMPERATURE("temperature"), TIME("time"), GRIND("grind"), RATING("rating"), NOTES("notes") }

/** What a journal page was read as. Fields not found stay blank and have no confidence entry. */
data class PaperBrewDraft(
    var method: String = "",
    var bean: String = "",
    var grind: String = "",
    var notes: String = "",
    var doseG: Double? = null,
    var waterG: Double? = null,
    var tempC: Double? = null,
    var totalTimeS: Int? = null,
    var ratingTenths: Int? = null,
    val confidence: MutableMap<PaperField, Double> = mutableMapOf(),
) {
    fun needsCheck(field: PaperField): Boolean = (confidence[field] ?: 1.0) < LOW_CONFIDENCE
    val needsCheckCount: Int get() = PaperField.entries.count { needsCheck(it) }
    val isEmpty: Boolean get() = confidence.isEmpty()

    companion object {
        /** Fields read with less confidence than this are highlighted in the review. */
        const val LOW_CONFIDENCE = 0.6
    }
}

/**
 * Reads journal-page text into a [PaperBrewDraft]. Pure text rules, so the same code serves on-device
 * recognition and the AI answer.
 *
 * shortcut: one brew per page, found by its label ("Dose 18 g"); a line with no known label goes to the
 * notes. Upgrade to table or multi-entry pages when real pages need it.
 */
object PaperImport {
    private val labels = listOf(
        PaperField.METHOD to listOf("method", "brewer"),
        PaperField.DOSE to listOf("dose", "coffee", "grounds"),
        PaperField.BEAN to listOf("beans", "bean", "coffee"),
        PaperField.WATER to listOf("water"),
        PaperField.TEMPERATURE to listOf("temperature", "temp"),
        PaperField.TIME to listOf("time"),
        PaperField.GRIND to listOf("grind"),
        PaperField.RATING to listOf("rating", "score", "stars"),
        PaperField.NOTES to listOf("tasting notes", "tasting", "notes", "note", "taste"),
    )

    fun parse(lines: List<PaperLine>): PaperBrewDraft {
        val draft = PaperBrewDraft()
        val leftovers = mutableListOf<PaperLine>()
        for (line in lines) {
            val text = line.text.trim()
            if (text.isEmpty()) continue
            if (!read(text, line.confidence, draft)) leftovers += PaperLine(text, line.confidence)
        }
        if (leftovers.isNotEmpty()) {
            draft.notes = (listOf(draft.notes) + leftovers.map { it.text }).filter { it.isNotEmpty() }.joinToString("\n")
            draft.confidence[PaperField.NOTES] = (leftovers.map { it.confidence } + listOfNotNull(draft.confidence[PaperField.NOTES])).min()
        }
        return draft
    }

    private const val SEPARATORS = ":=-–— \t"

    private fun read(text: String, confidence: Double, draft: PaperBrewDraft): Boolean {
        val lower = text.lowercase()
        for ((field, names) in labels) for (name in names) {
            if (!lower.startsWith(name)) continue
            if (lower.getOrNull(name.length)?.isLetter() == true) continue
            val value = text.drop(name.length).trim { it in SEPARATORS }
            if (set(field, value, confidence, draft)) return true
        }
        return false
    }

    private fun set(field: PaperField, value: String, confidence: Double, draft: PaperBrewDraft): Boolean {
        val first = value.firstOrNull() ?: return false
        // "Water temp 94" is not a water amount: a measurement starts with its number.
        val measured = setOf(PaperField.DOSE, PaperField.WATER, PaperField.TEMPERATURE, PaperField.TIME, PaperField.RATING)
        if (field in measured && !first.isDigit() && first != '★') return false
        when (field) {
            PaperField.METHOD -> draft.method = value
            PaperField.BEAN -> { if (first.isDigit()) return false; draft.bean = value }
            PaperField.GRIND -> draft.grind = value
            PaperField.NOTES -> draft.notes = listOf(draft.notes, value).filter { it.isNotEmpty() }.joinToString("\n")
            PaperField.DOSE -> draft.doseG = weight(value)?.takeIf { it <= 100 } ?: return false
            PaperField.WATER -> draft.waterG = weight(value)?.takeIf { it <= 5000 } ?: return false
            PaperField.TEMPERATURE -> draft.tempC = temperature(value) ?: return false
            PaperField.TIME -> draft.totalTimeS = seconds(value) ?: return false
            PaperField.RATING -> draft.ratingTenths = rating(value) ?: return false
        }
        draft.confidence[field] = minOf(confidence, draft.confidence[field] ?: 1.0)
        return true
    }

    /** The first number in [text] and what follows it. "18,5 g" is 18.5. */
    internal fun number(text: String): Pair<Double, String>? {
        val start = text.indexOfFirst { it.isDigit() }.takeIf { it >= 0 } ?: return null
        var end = start
        var seenSeparator = false
        while (end < text.length) {
            val c = text[end]
            if (c.isDigit()) end++
            else if (!seenSeparator && (c == '.' || c == ',') && end + 1 < text.length && text[end + 1].isDigit()) { seenSeparator = true; end++ }
            else break
        }
        val digits = text.substring(start, end).replace(",", ".")
        return digits.toDoubleOrNull()?.let { it to text.substring(end) }
    }

    private fun weight(text: String): Double? {
        val (value, rest) = number(text) ?: return null
        if (value <= 0) return null
        return when (unit(rest)) {
            "", "g", "gr", "gram", "grams" -> value
            "oz", "ounce", "ounces" -> value * UnitPreferences.GRAMS_PER_OUNCE
            // "3OO g" (letter O for zero) is not 3 g: anything else after the number is unread.
            else -> null
        }
    }

    private fun temperature(text: String): Double? {
        val (value, rest) = number(text) ?: return null
        val celsius = when (unit(rest, "°")) {
            "" -> if (value > 110) (value - 32) * 5 / 9 else value
            "c", "celsius" -> value
            "f", "fahrenheit" -> (value - 32) * 5 / 9
            else -> return null
        }
        return celsius.takeIf { it in 20.0..100.0 }
    }

    private fun unit(rest: String, extra: String = ""): String = rest.trim { it == ' ' || it == '.' || it in extra }.lowercase()

    /** "2:30", "150", "150 s", "2 min 30" and "2.5 min" are all 150 seconds. */
    private fun seconds(text: String): Int? {
        val (first, rest) = number(text) ?: return null
        val tail = rest.trim().lowercase()
        var total: Double
        val colon = if (tail.startsWith(":")) number(tail.drop(1)) else null
        if (colon != null) {
            total = first * 60 + colon.first
        } else if (tail.startsWith("m") && !tail.startsWith("ms")) {
            total = first * 60
            val after = tail.dropWhile { it.isLetter() }.trim()
            number(after)?.let { total += it.first }
        } else if (unit(rest) in listOf("", "s", "sec", "secs", "second", "seconds")) {
            total = first
        } else {
            return null
        }
        return if (total in 1.0..3600.0) total.roundHalfAway().toInt() else null
    }

    /** A rating as tenths out of 10. Stars and "x/5" count double; "x/10" or a bare number above 5 is out of 10. */
    private fun rating(text: String): Int? {
        val stars = text.count { it == '★' }
        var outOfTen = stars * 2.0
        if (stars == 0) {
            val (value, rest) = number(text) ?: return null
            val outOf = number(rest)?.first ?: if (value > 5) 10.0 else 5.0
            outOfTen = if (outOf == 10.0) value else value * 2
        }
        if (outOfTen <= 0 || outOfTen > 10) return null
        return (outOfTen * 10).roundHalfAway().toInt()
    }

    val schema = JSONSchema.Obj(
        mapOf(
            "method" to JSONSchema.Str(), "bean" to JSONSchema.Str(), "doseGrams" to JSONSchema.Num, "waterGrams" to JSONSchema.Num,
            "temperatureCelsius" to JSONSchema.Num, "timeSeconds" to JSONSchema.Num, "grind" to JSONSchema.Str(),
            "ratingOutOfFive" to JSONSchema.Num, "notes" to JSONSchema.Str(), "uncertain" to JSONSchema.Str(),
        ),
    )

    const val SCHEMA_NAME = "journal_page"

    private const val SYSTEM = "You read one handwritten coffee brew journal entry from a photo. Copy only what is written. " +
        "Use an empty string for text you cannot read and 0 for a number you cannot read. Never guess " +
        "or calculate. doseGrams and waterGrams are in grams, temperatureCelsius in degrees Celsius, " +
        "timeSeconds in seconds, ratingOutOfFive from 0.5 to 5. notes holds the tasting notes and " +
        "anything else written. uncertain lists, separated by commas, the fields you are unsure you " +
        "read correctly, using these names: method, bean, dose, water, temperature, time, grind, " +
        "rating, notes."

    /** [photo] must already be sanitized (no metadata); the queue sends it as-is. */
    fun payload(photo: ByteArray) = AIRequestPayload(SYSTEM, "Read this journal entry.", SCHEMA_NAME, schema, photo)

    internal const val AI_SURE = 0.9
    internal const val AI_UNSURE = 0.4

    /** The draft for an AI answer, or `null` when it does not match the schema. Same rules as recognized text. */
    fun draftFromAI(json: String): PaperBrewDraft? {
        val answer = runCatching { Json.parseToJsonElement(json) }.getOrNull() as? JsonObject ?: return null
        if (!schema.validates(answer)) return null
        val unsure = (answer["uncertain"]?.jsonPrimitive?.contentOrNull ?: "").lowercase().split(",").map { it.trim() }.toSet()
        fun str(key: String) = answer[key]?.jsonPrimitive?.contentOrNull
        fun line(label: String, field: PaperField, value: String?): PaperLine? {
            val v = value?.trim()?.takeIf { it.isNotEmpty() } ?: return null
            val name = if (field == PaperField.TEMPERATURE) "temp" else field.raw
            return PaperLine("$label $v", if (name in unsure) AI_UNSURE else AI_SURE)
        }
        fun amount(key: String, suffix: String): String? = JSONSchema.number(answer[key])?.takeIf { it > 0 }?.let { "$it $suffix" }
        return parse(
            listOfNotNull(
                line("Method:", PaperField.METHOD, str("method")),
                line("Beans:", PaperField.BEAN, str("bean")),
                line("Dose:", PaperField.DOSE, amount("doseGrams", "g")),
                line("Water:", PaperField.WATER, amount("waterGrams", "g")),
                line("Temp:", PaperField.TEMPERATURE, amount("temperatureCelsius", "C")),
                line("Time:", PaperField.TIME, amount("timeSeconds", "s")),
                line("Grind:", PaperField.GRIND, str("grind")),
                line("Rating:", PaperField.RATING, amount("ratingOutOfFive", "/ 5")),
                line("Notes:", PaperField.NOTES, str("notes")),
            ),
        )
    }
}
