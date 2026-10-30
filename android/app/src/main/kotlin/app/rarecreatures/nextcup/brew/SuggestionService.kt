package app.rarecreatures.nextcup.brew

import app.rarecreatures.nextcup.MethodParameters
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.BrewParameter
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.data.Suggestion
import app.rarecreatures.nextcup.data.SuggestionSource
import app.rarecreatures.nextcup.data.SuggestionState
import app.rarecreatures.nextcup.data.Verdict
import app.rarecreatures.nextcup.data.now
import app.rarecreatures.nextcup.data.rawOf
import app.rarecreatures.nextcup.kit.BrewDraft
import app.rarecreatures.nextcup.kit.DialInInput
import app.rarecreatures.nextcup.kit.DialInOutcome
import app.rarecreatures.nextcup.kit.DialInParameter
import app.rarecreatures.nextcup.kit.DialInRules
import app.rarecreatures.nextcup.kit.DialInStyle
import app.rarecreatures.nextcup.kit.DialInVerdict
import androidx.room.withTransaction
import kotlin.math.roundToInt

/** Stores the dial-in suggestions the rules make from a saved brew and finds the one for the next brew of the same beans. */
class SuggestionService(private val db: NextCupDatabase) {
    /**
     * Makes the rules suggestion for a saved brew, replacing one that was never answered. A brew whose suggestion
     * was answered keeps it. A balanced cup, or one with nothing to change, stores nothing and says why.
     */
    suspend fun propose(brew: Brew): DialInOutcome = db.withTransaction {
        val made = db.suggestions().all().filter { it.sourceBrewId == brew.id && it.source == SuggestionSource.RULES }
        if (made.any { it.state != SuggestionState.PROPOSED }) return@withTransaction DialInOutcome.Keep("This brew already has a suggestion you answered.")
        made.forEach { db.suggestions().delete(it) }

        // Bright is a good note, so a fault picked with it decides the change.
        val tasted = brew.verdicts.firstOrNull { it != Verdict.BRIGHT } ?: brew.verdict
        val verdict = DialInVerdict.of(tasted?.raw) ?: return@withTransaction DialInOutcome.Keep("Choose how it tasted to get a suggestion.")
        val method = brew.methodId?.let { db.methods().find(it) }
        val tracked = MethodParameters.shown(method?.trackedParameters).mapNotNull { DialInParameter.of(it.raw) }.toSet()
        val outcome = DialInRules.suggest(
            DialInInput(verdict, DialInStyle.of(method?.style?.raw) ?: DialInStyle.POUR_OVER, tracked, brew.grindSetting, brew.waterG, brew.tempC, brew.totalTimeS),
        )
        val change = (outcome as? DialInOutcome.Change)?.draft ?: return@withTransaction outcome
        val fresh = Suggestion(
            source = SuggestionSource.RULES, field = rawOf<BrewParameter>(change.parameter.raw) ?: BrewParameter.GRIND,
            fromValue = change.fromValue, toValue = change.toValue, rationale = change.rationale, sourceBrewId = brew.id,
        )
        db.suggestions().upsert(fresh)
        supersedeOlder(brew, fresh)
        outcome
    }

    /** A newer brew of the same beans makes an unanswered suggestion from an older one stale. */
    private suspend fun supersedeOlder(brew: Brew, fresh: Suggestion) {
        val beans = beanIds(brew.id)
        for (other in db.suggestions().all()) {
            if (other.id == fresh.id || other.state != SuggestionState.PROPOSED) continue
            val source = other.sourceBrewId?.let { db.brews().find(it) } ?: continue
            if (source.id == brew.id || source.date > brew.date) continue
            val sourceBeans = beanIds(source.id)
            val same = if (beans.isEmpty() && sourceBeans.isEmpty()) source.methodId == brew.methodId else beans.intersect(sourceBeans).isNotEmpty()
            if (same) db.suggestions().upsert(other.copy(state = SuggestionState.DISMISSED, updatedAt = now()))
        }
    }

    private suspend fun beanIds(brewId: String) = db.brews().beans(brewId).mapNotNull { it.beanId }.toSet()

    /** The newest unanswered suggestion for a brew about to be made with these beans (or, with none, this method). */
    suspend fun match(beanIds: Set<String>, methodId: String?, excludingBrewId: String): Suggestion? =
        db.suggestions().all().filter { it.state == SuggestionState.PROPOSED }.sortedByDescending { it.createdAt }.firstOrNull { s ->
            val source = s.sourceBrewId?.let { db.brews().find(it) } ?: return@firstOrNull false
            if (source.id == excludingBrewId) return@firstOrNull false
            val sourceBeans = beanIds(source.id)
            if (beanIds.isEmpty() && sourceBeans.isEmpty()) source.methodId == methodId else beanIds.isNotEmpty() && beanIds.intersect(sourceBeans).isNotEmpty()
        }
}

/** Reads and writes the brew-form value a suggestion is about, in canonical text. */
object SuggestionApplication {
    fun value(p: BrewParameter, d: BrewDraft): String = when (p) {
        BrewParameter.GRIND -> d.grindSetting
        BrewParameter.WATER, BrewParameter.YIELD -> d.waterG?.let(::number) ?: ""
        BrewParameter.TEMPERATURE -> d.tempC?.let(::number) ?: ""
        BrewParameter.TIME -> d.totalTimeS?.toString() ?: ""
        else -> ""
    }

    /** The draft with [text] applied, or null when the text is not a usable value for that field. */
    fun set(text: String, p: BrewParameter, d: BrewDraft): BrewDraft? {
        val clean = text.trim()
        return when (p) {
            BrewParameter.GRIND -> d.copy(grindSetting = clean)
            BrewParameter.WATER, BrewParameter.YIELD -> clean.toDoubleOrNull()?.takeIf { it > 0 }?.let { d.copy(waterG = it) }
            BrewParameter.TEMPERATURE -> clean.toDoubleOrNull()?.let { d.copy(tempC = it) }
            BrewParameter.TIME -> clean.toDoubleOrNull()?.takeIf { it >= 0 }?.let { d.copy(totalTimeS = it.roundToInt()) }
            else -> null
        }
    }

    fun number(v: Double) = if (v == v.roundToInt().toDouble()) v.roundToInt().toString() else String.format(java.util.Locale.ROOT, "%.1f", v)
}
