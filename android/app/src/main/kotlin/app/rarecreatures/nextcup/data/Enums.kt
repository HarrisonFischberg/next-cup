package app.rarecreatures.nextcup.data

/**
 * Stored enums. Raw values are persisted and exported with the same strings as iOS (Enums.swift), so an
 * export from either app imports into the other. Renaming a raw value is a schema migration.
 */
interface RawEnum { val raw: String }

inline fun <reified E> rawOf(raw: String?): E? where E : Enum<E>, E : RawEnum = enumValues<E>().firstOrNull { it.raw == raw }

enum class Verdict(override val raw: String, val label: String) : RawEnum {
    SOUR("sour", "Sour"), BITTER("bitter", "Bitter"), WEAK("weak", "Weak"), BRIGHT("bright", "Bright"),
    STRONG("strong", "Strong"), BALANCED("balanced", "Balanced");

    companion object {
        /** The draft keeps several tastes in one field, comma-separated ("sour,weak"). */
        fun picked(raw: String?): List<Verdict> = (raw ?: "").split(",").mapNotNull { rawOf<Verdict>(it) }
        fun joined(verdicts: List<Verdict>): String? = if (verdicts.isEmpty()) null else verdicts.joinToString(",") { it.raw }

        /** Picking or unpicking one taste. Balanced stands alone: it clears the faults, and a fault clears it. */
        fun toggled(option: Verdict, raw: String?): String? {
            val tastes = picked(raw).toMutableList()
            if (!tastes.remove(option)) {
                tastes.removeAll { option == BALANCED || it == BALANCED }
                tastes += option
            }
            return joined(tastes)
        }
    }
}

enum class RoastLevel(override val raw: String, val label: String) : RawEnum {
    ULTRA_LIGHT("ultraLight", "Ultra-light"), LIGHT("light", "Light"), MEDIUM_LIGHT("mediumLight", "Medium-light"),
    MEDIUM("medium", "Medium"), MEDIUM_DARK("mediumDark", "Medium-dark"), DARK("dark", "Dark"),
}

enum class BeanStatus(override val raw: String, val label: String) : RawEnum {
    IN_USE("inUse", "In use"), BUY_AGAIN("buyAgain", "Buy again"), WISHLIST("wishlist", "Wishlist"), FINISHED("finished", "Finished"),
}

enum class BrewStyle(override val raw: String, val label: String) : RawEnum {
    POUR_OVER("pourOver", "Pour over"), IMMERSION("immersion", "Immersion"), ESPRESSO("espresso", "Espresso"), COLD("cold", "Cold"),
}

enum class BrewParameter(override val raw: String) : RawEnum {
    DOSE("dose"), WATER("water"), YIELD("yield"), GRIND("grind"), TEMPERATURE("temperature"), TIME("time"),
    TDS("tds"), RATING("rating"), NOTES("notes"), PHOTO("photo"),
}

enum class StepKind(override val raw: String, val label: String) : RawEnum {
    BLOOM("bloom", "Bloom"), POUR("pour", "Pour"), WAIT("wait", "Wait"), STIR("stir", "Stir"), SWIRL("swirl", "Swirl"),
    INVERT("invert", "Invert"), PRESS("press", "Press"), PLUG("plug", "Plug"), BYPASS("bypass", "Bypass"),
    OPEN_VALVE("openValve", "Open valve"), CLOSE_VALVE("closeValve", "Close valve"), DRAWDOWN("drawdown", "Drawdown"),
    HEAT("heat", "Heat"), OFF_HEAT("offHeat", "Off the heat"), BREW("brew", "Brew"),
}

enum class SuggestionSource(override val raw: String) : RawEnum { RULES("rules"), AI("ai") }

enum class SuggestionState(override val raw: String) : RawEnum {
    PROPOSED("proposed"), ACCEPTED("accepted"), EDITED("edited"), DISMISSED("dismissed"),
}

enum class AIFeature(override val raw: String) : RawEnum {
    DIAGNOSIS("diagnosis"), PHOTO_INTERPRETATION("photoInterpretation"), BAG_RECOGNITION("bagRecognition"),
    INSIGHTS("insights"), PAPER_IMPORT("paperImport"),
}

/** `apple` is iOS's on-device model; Android's on-device model (Gemini Nano) is stored as `onDevice`. */
enum class AIProvider(override val raw: String) : RawEnum { ANTHROPIC("anthropic"), OPENAI("openAI"), APPLE("apple"), ON_DEVICE("onDevice") }

enum class AIRequestStatus(override val raw: String) : RawEnum {
    QUEUED("queued"), SENDING("sending"), DONE("done"), FAILED("failed"), CANCELLED("cancelled"),
}

enum class TaxonomyDimension(override val raw: String) : RawEnum {
    ORIGIN("origin"), PROCESS("process"), ROAST("roast"), FLAVOR("flavor"), BREWER("brewer"),
}
