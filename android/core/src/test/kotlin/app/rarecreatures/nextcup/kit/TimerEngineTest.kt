package app.rarecreatures.nextcup.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class FakeClock(private var current: Instant = Instant.ofEpochSecond(1_800_000_000)) : TimerClock {
    override fun now() = current
    fun advance(seconds: Double) { current = current.plusNanos((seconds * 1e9).toLong()) }
}

class MemoryStore : TimerStateStore {
    private var saved: TimerSnapshot? = null
    var saveCount = 0
    override fun save(snapshot: TimerSnapshot) { saved = snapshot; saveCount++ }
    override fun load() = saved
    override fun clear() { saved = null }
}

private fun makePlan() = TimerPlan.of(
    listOf(
        TimerStep(0, "Bloom", startOffsetS = 0, targetCumulativeWaterG = 45.0),
        TimerStep(1, "Pour", startOffsetS = 45, targetCumulativeWaterG = 250.0),
        TimerStep(2, "Drawdown", startOffsetS = 120),
    ),
    180,
)

class TimerPlanTest {
    @Test fun rejectsEmptyNegativeAndShortPlans() {
        assertEquals(TimerPlanError.Kind.NO_STEPS, assertThrows(TimerPlanError::class.java) { TimerPlan.of(emptyList(), 10) }.kind)
        assertEquals(TimerPlanError.Kind.NEGATIVE_OFFSET, assertThrows(TimerPlanError::class.java) { TimerPlan.of(listOf(TimerStep(0, "A", startOffsetS = -1)), 10) }.kind)
        assertEquals(TimerPlanError.Kind.TOTAL_NOT_AFTER_LAST_STEP, assertThrows(TimerPlanError::class.java) { TimerPlan.of(listOf(TimerStep(0, "A", startOffsetS = 10)), 10) }.kind)
    }

    @Test fun sortsStepsByOffset() {
        val plan = TimerPlan.of(listOf(TimerStep(1, "B", startOffsetS = 30), TimerStep(0, "A", startOffsetS = 0)), 60)
        assertEquals(listOf("A", "B"), plan.steps.map { it.label })
    }
}

class TimerEngineTest {
    private val clock = FakeClock()
    private val store = MemoryStore()
    private val engine = TimerEngine(makePlan(), clock, store)

    @Test fun notStartedShowsFirstStepAsNext() {
        val state = engine.state()
        assertEquals(TimerPhase.NotStarted, state.phase)
        assertNull(state.current)
        assertEquals("Bloom", state.next?.label)
        assertNull(store.load())
    }

    @Test fun stepsChangeAtTheirOffsets() {
        engine.start()
        assertEquals("Bloom", engine.state().current?.label)
        assertEquals("Pour", engine.state().next?.label)
        assertEquals(45.0, engine.state().secondsToNextChange)
        clock.advance(44.5)
        assertEquals("Bloom", engine.state().current?.label)
        clock.advance(0.5)
        val pour = engine.state()
        assertEquals("Pour", pour.current?.label)
        assertEquals(1, pour.currentIndex)
        assertEquals(0.0, pour.secondsIntoStep, 0.0)
        assertEquals(75.0, pour.secondsToNextChange)
        clock.advance(75.0)
        val last = engine.state()
        assertEquals("Drawdown", last.current?.label)
        assertNull(last.next)
        assertEquals(60.0, last.secondsToNextChange)
    }

    @Test fun keepsRunningPastTheTargetUntilFinished() {
        engine.start()
        clock.advance(200.0)
        val over = engine.state()
        assertEquals(TimerPhase.Running, over.phase)
        assertTrue(over.targetReached)
        assertEquals(1.0, over.progress, 0.0)
        assertEquals(0.0, over.remainingS, 0.0)
        assertEquals(20.0, over.overtimeS, 0.0)
        assertEquals("Drawdown", over.current?.label)
        assertNull(over.secondsToNextChange)
        engine.finish()
        clock.advance(100.0)
        assertEquals(TimerPhase.Finished(false), engine.state().phase)
        assertEquals(200.0, engine.state().elapsedS, 0.0)
    }

    @Test fun finishBeforeTheTargetIsEarly() {
        engine.start()
        clock.advance(90.0)
        engine.finish()
        assertEquals(TimerPhase.Finished(true), engine.state().phase)
        assertEquals(90.0, engine.state().elapsedS, 0.0)
    }

    @Test fun pauseFreezesElapsedAndResumeContinues() {
        engine.start()
        clock.advance(30.0)
        engine.pause()
        clock.advance(600.0)
        assertEquals(TimerPhase.Paused, engine.state().phase)
        assertEquals(30.0, engine.state().elapsedS, 0.0)
        engine.resume()
        assertEquals(TimerPhase.Running, engine.state().phase)
        clock.advance(20.0)
        assertEquals(50.0, engine.state().elapsedS, 0.0)
        assertEquals("Pour", engine.state().current?.label)
    }

    @Test fun multiplePausesAccumulate() {
        engine.start()
        clock.advance(10.0); engine.pause(); clock.advance(100.0); engine.resume()
        clock.advance(10.0); engine.pause(); clock.advance(100.0); engine.resume()
        clock.advance(10.0)
        assertEquals(30.0, engine.state().elapsedS, 0.0)
    }

    @Test fun controlsIgnoreWrongPhases() {
        engine.pause(); engine.resume(); engine.skipToNextStep(); engine.endEarly()
        assertEquals(TimerPhase.NotStarted, engine.state().phase)
        assertEquals(0, store.saveCount)
        engine.start()
        engine.resume()
        clock.advance(5.0)
        engine.start()
        assertEquals(5.0, engine.state().elapsedS, 0.0)
    }

    @Test fun skipJumpsToTheNextStepOffset() {
        engine.start()
        clock.advance(10.0)
        engine.skipToNextStep()
        assertEquals("Pour", engine.state().current?.label)
        assertEquals(45.0, engine.state().elapsedS, 0.0)
        clock.advance(5.0)
        assertEquals(50.0, engine.state().elapsedS, 0.0)
        engine.skipToNextStep()
        assertEquals("Drawdown", engine.state().current?.label)
        assertEquals(120.0, engine.state().elapsedS, 0.0)
    }

    @Test fun skipWhilePausedStaysPaused() {
        engine.start()
        clock.advance(10.0)
        engine.pause()
        engine.skipToNextStep()
        clock.advance(300.0)
        assertEquals(TimerPhase.Paused, engine.state().phase)
        assertEquals(45.0, engine.state().elapsedS, 0.0)
        engine.resume()
        clock.advance(1.0)
        assertEquals(46.0, engine.state().elapsedS, 0.0)
    }

    @Test fun skipOnTheLastStepFinishesNormally() {
        engine.start()
        clock.advance(130.0)
        engine.skipToNextStep()
        assertEquals(TimerPhase.Finished(false), engine.state().phase)
        assertEquals(180.0, engine.state().elapsedS, 0.0)
    }

    @Test fun endEarlyKeepsTheElapsedTime() {
        engine.start()
        clock.advance(95.0)
        engine.endEarly()
        clock.advance(1000.0)
        assertEquals(TimerPhase.Finished(true), engine.state().phase)
        assertEquals(95.0, engine.state().elapsedS, 0.0)
        engine.pause()
        engine.finish()
        assertEquals(TimerPhase.Finished(true), engine.state().phase)
    }

    @Test fun restoreAfterTerminationContinuesFromWallClock() {
        engine.start()
        clock.advance(20.0); engine.pause(); clock.advance(10.0); engine.resume()
        clock.advance(30.0)
        clock.advance(10.0)
        val restored = TimerEngine.restore(clock, store)!!
        val state = restored.state()
        assertEquals(TimerPhase.Running, state.phase)
        assertEquals(60.0, state.elapsedS, 0.0)
        assertEquals("Pour", state.current?.label)
        assertEquals(engine.plan, restored.plan)
    }

    @Test fun restoreKeepsAPauseThatWasOpen() {
        engine.start()
        clock.advance(25.0)
        engine.pause()
        clock.advance(3600.0)
        val restored = TimerEngine.restore(clock, store)!!
        assertEquals(TimerPhase.Paused, restored.state().phase)
        assertEquals(25.0, restored.state().elapsedS, 0.0)
    }

    @Test fun restoreKeepsSkipsAndEarlyEnds() {
        engine.start()
        clock.advance(5.0)
        engine.skipToNextStep()
        clock.advance(10.0)
        assertEquals(55.0, TimerEngine.restore(clock, store)!!.state().elapsedS, 0.0)
        engine.endEarly()
        val afterEnd = TimerEngine.restore(clock, store)!!
        assertEquals(TimerPhase.Finished(true), afterEnd.state().phase)
        assertEquals(55.0, afterEnd.state().elapsedS, 0.0)
    }

    @Test fun restoreWithNothingStoredIsNull() {
        assertNull(TimerEngine.restore(FakeClock(), MemoryStore()))
    }

    @Test fun discardClearsThePersistedTimer() {
        engine.start()
        engine.discard()
        assertNull(store.load())
        assertEquals(TimerPhase.NotStarted, engine.state().phase)
    }

    @Test fun clockMovingBackwardsNeverGoesNegative() {
        engine.start()
        clock.advance(-60.0)
        assertEquals(0.0, engine.state().elapsedS, 0.0)
        assertEquals(TimerPhase.Running, engine.state().phase)
    }

    @Test fun snapshotJsonRoundTripsAndRejectsCorruptText() {
        engine.start()
        clock.advance(12.0)
        engine.pause()
        val text = TimerStateStore.encode(store.load()!!)
        assertEquals(store.load(), TimerStateStore.decode(text))
        assertNull(TimerStateStore.decode("not json"))
    }
}

/** The handoff's acceptance run, on the bundled "Steep then release" timings. */
class SteepThenReleaseRunTest {
    private fun plan() = TimerPlan.of(
        listOf(
            TimerStep(0, "Close valve", startOffsetS = 0),
            TimerStep(1, "Pour", startOffsetS = 0, targetCumulativeWaterG = 270.0),
            TimerStep(2, "Stir", startOffsetS = 30),
            TimerStep(3, "Wait", startOffsetS = 40),
            TimerStep(4, "Open valve", startOffsetS = 120),
            TimerStep(5, "Drawdown", startOffsetS = 125),
        ),
        210,
    )

    @Test fun groupsStepsThatStartTogether() {
        val plan = plan()
        assertEquals(listOf(listOf(0, 1), listOf(2), listOf(3), listOf(4), listOf(5)), plan.displayGroups)
        assertEquals(0, plan.groupIndex(1))
        assertEquals(2, plan.groupIndex(3))
    }

    @Test fun walksTheScheduleWithoutTaps() {
        val clock = FakeClock()
        val engine = TimerEngine(plan(), clock, MemoryStore())
        engine.start()
        assertEquals(0.0, engine.state().elapsedS, 0.0)
        assertEquals("Pour", engine.state().current?.label)
        clock.advance(30.0)
        assertEquals("Stir", engine.state().current?.label)
        clock.advance(10.0)
        assertEquals("Wait", engine.state().current?.label)
        assertEquals(80.0, engine.state().secondsToNextChange)
        clock.advance(2.0)
        val at42 = engine.state()
        assertEquals(42.0, at42.elapsedS, 0.0)
        assertEquals(168.0, at42.remainingS, 0.0)
        assertEquals(20, Math.round(at42.progress * 100).toInt())
        assertEquals(78.0, at42.secondsToNextChange)
        assertEquals("Open valve", at42.next?.label)
        clock.advance(78.0)
        assertEquals("Open valve", engine.state().current?.label)
        clock.advance(5.0)
        assertEquals("Drawdown", engine.state().current?.label)
        clock.advance(85.0)
        assertTrue(engine.state().targetReached)
        assertEquals(TimerPhase.Running, engine.state().phase)
        clock.advance(12.0)
        engine.finish()
        assertEquals(TimerPhase.Finished(false), engine.state().phase)
        assertEquals(222.0, engine.state().elapsedS, 0.0)
    }
}
