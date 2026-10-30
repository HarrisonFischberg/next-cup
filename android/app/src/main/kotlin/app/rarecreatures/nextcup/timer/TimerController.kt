package app.rarecreatures.nextcup.timer

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.kit.SystemTimerClock
import app.rarecreatures.nextcup.kit.TimerEngine
import app.rarecreatures.nextcup.kit.TimerPhase
import app.rarecreatures.nextcup.kit.TimerSnapshot
import app.rarecreatures.nextcup.kit.TimerState
import app.rarecreatures.nextcup.kit.TimerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlin.math.floor

/** Keeps the running timer's snapshot in preferences as JSON; unreadable data is discarded. */
class PrefsTimerStateStore(private val prefs: SharedPreferences, private val key: String = "nextcup.timer.snapshot") : TimerStateStore {
    override fun save(snapshot: TimerSnapshot) = prefs.edit().putString(key, TimerStateStore.encode(snapshot)).apply()
    override fun load(): TimerSnapshot? {
        val text = prefs.getString(key, null) ?: return null
        return TimerStateStore.decode(text) ?: null.also { clear() }
    }
    override fun clear() = prefs.edit().remove(key).apply()
}

/** How a run ended: the elapsed time reached and whether it was cut short. */
data class TimerOutcome(val run: TimerRun, val elapsedS: Double, val endedEarly: Boolean, val setup: TimerSetup)

/**
 * The one running timer for the whole app, as iOS's TimerSession. All time comes from the engine's persisted
 * dates, so the screen, the notification and a restart after process death all agree.
 */
class TimerController(private val context: Context, private val db: NextCupDatabase, private val prefs: SharedPreferences, private val scope: CoroutineScope) {
    private val store = PrefsTimerStateStore(prefs)
    private val json = Json { ignoreUnknownKeys = true }
    private var engine: TimerEngine? = null
    private var ticker: Job? = null
    private var lastIndex: Int? = null

    private val _setup = MutableStateFlow<TimerSetup?>(null)
    val setup: StateFlow<TimerSetup?> = _setup
    private val _state = MutableStateFlow<TimerState?>(null)
    val state: StateFlow<TimerState?> = _state
    private val _outcome = MutableStateFlow<TimerOutcome?>(null)
    /** Set when a run finishes; the screen opens the brew form from it, then calls [consumeOutcome]. */
    val outcome: StateFlow<TimerOutcome?> = _outcome

    val isActive: Boolean get() = _state.value?.phase.let { it == TimerPhase.Running || it == TimerPhase.Paused }

    /** Prepares a run without starting it. A saved run for the same plan picks up where it was. */
    suspend fun prepare(run: TimerRun): TimerSetup? {
        val recipe = db.recipes().find(run.recipeId) ?: return null
        val setup = TimerSetup.build(run, recipe, db.recipes().steps(recipe.id), recipe.methodId?.let { db.methods().find(it) })
        val restored = TimerEngine.restore(SystemTimerClock, store)
        engine = if (restored != null && restored.plan == setup.plan) restored else TimerEngine(setup.plan, SystemTimerClock, store)
        _setup.value = setup
        _outcome.value = null
        prefs.edit().putString(RUN_KEY, json.encodeToString(TimerRun.serializer(), run)).apply()
        refresh(cues = false)
        if (isActive) startTicking()
        return setup
    }

    /** At launch: a run that was going when the process died comes back, with its notification. */
    suspend fun restoreIfRunning(): Boolean {
        val text = prefs.getString(RUN_KEY, null) ?: return false
        if (store.load() == null) return false
        val run = runCatching { json.decodeFromString(TimerRun.serializer(), text) }.getOrNull() ?: return false
        prepare(run) ?: return false
        return isActive
    }

    fun start() {
        val e = engine ?: return
        if (e.state().phase != TimerPhase.NotStarted) return
        e.start()
        cue(Cue.START)
        refresh(cues = false)
        startTicking()
        TimerService.start(context)
    }

    fun resumeService() { if (isActive) TimerService.start(context) }

    fun pause() { engine?.takeIf { it.state().phase == TimerPhase.Running }?.let { it.pause(); cue(Cue.TOGGLE); refresh(false) } }
    fun resume() { engine?.takeIf { it.state().phase == TimerPhase.Paused }?.let { it.resume(); cue(Cue.TOGGLE); refresh(false) } }
    fun skipToNextStep() { engine?.skipToNextStep(); refresh(true) }
    fun endEarly() { engine?.endEarly(); refresh(true) }
    fun finish() { engine?.finish(); refresh(true) }

    /** Drops a prepared or running brew without logging it. */
    fun cancel() {
        engine?.discard()
        clearRun()
    }

    fun consumeOutcome() { _outcome.value = null }

    private fun startTicking() {
        if (ticker?.isActive == true) return
        ticker = scope.launch {
            while (isActive) {
                refresh(cues = true)
                val s = _state.value ?: break
                if (s.phase is TimerPhase.Finished) break
                // Land just past each whole second so a second shows the moment it begins.
                delay(if (s.phase == TimerPhase.Running) ((floor(s.elapsedS) + 1 - s.elapsedS + 0.005).coerceAtMost(0.25) * 1000).toLong() else 250)
            }
        }
    }

    private fun refresh(cues: Boolean) {
        val e = engine ?: return
        val latest = e.state()
        val previous = _state.value
        if (latest.phase is TimerPhase.Finished) {
            complete(latest)
            return
        }
        if (cues && previous != null && previous.phase != TimerPhase.NotStarted) {
            if (latest.currentIndex != null && latest.currentIndex != lastIndex && lastIndex != null) cue(Cue.STEP)
            else if (latest.targetReached && !previous.targetReached) cue(Cue.STEP)
        }
        lastIndex = latest.currentIndex
        val moved = previous == null || latest.phase != previous.phase || latest.currentIndex != previous.currentIndex || latest.targetReached != previous.targetReached
        if (moved || latest.elapsedS.toInt() != previous?.elapsedS?.toInt()) _state.value = latest
        if (moved) TimerService.update(context)
    }

    private fun complete(finished: TimerState) {
        val setup = _setup.value ?: return
        val early = (finished.phase as? TimerPhase.Finished)?.endedEarly ?: false
        _state.value = finished
        _outcome.value = TimerOutcome(setup.run, finished.elapsedS, early, setup)
        cue(Cue.FINISH)
        engine?.discard()
        clearRun()
    }

    private fun clearRun() {
        ticker?.cancel()
        prefs.edit().remove(RUN_KEY).apply()
        TimerService.stop(context)
    }

    private enum class Cue { START, TOGGLE, STEP, FINISH }

    /** Haptics only for events that matter; a step change also chimes when the brew's sound is on. */
    private fun cue(cue: Cue) {
        val vibrator = if (android.os.Build.VERSION.SDK_INT >= 31) {
            ContextCompat.getSystemService(context, VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION") ContextCompat.getSystemService(context, Vibrator::class.java)
        }
        val ms = when (cue) {
            Cue.START, Cue.TOGGLE -> 20L
            Cue.STEP -> 60L
            Cue.FINISH -> 140L
        }
        runCatching { vibrator?.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE)) }
        if (prefs.getBoolean("nextcup.timer.sound", true) && (cue == Cue.STEP || cue == Cue.FINISH)) {
            runCatching {
                val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 70)
                tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 220)
                scope.launch { delay(400); tone.release() }
            }
        }
    }

    companion object {
        private const val RUN_KEY = "nextcup.timer.run"
    }
}
