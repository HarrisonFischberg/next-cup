package app.rarecreatures.nextcup.kit

import kotlin.math.pow

/**
 * Starting grind ranges for popular grinders, per brew method, in each grinder's own notation.
 * Source: Honest Coffee Guide's per-grinder tables (each entry links its page), read 2026-10-26.
 * Starting points only: the user dials in from here by taste. `espresso` is null where the maker
 * sells the grinder for brewed coffee only.
 */
data class GrinderGuide(
    val name: String,
    /** "Hand" or "Electric". */
    val kind: String,
    /** How the dial reads: clicks, dial, rotations, rotation.number.tick, number.click. */
    val notation: String,
    val pourOver: String?,
    val aeroPress: String?,
    val frenchPress: String?,
    val moka: String?,
    val espresso: String?,
    val coldBrew: String?,
    val source: String,
) {
    enum class Method { POUR_OVER, AERO_PRESS, FRENCH_PRESS, MOKA, ESPRESSO, COLD_BREW }

    val id: String get() = name

    fun range(method: Method): String? = when (method) {
        Method.POUR_OVER -> pourOver
        Method.AERO_PRESS -> aeroPress
        Method.FRENCH_PRESS -> frenchPress
        Method.MOKA -> moka
        Method.ESPRESSO -> espresso
        Method.COLD_BREW -> coldBrew
    }

    /** One setting to start at: the middle of a plain-number range (whole stays whole), otherwise the finer end. */
    fun recommended(method: Method): String? {
        val range = range(method) ?: return null
        val ends = range.split("–").map { it.trim() }
        if (ends.size != 2) return range
        val low = ends[0].toDoubleOrNull()
        val high = ends[1].toDoubleOrNull()
        if (low == null || high == null || ends[0].count { it == '.' } >= 2) return ends[0]
        val middle = (low + high) / 2
        if (!ends[0].contains('.') && !ends[1].contains('.')) return middle.roundHalfAway().toInt().toString()
        val decimals = maxOf(ends[0].split(".").last().length, 1)
        return fmt("%.${minOf(decimals, 2)}f", middle)
    }

    /** Words for the notation, said after a range: "15 – 25 clicks". */
    val unitLabel: String get() = when (notation) {
        "clicks" -> "clicks"
        "rotations" -> "rotations"
        "rotation.number.tick" -> "(rotation.number.tick)"
        "number.click" -> "(number.click)"
        else -> "on the dial"
    }

    /** Every setting the grind wheel offers, finest first, in the grinder's own notation. */
    val settings: List<String> get() {
        val ends = listOfNotNull(pourOver, aeroPress, frenchPress, moka, espresso, coldBrew)
            .flatMap { it.split("–") }.map { it.trim() }
        if (notation == "rotation.number.tick") {
            val turns = ends.mapNotNull { it.split(".").first().toIntOrNull() }.maxOrNull() ?: 0
            return (0..turns).flatMap { r -> (0..9).flatMap { n -> (0..9).map { "$r.$n.$it" } } }
        }
        // Baratza Vario: macro 1–10, micro A–W.
        if (ends.any { it.lastOrNull()?.isLetter() == true }) {
            return (1..10).flatMap { n -> "ABCDEFGHIJKLMNOPQRSTUVW".map { "$n$it" } }
        }
        // Eureka: the first turn reads 0–5.9 on the dial, later turns "turns+dial".
        if (ends.any { it.contains('+') }) {
            val turns = ends.mapNotNull { it.split("+").first().toIntOrNull() }.maxOrNull() ?: 0
            val dial = (0 until 60).map { number(it / 10.0, 1) }
            return dial + (1..maxOf(turns, 1)).flatMap { t -> dial.map { "$t+$it" } }
        }
        val decimals = ends.maxOfOrNull { it.split(".").drop(1).firstOrNull()?.length ?: 0 } ?: 0
        val coarsest = ends.mapNotNull { it.toDoubleOrNull() }.maxOrNull() ?: 40.0
        return steps(coarsest, decimals)
    }

    companion object {
        /** The wheel stop for a typed or saved setting: "9.0" finds "9", "1" finds "1.0.0". */
        fun setting(text: String, settings: List<String>): String? {
            val t = text.trim()
            return settings.firstOrNull { it == t || it == "$t.0.0" }
                ?: t.toDoubleOrNull()?.let { v -> settings.firstOrNull { it.toDoubleOrNull() == v } }
        }

        /** The wheel for a grinder the guide does not know: 0–40 by halves. */
        val otherSettings: List<String> by lazy { steps(40.0, 1, 0.5) }

        private fun steps(max: Double, decimals: Int, step: Double? = null): List<String> {
            val s = step ?: 10.0.pow(-decimals.toDouble())
            val count = (max / s).roundHalfAway().toInt()
            return (0..count).map { number(it * s, decimals) }
        }

        /** "9", "3.7", "0.33": no trailing zeros, always a dot whatever the locale. */
        private fun number(value: Double, decimals: Int): String {
            var text = fmt("%.${decimals}f", value)
            if (text.contains('.')) text = text.trimEnd('0').trimEnd('.')
            return text
        }

        /** The guide entry for a grinder the user named, ignoring case and spacing. */
        fun find(name: String?): GrinderGuide? {
            if (name == null) return null
            val key = name.lowercase().filter { it.isLetterOrDigit() }
            return all.firstOrNull { g -> g.name.lowercase().filter { it.isLetterOrDigit() } == key }
        }

        /** The guide's method for one of the app's brew method names, or null when none fits. */
        fun method(forMethodNamed: String?): Method? {
            val n = forMethodNamed?.lowercase() ?: return null
            return when {
                n.contains("espresso") -> Method.ESPRESSO
                n.contains("cold brew") -> Method.COLD_BREW
                n.contains("moka") -> Method.MOKA
                n.contains("inverted press") || n.contains("aeropress") -> Method.AERO_PRESS
                n.contains("press") -> Method.FRENCH_PRESS
                n.contains("drip") || n.contains("pour") || n.contains("chemex") -> Method.POUR_OVER
                else -> null
            }
        }

        val all: List<GrinderGuide> = listOf(
        GrinderGuide(name = "Baratza Encore", kind = "Electric", notation = "dial", pourOver = "7 – 18", aeroPress = "3 – 29", frenchPress = "19 – 40", moka = "5 – 17", espresso = null, coldBrew = "24 – 40", source = "https://honestcoffeeguide.com/baratza-encore-grind-settings/"),
        GrinderGuide(name = "Fellow Ode Gen 2", kind = "Electric", notation = "dial", pourOver = "2.2 – 5.2", aeroPress = "1.2 – 8.2", frenchPress = "6 – 11", moka = "2 – 5.1", espresso = null, coldBrew = "7 – 11", source = "https://honestcoffeeguide.com/fellow-ode-brew-grinder-gen-2-grind-settings/"),
        GrinderGuide(name = "Timemore Sculptor 078", kind = "Electric", notation = "dial", pourOver = "1 – 6.5", aeroPress = "0 – 11.5", frenchPress = "6.5 – 18", moka = "0 – 5.5", espresso = null, coldBrew = "9 – 18", source = "https://honestcoffeeguide.com/timemore-sculptor-078-grind-settings/"),
        GrinderGuide(name = "Turin DF64 Gen 2", kind = "Electric", notation = "dial", pourOver = "23 – 53", aeroPress = "15 – 80", frenchPress = "53 – 90", moka = "19 – 49", espresso = "0 – 20", coldBrew = "65 – 90", source = "https://honestcoffeeguide.com/turin-df64-gen-2-grind-settings/"),
        GrinderGuide(name = "Option-O Lagom Casa 65CL", kind = "Electric", notation = "rotation.number.tick", pourOver = "0.8.5 – 1.4.7", aeroPress = "0.6.8 – 2.0.2", frenchPress = "1.4.6 – 2.7.3", moka = "0.7.6 – 1.3.9", espresso = "0.3.8 – 0.8.0", coldBrew = "1.6.9 – 2.9.5", source = "https://honestcoffeeguide.com/option-o-lagom-casa-grind-settings/"),
        GrinderGuide(name = "Niche Zero", kind = "Electric", notation = "rotations", pourOver = "0.33 – 0.56", aeroPress = "0.26 – 0.77", frenchPress = "0.56 – 1.14", moka = "0.30 – 0.53", espresso = "0.15 – 0.30", coldBrew = "0.65 – 1.23", source = "https://honestcoffeeguide.com/niche-zero-grind-settings/"),
        GrinderGuide(name = "Baratza Vario W+", kind = "Electric", notation = "dial", pourOver = "2T – 6B", aeroPress = "2A – 8T", frenchPress = "6A – 10V", moka = "2J – 5O", espresso = "1A – 2N", coldBrew = "7E – 10V", source = "https://honestcoffeeguide.com/baratza-vario-w-plus-grind-settings/"),
        GrinderGuide(name = "Turin DF54", kind = "Electric", notation = "dial", pourOver = "34 – 67", aeroPress = "24 – 90", frenchPress = "67 – 90", moka = "29 – 62", espresso = "8 – 30", coldBrew = "79 – 90", source = "https://honestcoffeeguide.com/turin-df54-grind-settings/"),
        GrinderGuide(name = "Baratza Virtuoso+", kind = "Electric", notation = "dial", pourOver = "8 – 20", aeroPress = "5 – 30", frenchPress = "20 – 40", moka = "7 – 18", espresso = null, coldBrew = "24 – 40", source = "https://honestcoffeeguide.com/baratza-virtuoso-plus-grind-settings/"),
        GrinderGuide(name = "Baratza Encore ESP", kind = "Electric", notation = "dial", pourOver = "15 – 25", aeroPress = "8 – 30", frenchPress = "25 – 38", moka = "12 – 24", espresso = "0 – 13", coldBrew = "27 – 40", source = "https://honestcoffeeguide.com/baratza-encore-esp-grind-settings/"),
        GrinderGuide(name = "Eureka Mignon Specialità", kind = "Electric", notation = "rotations", pourOver = "4.5 – 1+4", aeroPress = "2.5 – 2+3", frenchPress = "1+4 – 3+4", moka = "3.5 – 1+3", espresso = "0 – 3.5", coldBrew = "2+0.5 – 4+0", source = "https://honestcoffeeguide.com/eureka-mignon-specialita-grind-settings/"),
        GrinderGuide(name = "1Zpresso K-Ultra", kind = "Hand", notation = "rotation.number.tick", pourOver = "0.5.3 – 0.9.2", aeroPress = "0.4.3 – 1", frenchPress = "0.9.1 – 1", moka = "0.4.8 – 0.8.6", espresso = "0.2.4 – 0.5", coldBrew = "1", source = "https://honestcoffeeguide.com/1zpresso-k-ultra-grind-settings/"),
        GrinderGuide(name = "1Zpresso ZP6 Special", kind = "Hand", notation = "number.click", pourOver = "1.8 – 5.1", aeroPress = "0.9 – 8.0", frenchPress = "5.0 – 9.0", moka = "1.4 – 4.6", espresso = "0.0 – 1.5", coldBrew = "6.3 – 9.0", source = "https://honestcoffeeguide.com/1zpresso-zp6-special-grind-settings/"),
        GrinderGuide(name = "KINGrinder K6", kind = "Hand", notation = "rotations", pourOver = "0.48 – 1.22", aeroPress = "0.38 – 1.53", frenchPress = "1.22 – 2.34", moka = "0.43 – 1.18", espresso = "0.22 – 0.45", coldBrew = "1.35 – 2.40", source = "https://honestcoffeeguide.com/kingrinder-k6-grind-settings/"),
        GrinderGuide(name = "Comandante C40 MK4", kind = "Hand", notation = "clicks", pourOver = "15 – 25", aeroPress = "12 – 35", frenchPress = "26 – 40", moka = "14 – 24", espresso = "7 – 13", coldBrew = "30 – 40", source = "https://honestcoffeeguide.com/comandante-c40-mk4-grind-settings/"),
        GrinderGuide(name = "Pietro Pro Brewing", kind = "Hand", notation = "dial", pourOver = "3.1 – 7.0", aeroPress = "2.0 – 10.0", frenchPress = "7.0 – 10.0", moka = "2.6 – 6.5", espresso = null, coldBrew = "8.4 – 10.0", source = "https://honestcoffeeguide.com/fiorenzato-pietro-b-modal-burrs-grind-settings/"),
        GrinderGuide(name = "1Zpresso J-Ultra", kind = "Hand", notation = "rotation.number.tick", pourOver = "1.6.3 – 2.8.4", aeroPress = "1.3.1 – 3.9.0", frenchPress = "2.8.1 – 5.0.0", moka = "1.4.7 – 2.6.8", espresso = "0.7.4 – 1.5.4", coldBrew = "3.2.6 – 5.0.0", source = "https://honestcoffeeguide.com/1zpresso-j-ultra-grind-settings/"),
        GrinderGuide(name = "Kinu M47 Phoenix", kind = "Hand", notation = "rotations", pourOver = "2.5 – 4.2", aeroPress = "2 – 5.8", frenchPress = "4.2 – 7.8", moka = "2.2 – 4", espresso = "1.1 – 2.3", coldBrew = "4.9 – 8.5", source = "https://honestcoffeeguide.com/kinu-m47-phoenix-grind-settings/"),
        GrinderGuide(name = "Timemore Chestnut S3", kind = "Hand", notation = "clicks", pourOver = "0.9 – 4.2", aeroPress = "0 – 7.2", frenchPress = "4.2 – 9.0", moka = "0.4 – 3.8", espresso = null, coldBrew = "5.5 – 9.0", source = "https://honestcoffeeguide.com/timemore-s3-grind-settings/"),
        GrinderGuide(name = "1Zpresso J", kind = "Hand", notation = "rotation.number.tick", pourOver = "1.5.0 – 2.5.2", aeroPress = "1.2.0 – 3.5.1", frenchPress = "2.5.2 – 4.0.0", moka = "1.3.1 – 2.4.1", espresso = "0.6.2 – 1.4.0", coldBrew = "2.9.2 – 4.0.0", source = "https://honestcoffeeguide.com/1zpresso-j-grind-settings/"),
        GrinderGuide(name = "1Zpresso Q Air", kind = "Hand", notation = "rotation.number.tick", pourOver = "1.2.0 – 2.0.1", aeroPress = "0.9.2 – 2.8.0", frenchPress = "2.0.1 – 3.8.0", moka = "1.0.2 – 1.9.1", espresso = "0.5.1 – 1.1.0", coldBrew = "2.3.2 – 4.0.0", source = "https://honestcoffeeguide.com/1zpresso-q-air-grind-settings/"),
        )
    }
}
