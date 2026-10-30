package app.rarecreatures.nextcup.kit

import java.text.Normalizer
import java.time.LocalDate

/**
 * Conservative readers for text found on a coffee bag (OCR lines, top to bottom). They return a value
 * only when the label states it plainly, so a guess never fills a field.
 */
object LabelEvidence {
    private val roastWords = listOf("roast", "röst", "rost", "tost", "tueste", "torr")
    private val otherDates = listOf(
        "best", "use by", "exp", "bb", "mhd", "consum", "pack", "harvest", "cosecha", "ernte", "récolte", "mindestens", "caduc",
    )
    /** Printed text is data: a line that reads like an instruction is never evidence. */
    private val instruction = Regex("\\b(?:ignore|instructions?|set|change|use|should|must)\\b")
    private val months = mapOf(
        "jan" to 1, "ene" to 1, "gen" to 1, "feb" to 2, "fev" to 2, "mar" to 3, "apr" to 4, "abr" to 4, "avr" to 4,
        "may" to 5, "mai" to 5, "mag" to 5, "jun" to 6, "jui" to 6, "giu" to 6, "jul" to 7, "lug" to 7,
        "aug" to 8, "ago" to 8, "aou" to 8, "sep" to 9, "set" to 9, "oct" to 10, "okt" to 10, "ott" to 10,
        "nov" to 11, "dec" to 12, "dez" to 12, "dic" to 12,
    )

    /** The roast date as `yyyy-MM-dd`, or null when none is stated unambiguously or lines disagree. */
    fun roastDate(lines: List<String>): String? = roastDates(lines).singleOrNull()

    /** Every distinct roast date the lines state plainly. */
    fun roastDates(lines: List<String>): Set<String> = lines.mapNotNull { line ->
        val text = fold(line)
        if (roastWords.none { text.contains(fold(it)) } || otherDates.any { text.contains(fold(it)) } || instruction.containsMatchIn(text)) null
        else date(text)
    }.toSet()

    /** The bag weight in grams. Grams or kilograms win over ounces or pounds. */
    fun bagWeightGrams(lines: List<String>): Double? {
        val pattern = Regex("(\\d+(?:[.,]\\d+)?)\\s*(kg|grams|gram|gr|g|oz|lbs|lb)\\b")
        var metric: Double? = null
        var imperial: Double? = null
        for (line in lines) for (m in pattern.findAll(fold(line))) {
            val value = m.groupValues[1].replace(",", ".").toDoubleOrNull()?.takeIf { it > 0 } ?: continue
            when (m.groupValues[2]) {
                "kg" -> metric = metric ?: (value * 1000)
                "oz" -> imperial = imperial ?: (value * 28.3495)
                "lb", "lbs" -> imperial = imperial ?: (value * 453.592)
                else -> metric = metric ?: value
            }
        }
        return (metric ?: imperial)?.let { (it * 10).roundHalfAway() / 10 }
    }

    /** Whether any line names a farm or producer, the only evidence for a farm field. */
    fun namesFarm(lines: List<String>): Boolean {
        val words = listOf("farm", "finca", "estate", "hacienda", "fazenda", "producer", "productor", "sitio")
        return lines.any { line -> words.any { fold(line).contains(it) } }
    }

    /** Whether a line states a roast level, the only evidence for a roast-level field. */
    fun statesRoastLevel(lines: List<String>): Boolean {
        val levels = listOf("light", "medium", "dark", "city", "hell", "dunkel", "claro", "oscuro", "medio")
        return lines.any { line ->
            val text = fold(line)
            roastWords.any { text.contains(fold(it)) } && levels.any { text.contains(it) }
        }
    }

    private fun fold(text: String): String =
        Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")

    private fun date(text: String): String? {
        val cleaned = text.replace(Regex("(\\d)(st|nd|rd|th)\\b"), "$1")
        Regex("\\b(\\d{4})[-/.](\\d{1,2})[-/.](\\d{1,2})\\b").find(cleaned)?.let { m ->
            return valid(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toInt())
        }
        Regex("\\b(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4})\\b").find(cleaned)?.let { m ->
            return valid(m.groupValues[3].toInt(), m.groupValues[2].toInt(), m.groupValues[1].toInt())
        }
        Regex("\\b(\\d{1,2})/(\\d{1,2})/(\\d{4})\\b").find(cleaned)?.let { m ->
            val a = m.groupValues[1].toInt()
            val b = m.groupValues[2].toInt()
            val year = m.groupValues[3].toInt()
            // 03/04/2026 could be either order; only a day above 12 or equal parts settle it.
            if (a > 12) return valid(year, b, a)
            if (b > 12 || a == b) return valid(year, a, b)
            return null
        }
        Regex("\\b(\\d{1,2})\\.?\\s+(?:de\\s+)?([a-z]{3,})\\.?,?\\s+(?:de\\s+)?(\\d{4})\\b").find(cleaned)?.let { m ->
            months[m.groupValues[2].take(3)]?.let { month -> return valid(m.groupValues[3].toInt(), month, m.groupValues[1].toInt()) }
        }
        Regex("\\b([a-z]{3,})\\.?\\s+(\\d{1,2}),?\\s+(\\d{4})\\b").find(cleaned)?.let { m ->
            months[m.groupValues[1].take(3)]?.let { month -> return valid(m.groupValues[3].toInt(), month, m.groupValues[2].toInt()) }
        }
        return null
    }

    private fun valid(year: Int, month: Int, day: Int): String? {
        if (year !in 2000..2100) return null
        return runCatching { LocalDate.of(year, month, day) }.getOrNull()?.toString()
    }
}
