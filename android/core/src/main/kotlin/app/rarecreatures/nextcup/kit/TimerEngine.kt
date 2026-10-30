package app.rarecreatures.nextcup.kit

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Duration
import java.time.Instant

/** Source of wall-clock time. Injected so tests can drive the timer without waiting. */
fun interface TimerClock {
    fun now(): Instant
}

object SystemTimerClock : TimerClock {
    override fun now(): Instant = Instant.now()
}

/** One timeline step as the timer sees it. A step runs from its own offset to the next step's offset. */
@Serializable
data class TimerStep(
    val order: Int,
    val label: String,
    val instruction: String = "",
    val startOffsetS: Int,
    val targetCumulativeWaterG: Double? = null,
)

class TimerPlanError(val kind: Kind) : Exception(kind.name) {
    enum class Kind { NO_STEPS, NEGATIVE_OFFSET, TOTAL_NOT_AFTER_LAST_STEP }
}

/** The steps of a recipe plus the moment the brew ends. Build with [TimerPlan.of], which validates. */
@Serializable
data class TimerPlan internal constructor(val steps: List<TimerStep>, val totalDurationS: Int) {
    companion object {
        fun of(steps: List<TimerStep>, totalDurationS: Int): TimerPlan {
            if (steps.isEmpty()) throw TimerPlanError(TimerPlanError.Kind.NO_STEPS)
            val ordered = steps.sortedWith(compareBy<TimerStep> { it.startOffsetS }.thenBy { it.order })
            if (ordered.first().startOffsetS < 0) throw TimerPlanError(TimerPlanError.Kind.NEGATIVE_OFFSET)
            if (totalDurationS <= ordered.last().startOffsetS) throw TimerPlanError(TimerPlanError.Kind.TOTAL_NOT_AFTER_LAST_STEP)
            return TimerPlan(ordered, totalDurationS)
        }
    }

    /** Step indices grouped by start time, so steps that begin together show as one displayed step. */
    val displayGroups: List<List<Int>>
        get() {
            val groups = mutableListOf<MutableList<Int>>()
            steps.forEachIndexed { index, step ->
                val last = groups.lastOrNull()?.lastOrNull()
                if (last != null && steps[last].startOffsetS == step.startOffsetS) groups.last() += index
                else groups += mutableListOf(index)
            }
            return groups
        }

    /** The displayed group holding step [index]. */
    fun groupIndex(ofStep: Int): Int? = displayGroups.indexOfFirst { ofStep in it }.takeIf { it >= 0 }
}

/** A pause interval; `end == null` while still paused. */
@Serializable
data class TimerPause(
    @Serializable(InstantSerializer::class) val start: Instant,
    @Serializable(InstantSerializer::class) val end: Instant? = null,
)

/** Everything needed to rebuild a running timer after the process dies: dates and spans, never a counter. */
@Serializable
data class TimerSnapshot(
    val plan: TimerPlan,
    @Serializable(InstantSerializer::class) val startedAt: Instant,
    val pauses: List<TimerPause>,
    /** Seconds added by skipping ahead, so elapsed time jumps to the next step's offset. */
    val skippedS: Double,
    /** Set when the brew was ended before the plan ran out. */
    val endedElapsedS: Double? = null,
    val endedEarly: Boolean = false,
)

/** Persistence for the one running timer. Saving is best effort: a failed write never stops the brew. */
interface TimerStateStore {
    fun save(snapshot: TimerSnapshot)
    /** `null` when nothing is stored or the stored data is unreadable (unreadable data is discarded). */
    fun load(): TimerSnapshot?
    fun clear()

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
        fun encode(snapshot: TimerSnapshot): String = json.encodeToString(TimerSnapshot.serializer(), snapshot)
        fun decode(text: String): TimerSnapshot? = runCatching { json.decodeFromString(TimerSnapshot.serializer(), text) }.getOrNull()
    }
}

sealed interface TimerPhase {
    data object NotStarted : TimerPhase
    data object Running : TimerPhase
    data object Paused : TimerPhase
    data class Finished(val endedEarly: Boolean) : TimerPhase
}

/** What the screen shows at one instant. */
data class TimerState(
    val phase: TimerPhase,
    val elapsedS: Double,
    val currentIndex: Int?,
    val current: TimerStep?,
    val next: TimerStep?,
    val secondsIntoStep: Double,
    /** Seconds until the next step starts, or until the brew ends on the last step. */
    val secondsToNextChange: Double?,
    val totalDurationS: Int,
) {
    /** The recipe's target time has passed; the brew keeps running until the user finishes it. */
    val targetReached: Boolean get() = elapsedS >= totalDurationS
    /** Share of the target time elapsed, clamped to 0..1. */
    val progress: Double get() = if (totalDurationS > 0) (elapsedS / totalDurationS).coerceIn(0.0, 1.0) else 0.0
    val remainingS: Double get() = maxOf(totalDurationS - elapsedS, 0.0)
    val overtimeS: Double get() = maxOf(elapsedS - totalDurationS, 0.0)
}

private fun seconds(from: Instant, to: Instant): Double = Duration.between(from, to).toNanos() / 1e9

/** Runs recipe steps against an injectable clock. All state is derived from persisted dates. */
class TimerEngine(val plan: TimerPlan, private val clock: TimerClock, private val store: TimerStateStore) {
    private var snapshot: TimerSnapshot? = null

    companion object {
        /** Rebuilds the timer that was running when the app last stopped, or `null` if none. */
        fun restore(clock: TimerClock, store: TimerStateStore): TimerEngine? {
            val saved = store.load() ?: return null
            return TimerEngine(saved.plan, clock, store).also { it.snapshot = saved }
        }
    }

    fun start() {
        if (snapshot != null) return
        commit(TimerSnapshot(plan, clock.now(), emptyList(), 0.0, null, false))
    }

    fun pause() {
        val saved = snapshot ?: return
        if (state().phase != TimerPhase.Running) return
        commit(saved.copy(pauses = saved.pauses + TimerPause(clock.now(), null)))
    }

    fun resume() {
        val saved = snapshot ?: return
        if (state().phase != TimerPhase.Paused || saved.pauses.isEmpty()) return
        val last = saved.pauses.last()
        commit(saved.copy(pauses = saved.pauses.dropLast(1) + last.copy(end = maxOf(clock.now(), last.start))))
    }

    private fun isActive(phase: TimerPhase) = phase == TimerPhase.Running || phase == TimerPhase.Paused

    /** Ends the brew at the time reached, early or not. Past the target this is the normal finish. */
    fun finish() {
        val saved = snapshot ?: return
        val current = state()
        if (!isActive(current.phase)) return
        commit(saved.copy(endedElapsedS = current.elapsedS, endedEarly = !current.targetReached))
    }

    /** Jumps to the start of the next step; on the last step it finishes the brew normally. */
    fun skipToNextStep() {
        val saved = snapshot ?: return
        val current = state()
        if (!isActive(current.phase)) return
        val next = current.next
        commit(
            if (next != null) saved.copy(skippedS = saved.skippedS + next.startOffsetS - current.elapsedS)
            else saved.copy(endedElapsedS = plan.totalDurationS.toDouble(), endedEarly = false),
        )
    }

    /** Stops the brew now and keeps the elapsed time reached. */
    fun endEarly() {
        val saved = snapshot ?: return
        val current = state()
        if (!isActive(current.phase)) return
        commit(saved.copy(endedElapsedS = current.elapsedS, endedEarly = true))
    }

    /** Forgets the persisted timer, e.g. after the brew form has taken its values. */
    fun discard() {
        snapshot = null
        store.clear()
    }

    fun state(): TimerState {
        val saved = snapshot ?: return derive(TimerPhase.NotStarted, 0.0)
        saved.endedElapsedS?.let { return derive(TimerPhase.Finished(saved.endedEarly), it) }
        val paused = saved.pauses.lastOrNull()?.let { it.end == null } ?: false
        val reference = if (paused) saved.pauses.last().start else clock.now()
        val pausedS = saved.pauses.sumOf { p -> p.end?.let { maxOf(seconds(p.start, it), 0.0) } ?: 0.0 }
        val elapsed = maxOf(seconds(saved.startedAt, reference) - pausedS + saved.skippedS, 0.0)
        // Past the target the brew keeps running (the coffee may still be draining) until finished.
        return derive(if (paused) TimerPhase.Paused else TimerPhase.Running, elapsed)
    }

    private fun derive(phase: TimerPhase, elapsed: Double): TimerState {
        val steps = plan.steps
        val total = plan.totalDurationS.toDouble()
        if (phase == TimerPhase.NotStarted) {
            return TimerState(phase, 0.0, null, null, steps.firstOrNull(), 0.0, null, plan.totalDurationS)
        }
        if (phase is TimerPhase.Finished) {
            return TimerState(phase, elapsed, null, null, null, 0.0, null, plan.totalDurationS)
        }
        val index = steps.indexOfLast { it.startOffsetS <= elapsed }.takeIf { it >= 0 }
        val next = index?.let { if (it + 1 < steps.size) steps[it + 1] else null }
        val boundary = next?.startOffsetS?.toDouble() ?: total
        return TimerState(
            phase = phase,
            elapsedS = elapsed,
            currentIndex = index,
            current = index?.let { steps[it] },
            next = if (index == null) steps.first() else next,
            secondsIntoStep = index?.let { elapsed - steps[it].startOffsetS } ?: 0.0,
            secondsToNextChange = if (index == null) steps[0].startOffsetS - elapsed
            else if (boundary > elapsed) boundary - elapsed else null,
            totalDurationS = plan.totalDurationS,
        )
    }

    private fun commit(saved: TimerSnapshot) {
        snapshot = saved
        store.save(saved)
    }
}
