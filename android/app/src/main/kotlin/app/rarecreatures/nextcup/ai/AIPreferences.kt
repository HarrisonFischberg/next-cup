package app.rarecreatures.nextcup.ai

import android.content.SharedPreferences
import app.rarecreatures.nextcup.data.AIFeature
import app.rarecreatures.nextcup.data.AIProvider
import app.rarecreatures.nextcup.data.rawOf

/** Non-secret AI preferences: the disclosure accepted per provider and the provider and model per feature. Never a key. */
class AIPreferences(private val prefs: SharedPreferences, private val onDeviceAvailable: () -> Boolean) {
    companion object {
        /** Bump when the disclosure text changes so it is shown again. */
        const val DISCLOSURE_VERSION = 2
        const val EFFORT_KEY = "ai.effort"
        fun disclosureKey(p: AIProvider) = "ai.disclosure.${p.raw}.version"
        fun providerKey(f: AIFeature) = "ai.provider.${f.raw}"
        fun modelKey(f: AIFeature) = "ai.model.${f.raw}"
        val keyed = listOf(AIProvider.ANTHROPIC, AIProvider.OPENAI)
    }

    /** "low", "medium" or "high"; null leaves the provider's default. */
    var effort: String?
        get() = prefs.getString(EFFORT_KEY, null)?.ifEmpty { null }
        set(value) = prefs.edit().putString(EFFORT_KEY, value).apply()

    /** Nothing leaves the phone with the on-device model, so there is nothing to disclose. */
    fun hasAcceptedDisclosure(p: AIProvider) = p == AIProvider.ON_DEVICE || prefs.getInt(disclosureKey(p), 0) >= DISCLOSURE_VERSION
    fun acceptDisclosure(p: AIProvider) = prefs.edit().putInt(disclosureKey(p), DISCLOSURE_VERSION).apply()

    /** The user's pick, else the on-device model where this phone has one; a cloud model is never guessed. */
    fun provider(f: AIFeature): AIProvider? =
        rawOf<AIProvider>(prefs.getString(providerKey(f), null))?.takeIf { it != AIProvider.APPLE } ?: if (onDeviceAvailable()) AIProvider.ON_DEVICE else null

    fun modelID(f: AIFeature): String? = prefs.getString(modelKey(f), null)?.ifEmpty { null } ?: if (provider(f) == AIProvider.ON_DEVICE) OnDeviceAI.MODEL_ID else null

    fun setChoice(p: AIProvider, model: String, f: AIFeature) =
        prefs.edit().putString(providerKey(f), p.raw).putString(modelKey(f), model.trim()).apply()

    fun clearChoice(f: AIFeature) = prefs.edit().remove(providerKey(f)).remove(modelKey(f)).apply()
}

val AIProvider.title: String get() = when (this) {
    AIProvider.ANTHROPIC -> "Anthropic"
    AIProvider.OPENAI -> "OpenAI"
    AIProvider.APPLE -> "Apple"
    AIProvider.ON_DEVICE -> "On this phone (Gemini Nano)"
}

val AIFeature.title: String get() = when (this) {
    AIFeature.DIAGNOSIS -> "Brew diagnosis"
    AIFeature.PHOTO_INTERPRETATION -> "Photo interpretation"
    AIFeature.BAG_RECOGNITION -> "Bag recognition"
    AIFeature.INSIGHTS -> "Insights"
    AIFeature.PAPER_IMPORT -> "Paper import"
}

/** Exactly what one request of this feature sends, shown in the disclosure. */
val AIFeature.sends: String get() = when (this) {
    AIFeature.DIAGNOSIS -> "The one brew you ask about: its date, method, bean origin, process and roast, dose, water, grind, temperature, time, taste, rating and your notes."
    AIFeature.INSIGHTS -> "Up to the 8 most recent brews of one coffee, each with its date, method, bean origin, process and roast, dose, water, grind, temperature, time, taste, rating and your notes."
    AIFeature.BAG_RECOGNITION -> "One photo of a coffee bag, with location and camera data removed, and a fixed instruction."
    AIFeature.PHOTO_INTERPRETATION -> "One photo of a coffee, with location and camera data removed, and a fixed instruction."
    AIFeature.PAPER_IMPORT -> "One photo of a handwritten journal page, in full, with location and camera data removed. Everything written on the page is sent."
}
