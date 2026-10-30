package app.rarecreatures.nextcup.brew

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.BrewBean
import app.rarecreatures.nextcup.data.Grinder
import app.rarecreatures.nextcup.data.Suggestion
import app.rarecreatures.nextcup.data.SuggestionState
import app.rarecreatures.nextcup.data.Verdict
import app.rarecreatures.nextcup.data.WaterProfile
import app.rarecreatures.nextcup.data.now
import app.rarecreatures.nextcup.kit.BlendShares
import app.rarecreatures.nextcup.kit.BrewDraft
import app.rarecreatures.nextcup.kit.BrewMath
import app.rarecreatures.nextcup.kit.BrewTargets
import app.rarecreatures.nextcup.kit.DialInOutcome
import app.rarecreatures.nextcup.kit.DraftBean
import app.rarecreatures.nextcup.kit.DraftLoad
import app.rarecreatures.nextcup.kit.DraftStore
import app.rarecreatures.nextcup.kit.UnitPreferences
import app.rarecreatures.nextcup.kit.WeightUnit
import app.rarecreatures.nextcup.timer.TimerOutcome
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.UUID
import kotlin.math.roundToInt

/** How the form was opened. */
sealed interface FormSource {
    data object New : FormSource
    data class Editing(val brewId: String) : FormSource
    data class Repeating(val brewId: String) : FormSource
    /** An unsaved brew reopened from the Journal, by draft file name. */
    data class Resuming(val draftName: String) : FormSource
    /** The brew the timer just finished. */
    data class FromTimer(val outcome: TimerOutcome) : FormSource
}

data class NewBest(val bean: String, val tenths: Int, val previous: Int)

/**
 * State and rules for the brew form, as iOS's BrewFormModel. The draft autosaves outside the database; a brew
 * is written only on Save, and the draft is cleared only after that write is confirmed.
 */
class BrewFormViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application.app
    private val db = app.db
    private val json = Json { ignoreUnknownKeys = true }
    private var draftStore: DraftStore = DraftStore.newBrew()
    private var baseline = BrewDraft()
    private var autosave: Job? = null
    private var opened = false
    private var undoDraftValue: String? = null
    private var undoToValue: String? = null
    private var followedSuggestionId: String? = null

    val draft = MutableStateFlow(BrewDraft())
    val notice = MutableStateFlow<String?>(null)
    val saveError = MutableStateFlow<String?>(null)
    val isSaving = MutableStateFlow(false)
    val savedBrewId = MutableStateFlow<String?>(null)
    val editingId = MutableStateFlow<String?>(null)
    val waiting = MutableStateFlow<Suggestion?>(null)
    val handledSuggestion = MutableStateFlow<Suggestion?>(null)
    val suggestionError = MutableStateFlow<String?>(null)
    val madeSuggestion = MutableStateFlow<Suggestion?>(null)
    val dialInNote = MutableStateFlow<String?>(null)
    val newBest = MutableStateFlow<NewBest?>(null)
    val photoError = MutableStateFlow<String?>(null)

    val methods = db.methods().observeAll()
    val beans = db.beans().observeAll()
    val grinders = db.gear().observeGrinders()
    val waterProfiles = db.gear().observeWaterProfiles()
    val units: StateFlow<UnitPreferences> = app.prefs.units

    fun open(source: FormSource) {
        if (opened) return
        opened = true
        viewModelScope.launch {
            val fresh: BrewDraft
            when (source) {
                is FormSource.Editing -> {
                    editingId.value = source.brewId
                    fresh = db.brews().find(source.brewId)?.let { saved(it) } ?: BrewDraft()
                    draftStore = DraftStore.editing(UUID.fromString(source.brewId))
                }
                is FormSource.Repeating -> {
                    val src = db.brews().find(source.brewId)
                    fresh = if (src != null) BrewDraft.repeating(saved(src), UUID.fromString(src.id), draftBeans(src.id)) else BrewDraft()
                    draftStore = DraftStore.repeating(UUID.fromString(source.brewId))
                }
                is FormSource.Resuming -> {
                    val entry = DraftStore.all().firstOrNull { it.store.name == source.draftName }
                    draftStore = entry?.store ?: DraftStore.newBrew()
                    if (entry?.kind is app.rarecreatures.nextcup.kit.SavedDraft.Kind.Editing) editingId.value = entry.draft.id.toString().uppercase()
                    fresh = entry?.draft ?: BrewDraft()
                    if (entry == null) notice.value = "That unsaved brew was saved or discarded."
                }
                is FormSource.FromTimer -> {
                    val o = source.outcome
                    val recipe = db.recipes().find(o.run.recipeId)
                    fresh = BrewDraft(
                        sourceKey = o.run.sessionKey, methodID = recipe?.methodId?.let(UUID::fromString), recipeID = UUID.fromString(o.run.recipeId),
                        doseG = o.setup.scaled.doseG, waterG = o.setup.scaled.waterG, tempC = o.setup.tempC, totalTimeS = o.elapsedS.roundToInt(),
                        grindSetting = o.run.grindSetting,
                        targets = BrewTargets(o.setup.scaled.doseG, o.setup.scaled.waterG, o.setup.tempC, o.setup.plan.totalDurationS),
                        endedEarly = o.endedEarly,
                        beans = o.run.beanName?.let { listOf(DraftBean(o.run.beanId?.let(UUID::fromString), it, o.setup.scaled.doseG)) },
                        grinderID = o.run.grinderId?.let(UUID::fromString),
                    )
                    draftStore = DraftStore.named("brew-draft-${o.run.sessionKey}")
                    (draftStore.load() as? DraftLoad.Draft)?.let { draft.value = it.draft }
                }
                FormSource.New -> fresh = blank()
            }
            baseline = fresh
            if (source !is FormSource.FromTimer || draft.value.sourceKey == null) draft.value = fresh
            // A form opened from a timer run or a repeat is saved at once, so its values survive a crash.
            if (source is FormSource.FromTimer || source is FormSource.Repeating) flush(force = true)
            findWaiting()
        }
    }

    private suspend fun blank(): BrewDraft {
        val methods = db.methods().all().filter { !it.isHidden }
        val method = methods.firstOrNull { it.id == app.prefs.lastMethodId } ?: methods.minByOrNull { it.sortOrder }
        val grinder = app.prefs.lastGrinderId?.takeIf { id -> db.gear().grinders().any { it.id == id } }
        return BrewDraft(methodID = method?.id?.let(UUID::fromString), grinderID = grinder?.let(UUID::fromString))
    }

    private suspend fun draftBeans(brewId: String) = db.brews().beans(brewId).sortedBy { it.createdAt }.map {
        DraftBean(it.beanId?.let(UUID::fromString), it.beanId?.let { id -> db.beans().find(id)?.name } ?: it.beanNameSnapshot, it.grams)
    }

    private suspend fun saved(b: Brew) = BrewDraft(
        id = UUID.fromString(b.id), date = Instant.ofEpochMilli(b.date), methodID = b.methodId?.let(UUID::fromString),
        recipeID = b.recipeId?.let(UUID::fromString), doseG = b.doseG, waterG = b.waterG, tempC = b.tempC, totalTimeS = b.totalTimeS,
        grindSetting = b.grindSetting ?: "", verdict = Verdict.joined(b.verdicts), ratingTenths = b.ratingTenths ?: 0, notes = b.notes,
        photo = b.photo, targets = b.targetsJSON?.let { runCatching { json.decodeFromString(BrewTargets.serializer(), it) }.getOrNull() },
        beans = draftBeans(b.id), grinderID = b.grinderId?.let(UUID::fromString), tds = b.tds, waterProfileID = b.waterProfileId?.let(UUID::fromString),
    )

    private suspend fun findWaiting() {
        if (editingId.value != null) return
        val d = draft.value
        waiting.value = SuggestionService(db).match(
            d.beans.orEmpty().mapNotNull { it.beanID?.toString()?.uppercase() }.toSet(), d.methodID?.toString()?.uppercase(), d.id.toString().uppercase(),
        )
    }

    // Derived

    val ratioLabel: String? get() = BrewMath.ratioLabel(BrewMath.ratio(draft.value.doseG, draft.value.waterG))
    val extractionLabel: String? get() = BrewMath.extractionYield(draft.value.tds, draft.value.waterG, draft.value.doseG)?.let { String.format(java.util.Locale.getDefault(), "%.1f%%", it) }
    val beanShares: List<Double> get() = BlendShares.percentages(draft.value.beans.orEmpty().map { it.grams })

    // Editing

    fun update(change: (BrewDraft) -> BrewDraft) {
        if (savedBrewId.value != null) return
        draft.value = change(draft.value)
        autosave?.cancel()
        autosave = viewModelScope.launch { delay(400); flush() }
    }

    /** Moves a weight by one step in the user's unit, so a tap always changes what is shown. */
    fun stepWeight(current: Double?, direction: Int, gramStep: Double, ounceStep: Double, start: Double): Double {
        if (current == null) return start
        val u = units.value
        val step = if (u.weight == WeightUnit.GRAMS) gramStep else ounceStep
        val shown = u.displayWeight(current)
        return u.grams(maxOf(step, Math.round((shown + direction * step) / step) * step))
    }

    fun stepTemperature(current: Double?, direction: Int): Double {
        if (current == null) return DEFAULT_TEMP_C
        val u = units.value
        return u.celsius(Math.round(u.displayTemperature(current)).toDouble() + direction)
    }

    fun toggleVerdict(v: Verdict) = update { it.copy(verdict = Verdict.toggled(v, it.verdict)) }

    fun addBean(bean: Bean) = update { d ->
        val beans = d.beans.orEmpty()
        if (beans.any { it.beanID?.toString()?.uppercase() == bean.id }) return@update d
        val shares = BlendShares.appending(beans.map { it.grams })
        val next = (beans + DraftBean(UUID.fromString(bean.id), bean.name, 0.0)).mapIndexed { i, b -> b.copy(grams = shares[i]) }
        d.copy(beans = next)
    }.also { viewModelScope.launch { recallGrind(bean); findWaiting() } }

    /** The first bean chosen on a brew with no grind brings back the grinder and setting from its last brew. */
    private suspend fun recallGrind(bean: Bean) {
        if (draft.value.beans?.size != 1 || draft.value.grindSetting.isNotBlank()) return
        val uses = db.brews().allBrewBeans().filter { it.beanId == bean.id }.mapNotNull { it.brewId }.toSet()
        val last = db.brews().all().filter { it.id in uses && it.id != draft.value.id.toString().uppercase() && !it.grindSetting.isNullOrEmpty() }.maxByOrNull { it.date } ?: return
        update { it.copy(grindSetting = last.grindSetting!!, grinderID = last.grinderId?.let(UUID::fromString) ?: it.grinderID) }
    }

    fun removeBean(index: Int) = update { d ->
        val beans = d.beans ?: return@update d
        val shares = BlendShares.removing(index, beans.map { it.grams })
        d.copy(beans = beans.filterIndexed { i, _ -> i != index }.mapIndexed { i, b -> b.copy(grams = shares[i]) })
    }

    fun stepShare(index: Int, points: Double) = update { d ->
        val beans = d.beans ?: return@update d
        if (beans.size < 2) return@update d
        val current = BlendShares.percentages(beans.map { it.grams })
        val next = BlendShares.rebalanced(current, index, current[index] + points)
        d.copy(beans = beans.mapIndexed { i, b -> b.copy(grams = next[i]) })
    }

    /** Adds a grinder (or finds the one with this name) and chooses it. */
    fun addGrinder(name: String) = viewModelScope.launch {
        val clean = name.trim().takeIf { it.isNotEmpty() } ?: return@launch
        val match = db.gear().grinders().firstOrNull { it.name.equals(clean, ignoreCase = true) } ?: Grinder(name = clean).also { db.gear().upsertGrinder(it) }
        update { it.copy(grinderID = UUID.fromString(match.id)) }
    }

    /** Adds a water profile (or finds the one with this name) and chooses it. Hardness is optional but must be positive. */
    fun addWaterProfile(name: String, hardness: String): Boolean {
        val clean = name.trim()
        val typed = hardness.trim()
        val ppm = typed.toDoubleOrNull()
        if (clean.isEmpty() || (typed.isNotEmpty() && (ppm ?: 0.0) <= 0)) return false
        viewModelScope.launch {
            val match = db.gear().waterProfiles().firstOrNull { it.name.equals(clean, ignoreCase = true) }
                ?: WaterProfile(name = clean, ppmHardness = ppm).also { db.gear().upsertWaterProfile(it) }
            update { it.copy(waterProfileID = UUID.fromString(match.id)) }
        }
        return true
    }

    /** Re-encodes the picked photo without location or camera metadata before it is kept anywhere. */
    fun attachPhoto(bytes: ByteArray?) = viewModelScope.launch {
        photoError.value = null
        val cleaned = bytes?.let { PhotoSanitizer.sanitized(it) }
        if (cleaned == null) photoError.value = "That file could not be read as a photo. Nothing was attached."
        else update { it.copy(photo = cleaned) }
    }

    // Dial-in suggestion

    fun applySuggestion(s: Suggestion, edited: String? = null) = viewModelScope.launch {
        suggestionError.value = null
        val applied = edited ?: s.toValue
        val next = SuggestionApplication.set(applied, s.field, draft.value)
        if (applied.isBlank() || next == null) {
            suggestionError.value = "That value could not be used. Nothing was changed."
            return@launch
        }
        val previous = SuggestionApplication.value(s.field, draft.value)
        val answered = s.copy(toValue = applied, state = if (edited == null) SuggestionState.ACCEPTED else SuggestionState.EDITED, updatedAt = now())
        runCatching { db.suggestions().upsert(answered) }.onFailure { suggestionError.value = "The suggestion was not saved. ${it.message}"; return@launch }
        undoDraftValue = previous
        undoToValue = s.toValue
        followedSuggestionId = s.id
        handledSuggestion.value = answered
        update { next }
    }

    fun dismissSuggestion(s: Suggestion) = viewModelScope.launch {
        val answered = s.copy(state = SuggestionState.DISMISSED, updatedAt = now())
        runCatching { db.suggestions().upsert(answered) }.onFailure { suggestionError.value = "The suggestion was not saved. ${it.message}"; return@launch }
        undoDraftValue = null
        undoToValue = s.toValue
        handledSuggestion.value = answered
    }

    /** Takes the answer back: the draft value returns to what it was and the suggestion waits again. */
    fun undoSuggestion(s: Suggestion) = viewModelScope.launch {
        val wasApplied = s.state == SuggestionState.ACCEPTED || s.state == SuggestionState.EDITED
        runCatching { db.suggestions().upsert(s.copy(state = SuggestionState.PROPOSED, toValue = undoToValue ?: s.toValue, updatedAt = now())) }
            .onFailure { suggestionError.value = "The suggestion was not changed. ${it.message}"; return@launch }
        if (wasApplied) undoDraftValue?.let { v -> SuggestionApplication.set(v, s.field, draft.value)?.let { d -> update { d } } }
        undoDraftValue = null
        followedSuggestionId = null
        handledSuggestion.value = null
        findWaiting()
    }

    // Autosave

    /** Writes the draft now. An untouched form removes its draft, so opening and leaving never lists an unsaved brew. */
    fun flush(force: Boolean = false) {
        autosave?.cancel()
        if (savedBrewId.value != null) return
        if (!force && sameAsOpened()) {
            draftStore.clear()
            return
        }
        draftStore.save(draft.value).onSuccess { if (notice.value?.startsWith("This draft") == true) notice.value = null }
            .onFailure { notice.value = "This draft could not be autosaved. What you typed is still here." }
    }

    private fun sameAsOpened(): Boolean {
        val d = draft.value
        return if (editingId.value == null) d.copy(id = baseline.id, date = baseline.date) == baseline else d == baseline
    }

    /** Drops every change since the form opened. */
    fun discard() {
        draftStore.clear()
        draft.value = baseline
    }

    // Save

    val canSave: Boolean get() = draft.value.canSave && !isSaving.value && savedBrewId.value == null

    fun save() = viewModelScope.launch {
        if (!canSave) return@launch
        isSaving.value = true
        saveError.value = null
        autosave?.cancel()
        val d = draft.value
        val id = d.id.toString().uppercase()
        try {
            val existing = db.brews().find(id)
            val tastes = Verdict.picked(d.verdict)
            val brew = Brew(
                id = id, createdAt = existing?.createdAt ?: now(), updatedAt = now(), date = d.date.toEpochMilli(),
                doseG = d.doseG, waterG = d.waterG, tempC = d.tempC, totalTimeS = d.totalTimeS, tds = d.tds,
                grindSetting = d.grindSetting.trim().ifEmpty { null }, verdict = tastes.firstOrNull(),
                alsoTasted = if (tastes.size > 1) tastes.drop(1).map { it.raw } else null,
                ratingTenths = d.ratingTenths.takeIf { it != 0 }, notes = d.notes, photo = d.photo,
                targetsJSON = d.targets?.let { json.encodeToString(BrewTargets.serializer(), it) },
                methodId = d.methodID?.toString()?.uppercase(), recipeId = d.recipeID?.toString()?.uppercase()?.takeIf { db.recipes().find(it) != null },
                grinderId = d.grinderID?.toString()?.uppercase(), waterProfileId = d.waterProfileID?.toString()?.uppercase(),
                suggestionFollowedId = followedSuggestionId ?: existing?.suggestionFollowedId,
            )
            // Each bean takes its share of this brew's dose, so a blend deducts from every bag.
            val beans = d.beans?.let { list ->
                val grams = BlendShares.grams(d.doseG ?: 0.0, list.map { it.grams })
                list.mapIndexed { i, b ->
                    val beanId = b.beanID?.toString()?.uppercase()?.takeIf { db.beans().find(it) != null }
                    BrewBean(grams = grams[i], beanNameSnapshot = b.name, beanId = beanId)
                }
            }
            db.brews().save(brew, beans)
            d.methodID?.let { app.prefs.lastMethodId = it.toString().uppercase() }
            d.grinderID?.let { app.prefs.lastGrinderId = it.toString().uppercase() }
            savedBrewId.value = id
            when (val outcome = runCatching { SuggestionService(db).propose(brew) }.getOrNull()) {
                is DialInOutcome.Change -> madeSuggestion.value = db.suggestions().all().firstOrNull { it.sourceBrewId == id && it.state == SuggestionState.PROPOSED }
                is DialInOutcome.Keep -> dialInNote.value = outcome.message
                null -> dialInNote.value = "The brew is saved, but its dial-in suggestion could not be stored."
            }
            noteNewBest(brew)
            if (draftStore.clear().isFailure) notice.value = "Saved. An old draft file could not be removed."
        } catch (e: Exception) {
            saveError.value = "Not saved. ${e.message ?: ""} Your brew is kept as a draft. Try again."
            flush(force = true)
        } finally {
            isSaving.value = false
        }
    }

    /** A new best needs an earlier graded brew of the same bean to beat. */
    private suspend fun noteNewBest(brew: Brew) {
        val grade = brew.ratingTenths?.takeIf { it > 0 } ?: return
        val uses = db.brews().allBrewBeans()
        for (use in uses.filter { it.brewId == brew.id }) {
            val bean = use.beanId?.let { db.beans().find(it) } ?: continue
            val earlier = uses.filter { it.beanId == bean.id && it.brewId != brew.id }.mapNotNull { it.brewId?.let { b -> db.brews().find(b)?.ratingTenths } }.filter { it > 0 }
            val previous = earlier.maxOrNull() ?: continue
            if (grade > previous) { newBest.value = NewBest(bean.name, grade, previous); return }
        }
    }

    override fun onCleared() {
        flush()
        super.onCleared()
    }

    companion object {
        const val DEFAULT_DOSE_G = 15.0
        const val DEFAULT_WATER_G = 250.0
        const val DEFAULT_TEMP_C = 94.0
        const val DEFAULT_TIME_S = 180
        const val DEFAULT_TDS = 1.35
    }
}
