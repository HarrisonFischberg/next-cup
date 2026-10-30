package app.rarecreatures.nextcup.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.abs

class BrewMathTest {
    @Test fun doseForYieldAllowsForWaterTheGroundsKeep() {
        assertTrue(abs(BrewMath.dose(234.0, 15.0)!! - 18) < 0.0001)
        assertEquals(18.0, BrewMath.dose(36.0, 2.0))
        assertNull(BrewMath.dose(0.0, 15.0))
        assertNull(BrewMath.dose(200.0, null))
    }

    @Test fun cupIsWhatThePourLeavesAfterTheGroundsDrink() {
        val cup = 18 * 29.5735
        val dose = BrewMath.dose(cup, 15.0)!!
        assertTrue(abs(dose * 15 - 614.0) < 1)
        assertTrue(abs(BrewMath.cupG(dose * 15, dose)!! - cup) < 0.0001)
        assertEquals(36.0, BrewMath.cupG(36.0, 18.0))
        assertNull(BrewMath.cupG(0.0, 18.0))
    }

    @Test fun ratioDividesWaterByDose() {
        assertEquals(250.0 / 15.0, BrewMath.ratio(15.0, 250.0))
        assertEquals("1:16.7", BrewMath.ratioLabel(BrewMath.ratio(15.0, 250.0)))
    }

    @Test fun iceCountsTowardWater() = assertEquals(16.0, BrewMath.ratio(20.0, 200.0, 120.0))

    @Test fun missingOrNonPositiveInputsAreNullNotZero() {
        assertNull(BrewMath.ratio(null, 250.0))
        assertNull(BrewMath.ratio(15.0, null))
        assertNull(BrewMath.ratio(0.0, 250.0))
        assertNull(BrewMath.espressoRatio(18.0, null))
        assertNull(BrewMath.extractionYield(1.4, null, 15.0))
        assertNull(BrewMath.ratioLabel(null))
    }

    @Test fun espressoRatioUsesYield() = assertEquals(2.0, BrewMath.espressoRatio(18.0, 36.0))

    @Test fun extractionYieldIsTDSTimesBeverageOverDose() {
        assertTrue(abs(BrewMath.extractionYield(1.4, 250.0, 15.0)!! - 23.3333) < 0.001)
    }
}

class RecipeScalerTest {
    private val recipe = ScalableRecipe(
        15.0, 250.0,
        steps = listOf(ScalableStep(0, 0, 45.0), ScalableStep(1, 45, null), ScalableStep(2, 75, 250.0)),
    )

    @Test fun scalesEveryTargetAndKeepsTiming() {
        val scaled = RecipeScaler.scale(recipe, 30.0)
        assertEquals(2.0, scaled.factor, 0.0)
        assertEquals(500.0, scaled.recipe.waterG, 0.0)
        assertEquals(listOf(90.0, null, 500.0), scaled.recipe.steps.map { it.targetCumulativeWaterG })
        assertEquals(listOf(0, 45, 75), scaled.recipe.steps.map { it.startOffsetS })
        assertTrue(scaled.notes.isEmpty())
    }

    @Test fun roundingProducesANote() {
        val scaled = RecipeScaler.scale(recipe, 16.0)
        assertEquals(267.0, scaled.recipe.waterG, 0.0)
        assertEquals(48.0, scaled.recipe.steps[0].targetCumulativeWaterG)
        assertEquals(1, scaled.notes.size)
        assertTrue(scaled.notes[0].contains("rounded"))
    }

    @Test fun roundedTargetsStayInOrder() {
        val targets = RecipeScaler.scale(recipe, 17.3).recipe.steps.mapNotNull { it.targetCumulativeWaterG }
        assertEquals(targets.sorted(), targets)
    }

    @Test fun iceScalesAndCountsTowardTotalWater() {
        val scaled = RecipeScaler.scale(ScalableRecipe(20.0, 200.0, 120.0, true), 10.0)
        assertEquals(100.0, scaled.recipe.waterG, 0.0)
        assertEquals(60.0, scaled.recipe.iceG)
        assertEquals(160.0, scaled.recipe.totalWaterG, 0.0)
        assertEquals(16.0, BrewMath.ratio(10.0, 100.0, 60.0))
    }

    @Test fun doseRoundsToATenthWithANote() {
        val scaled = RecipeScaler.scale(recipe, 15.04)
        assertEquals(15.0, scaled.recipe.doseG, 0.0)
        assertTrue("Dose is rounded to 0.1 g." in scaled.notes)
    }

    @Test fun invalidDosesAreRejected() {
        for (dose in listOf(0.0, -5.0, Double.POSITIVE_INFINITY)) {
            assertEquals(RecipeScalerError.Kind.INVALID_DOSE, assertThrows(RecipeScalerError::class.java) { RecipeScaler.scale(recipe, dose) }.kind)
        }
        assertEquals(
            RecipeScalerError.Kind.INVALID_RECIPE_DOSE,
            assertThrows(RecipeScalerError::class.java) { RecipeScaler.scale(recipe.copy(doseG = 0.0), 15.0) }.kind,
        )
    }
}

class FreshnessTest {
    private val utc = ZoneOffset.UTC
    private fun day(offset: Long): Instant = LocalDate.of(2026, 1, 1).plusDays(offset).atStartOfDay(utc).toInstant()

    @Test fun noRoastDateIsUnknown() {
        assertEquals(FreshnessState.UNKNOWN, Freshness.state(null, today = day(10), zone = utc))
        assertNull(Freshness.ageDays(null, today = day(10), zone = utc))
    }

    @Test fun futureRoastDateIsUnknown() = assertEquals(FreshnessState.UNKNOWN, Freshness.state(day(5), today = day(1), zone = utc))

    @Test fun windowsFromRoastDate() {
        fun state(age: Long) = Freshness.state(day(0), today = day(age), zone = utc)
        assertEquals(FreshnessState.RESTING, state(0))
        assertEquals(FreshnessState.RESTING, state(4))
        assertEquals(FreshnessState.PEAK, state(5))
        assertEquals(FreshnessState.PEAK, state(30))
        assertEquals(FreshnessState.PAST_PEAK, state(31))
    }

    @Test fun timeOfDayDoesNotChangeTheDayCount() {
        assertEquals(5, Freshness.ageDays(day(0).plusSeconds(23 * 3600), today = day(5).plusSeconds(60), zone = utc))
    }

    @Test fun frozenDaysAreExcludedFromAge() {
        val spans = listOf(FrozenSpan(day(3), day(33)))
        assertEquals(10, Freshness.ageDays(day(0), spans, day(40), utc))
        assertEquals(FreshnessState.PEAK, Freshness.state(day(0), spans, day(40), zone = utc))
    }

    @Test fun currentlyFrozenBagIsFrozenAndKeepsItsAge() {
        val spans = listOf(FrozenSpan(day(10)))
        assertEquals(FreshnessState.FROZEN, Freshness.state(day(0), spans, day(60), zone = utc))
        assertEquals(10, Freshness.ageDays(day(0), spans, day(60), utc))
    }

    @Test fun multipleSpansAndSpansBeforeRoastAreClipped() {
        val spans = listOf(FrozenSpan(day(-5), day(2)), FrozenSpan(day(10), day(14)))
        assertEquals(14, Freshness.ageDays(day(0), spans, day(20), utc))
    }
}

class UnitsTest {
    @Test fun metricIsIdentity() {
        val units = UnitPreferences()
        assertEquals(18.0, units.displayWeight(18.0), 0.0)
        assertEquals(93.0, units.displayTemperature(93.0), 0.0)
        assertEquals("g", units.weightSymbol)
        assertEquals("°C", units.temperatureSymbol)
    }

    @Test fun ounceAndFahrenheitKnownValues() {
        val units = UnitPreferences(WeightUnit.OUNCES, TemperatureUnit.FAHRENHEIT)
        assertEquals(1.0, units.displayWeight(28.349523125), 1e-12)
        assertEquals(212.0, units.displayTemperature(100.0), 0.0)
        assertEquals(32.0, units.displayTemperature(0.0), 0.0)
        assertEquals("oz", units.weightSymbol)
        assertEquals("°F", units.temperatureSymbol)
    }

    @Test fun roundTripsAreLossless() {
        val imperial = UnitPreferences(WeightUnit.OUNCES, TemperatureUnit.FAHRENHEIT)
        var grams = 0.5
        while (grams <= 1000) { assertEquals(grams, imperial.grams(imperial.displayWeight(grams)), 1e-9); grams += 37.3 }
        var c = -10.0
        while (c <= 100) { assertEquals(c, imperial.celsius(imperial.displayTemperature(c)), 1e-9); c += 7.7 }
    }
}
