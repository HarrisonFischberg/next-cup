package app.rarecreatures.nextcup.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BrewSceneTest {
    private fun steps(vararg pairs: Pair<Double, String>) = pairs.map { BrewSceneStep(it.first, it.second) }
    private val cone = steps(0.0 to "bloom", 45.0 to "pour", 75.0 to "pour", 105.0 to "drawdown")
    private fun f(kind: BrewSceneKind, s: List<BrewSceneStep>, total: Double, t: Double) = BrewScene.frame(kind, s, total, t)

    @Test fun builtInKeysAndStylesPickTheirScene() {
        assertEquals(BrewSceneKind.INVERTED, BrewSceneKind.of("inverted-press", "immersion"))
        assertEquals(BrewSceneKind.POUR_OVER, BrewSceneKind.of("iced-pour-over", "cold"))
        assertEquals(BrewSceneKind.PRESS, BrewSceneKind.of(null, "immersion"))
        assertEquals(BrewSceneKind.ESPRESSO, BrewSceneKind.of("my-own", "espresso"))
        assertEquals(BrewSceneKind.POUR_OVER, BrewSceneKind.of(null, null))
    }

    @Test fun nothingMovesBeforeTheStart() = assertEquals(BrewSceneFrame(), f(BrewSceneKind.POUR_OVER, cone, 180.0, 0.0))

    @Test fun kettleTipsOnlyDuringTheFirstPartOfAPour() {
        assertTrue(f(BrewSceneKind.POUR_OVER, cone, 180.0, 50.0).pouring)
        assertFalse(f(BrewSceneKind.POUR_OVER, cone, 180.0, 72.0).pouring)
        assertFalse(f(BrewSceneKind.POUR_OVER, cone, 180.0, 120.0).kettleShown)
    }

    @Test fun pourOverFillsTheServerAndEmptiesTheBed() {
        val mid = f(BrewSceneKind.POUR_OVER, cone, 180.0, 90.0)
        val end = f(BrewSceneKind.POUR_OVER, cone, 180.0, 180.0)
        assertTrue(mid.bed == 1.0 && mid.dripping)
        assertTrue(end.bed == 0.0 && !end.dripping)
        assertTrue(end.vessel > mid.vessel)
    }

    @Test fun switchableHoldsWaterUntilTheValveOpens() {
        val s = steps(0.0 to "closeValve", 5.0 to "pour", 30.0 to "stir", 40.0 to "wait", 120.0 to "openValve", 150.0 to "drawdown")
        val steep = f(BrewSceneKind.SWITCHABLE, s, 210.0, 80.0)
        assertTrue(steep.bed == 1.0 && !steep.dripping && steep.vessel == 0.0 && steep.lidOn)
        val release = f(BrewSceneKind.SWITCHABLE, s, 210.0, 140.0)
        assertTrue(release.dripping && release.vessel > 0 && !release.lidOn)
    }

    @Test fun pressPlungesOnlyOnThePressStep() {
        val s = steps(0.0 to "pour", 20.0 to "stir", 30.0 to "wait", 240.0 to "press")
        assertEquals(0.0, f(BrewSceneKind.PRESS, s, 270.0, 100.0).plunger, 0.0)
        assertEquals(0.5, f(BrewSceneKind.PRESS, s, 270.0, 255.0).plunger, 0.0)
        assertEquals(1.0, f(BrewSceneKind.PRESS, s, 270.0, 300.0).plunger, 0.0)
        assertTrue(f(BrewSceneKind.PRESS, s, 270.0, 100.0).steeping)
    }

    @Test fun invertedPressFlipsHalfwayThroughTheInvertStep() {
        val s = steps(0.0 to "plug", 5.0 to "pour", 25.0 to "stir", 35.0 to "wait", 90.0 to "invert", 100.0 to "press")
        assertTrue(f(BrewSceneKind.INVERTED, s, 130.0, 60.0).inverted)
        assertTrue(f(BrewSceneKind.INVERTED, s, 130.0, 94.0).inverted)
        assertFalse(f(BrewSceneKind.INVERTED, s, 130.0, 96.0).inverted)
        val pressing = f(BrewSceneKind.INVERTED, s, 130.0, 115.0)
        assertTrue(pressing.plunger == 0.5 && pressing.vessel == 0.5)
    }

    @Test fun espressoBuildsPressureThenPulls() {
        val s = steps(0.0 to "pour", 8.0 to "wait")
        assertEquals(3.0, f(BrewSceneKind.ESPRESSO, s, 28.0, 3.0).pressureBar, 0.0)
        val pulling = f(BrewSceneKind.ESPRESSO, s, 28.0, 17.0)
        assertTrue(pulling.pressureBar == 9.0 && pulling.shot && !pulling.pouring)
        val done = f(BrewSceneKind.ESPRESSO, s, 28.0, 28.0)
        assertTrue(done.vessel == 1.0 && !done.shot && done.pressureBar == 0.0)
    }

    @Test fun coldBrewDarkensOverTheSteep() {
        val r = f(BrewSceneKind.COLD, steps(0.0 to "pour", 60.0 to "stir", 120.0 to "wait"), 57600.0, 28800.0)
        assertTrue(r.bed == 1.0 && r.darkness == 0.5)
    }

    @Test fun newBrewersFillTheirOwnDrawingOverTheSchedule() {
        assertEquals(BrewSceneKind.STILL, BrewSceneKind.of("moka-pot", "espresso"))
        assertEquals(BrewSceneKind.STILL, BrewSceneKind.of("drip-machine", "pourOver"))
        val half = f(BrewSceneKind.STILL, steps(0.0 to "pour", 30.0 to "heat"), 200.0, 100.0)
        assertEquals(0.5, half.vessel, 0.0)
        assertFalse(half.pouring)
    }
}

class StarterRecipesTest {
    private fun recipe(style: StarterStyle, roast: StarterRoast?, process: String? = null) = StarterRecipes.recipe(style, roast, process)

    @Test fun oneRecipePerStyle() = assertEquals(StarterStyle.entries, StarterRecipes.recipes(StarterRoast.LIGHT, null).map { it.style })

    @Test fun lightRoastsGetHotterWaterAndLongerContact() {
        for (style in StarterStyle.entries) {
            val light = recipe(style, StarterRoast.LIGHT)
            val dark = recipe(style, StarterRoast.DARK)
            assertTrue(light.totalTimeS > dark.totalTimeS)
            if (style != StarterStyle.COLD) assertTrue(light.tempC!! > dark.tempC!!)
        }
    }

    @Test fun roastsInOneBandShareNumbers() {
        fun n(s: StarterStyle, r: StarterRoast) = recipe(s, r).copy(note = "")
        assertEquals(n(StarterStyle.POUR_OVER, StarterRoast.ULTRA_LIGHT), n(StarterStyle.POUR_OVER, StarterRoast.LIGHT))
        assertEquals(n(StarterStyle.ESPRESSO, StarterRoast.MEDIUM_LIGHT), n(StarterStyle.ESPRESSO, StarterRoast.MEDIUM))
        assertEquals(n(StarterStyle.IMMERSION, StarterRoast.MEDIUM_DARK), n(StarterStyle.IMMERSION, StarterRoast.DARK))
    }

    @Test fun missingRoastAssumesMediumAndSaysSo() {
        val none = recipe(StarterStyle.POUR_OVER, null)
        assertEquals(recipe(StarterStyle.POUR_OVER, StarterRoast.MEDIUM).steps, none.steps)
        assertTrue(none.note.contains("medium roast is assumed"))
    }

    @Test fun fermentedProcessStartsOneDegreeCooler() {
        val washed = recipe(StarterStyle.POUR_OVER, StarterRoast.LIGHT, "washed").tempC!!
        val natural = recipe(StarterStyle.POUR_OVER, StarterRoast.LIGHT, "Natural").tempC!!
        assertEquals(washed - 1, natural, 0.0)
        assertNull(recipe(StarterStyle.COLD, StarterRoast.LIGHT, "natural").tempC)
    }

    @Test fun espressoYieldFollowsRoast() {
        assertEquals(45.0, recipe(StarterStyle.ESPRESSO, StarterRoast.LIGHT).waterG, 0.0)
        assertEquals(36.0, recipe(StarterStyle.ESPRESSO, StarterRoast.MEDIUM).waterG, 0.0)
        assertEquals(32.0, recipe(StarterStyle.ESPRESSO, StarterRoast.DARK).waterG, 0.0)
    }

    @Test fun everyRecipeIsTimeableInOrder() {
        for (roast in StarterRoast.entries + listOf(null)) for (item in StarterRecipes.recipes(roast, "natural")) {
            val offsets = item.steps.map { it.startOffsetS }
            assertEquals(offsets.sorted(), offsets)
            assertTrue(offsets.last() < item.totalTimeS)
            val targets = item.steps.mapNotNull { it.targetCumulativeWaterG }
            assertEquals(targets.sorted(), targets)
            assertEquals(item.waterG, targets.last(), 0.0)
            assertTrue(item.doseG > 0)
        }
    }
}
