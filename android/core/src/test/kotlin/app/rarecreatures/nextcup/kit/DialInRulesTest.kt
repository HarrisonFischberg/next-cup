package app.rarecreatures.nextcup.kit

import app.rarecreatures.nextcup.kit.DialInParameter.GRIND
import app.rarecreatures.nextcup.kit.DialInParameter.TEMPERATURE
import app.rarecreatures.nextcup.kit.DialInParameter.TIME
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DialInRulesTest {
    private fun input(
        verdict: DialInVerdict, style: DialInStyle = DialInStyle.POUR_OVER, tracked: Set<DialInParameter> = setOf(GRIND, TEMPERATURE, TIME),
        grind: String? = "20", water: Double? = 250.0, temp: Double? = 94.0, time: Int? = 180,
    ) = DialInInput(verdict, style, tracked, grind, water, temp, time)

    private fun change(outcome: DialInOutcome) = (outcome as? DialInOutcome.Change)?.draft
    private fun s(i: DialInInput) = DialInRules.suggest(i)

    @Test fun balancedKeepsEverything() {
        val outcome = s(input(DialInVerdict.BALANCED))
        assertTrue((outcome as DialInOutcome.Keep).message.contains("balanced"))
    }

    @Test fun sourGoesFinerFirst() {
        val d = change(s(input(DialInVerdict.SOUR)))
        assertEquals(GRIND, d?.parameter)
        assertEquals("20", d?.fromValue)
        assertEquals("19", d?.toValue)
    }

    @Test fun bitterGoesCoarserFirst() {
        val d = change(s(input(DialInVerdict.BITTER)))
        assertEquals(GRIND, d?.parameter)
        assertEquals("21", d?.toValue)
    }

    @Test fun grindKeepsTheTextAroundTheNumber() {
        assertEquals("20 clicks", change(s(input(DialInVerdict.SOUR, grind = "21 clicks")))?.toValue)
        assertEquals("6.5", change(s(input(DialInVerdict.BITTER, grind = "5.5")))?.toValue)
    }

    @Test fun wordsAndBlankGrindGetAWrittenStep() {
        val words = change(s(input(DialInVerdict.SOUR, grind = "medium fine")))
        assertEquals(GRIND, words?.parameter)
        assertEquals("one step finer", words?.toValue)
        val blank = change(s(input(DialInVerdict.BITTER, grind = null)))
        assertEquals("", blank?.fromValue)
        assertEquals("one step coarser", blank?.toValue)
    }

    @Test fun theFinestSettingFallsBackToAWrittenStep() = assertEquals("one step finer", change(s(input(DialInVerdict.SOUR, grind = "0")))?.toValue)

    @Test fun sourWithoutGrindTrackedRaisesTemperature() {
        val d = change(s(input(DialInVerdict.SOUR, tracked = setOf(TEMPERATURE, TIME))))
        assertEquals(TEMPERATURE, d?.parameter)
        assertEquals("94", d?.fromValue)
        assertEquals("96", d?.toValue)
    }

    @Test fun bitterWithoutGrindTrackedLowersTemperature() =
        assertEquals("92", change(s(input(DialInVerdict.BITTER, tracked = setOf(TEMPERATURE))))?.toValue)

    @Test fun temperatureStopsAtItsLimits() {
        assertEquals(
            DialInOutcome.Keep("No setting for this sour cup can be changed from here."),
            s(input(DialInVerdict.SOUR, tracked = setOf(TEMPERATURE), temp = 99.0)),
        )
        assertNull(change(s(input(DialInVerdict.BITTER, tracked = setOf(TEMPERATURE), temp = 80.0))))
    }

    @Test fun immersionAndColdUseSteepTime() {
        val immersion = change(s(input(DialInVerdict.SOUR, DialInStyle.IMMERSION, setOf(TIME), time = 240)))
        assertEquals(TIME, immersion?.parameter)
        assertEquals("270", immersion?.toValue)
        val cold = change(s(input(DialInVerdict.BITTER, DialInStyle.COLD, setOf(TIME, TEMPERATURE), time = 50_400)))
        assertEquals(TIME, cold?.parameter)
        assertEquals("43200", cold?.toValue)
    }

    @Test fun pourOverTimeIsAResultNotALever() = assertNull(change(s(input(DialInVerdict.SOUR, tracked = setOf(TIME)))))

    @Test fun coldBrewNeverGetsHotWaterAdvice() =
        assertEquals(TIME, change(s(input(DialInVerdict.SOUR, DialInStyle.COLD, setOf(TEMPERATURE, TIME))))?.parameter)

    @Test fun weakCutsWaterAndStrongAddsIt() {
        val weak = change(s(input(DialInVerdict.WEAK, water = 250.0)))
        assertEquals(DialInParameter.WATER, weak?.parameter)
        assertEquals("235", weak?.toValue)
        assertEquals("270", change(s(input(DialInVerdict.STRONG, water = 250.0)))?.toValue)
    }

    @Test fun espressoMovesTheOutputWeight() {
        val weak = change(s(input(DialInVerdict.WEAK, DialInStyle.ESPRESSO, water = 36.0)))
        assertEquals(DialInParameter.YIELD, weak?.parameter)
        assertEquals("32.5", weak?.toValue)
        assertEquals("39.5", change(s(input(DialInVerdict.STRONG, DialInStyle.ESPRESSO, water = 36.0)))?.toValue)
    }

    @Test fun strengthNeedsAWaterWeight() {
        assertNull(change(s(input(DialInVerdict.WEAK, water = null))))
        assertNull(change(s(input(DialInVerdict.STRONG, water = 0.0))))
    }

    @Test fun brightKeepsEverything() = assertTrue(s(input(DialInVerdict.BRIGHT)) is DialInOutcome.Keep)

    @Test fun everyChangeCarriesAReason() {
        for (v in DialInVerdict.entries) if (v != DialInVerdict.BALANCED && v != DialInVerdict.BRIGHT) {
            assertTrue(change(s(input(v)))!!.rationale.isNotEmpty())
        }
    }

    @Test fun theSameInputGivesTheSameAnswer() = assertEquals(s(input(DialInVerdict.SOUR)), s(input(DialInVerdict.SOUR)))
}

class GrinderGuideTest {
    @Test fun listsTheTwentyOneGrindersOnceEach() {
        assertEquals(21, GrinderGuide.all.size)
        assertEquals(21, GrinderGuide.all.map { it.name }.toSet().size)
        assertTrue(GrinderGuide.all.all { it.source.startsWith("https://honestcoffeeguide.com/") })
    }

    @Test fun everyGrinderHasAPourOverRange() = assertTrue(GrinderGuide.all.all { !it.pourOver.isNullOrEmpty() })

    @Test fun brewOnlyGrindersHaveNoEspressoRange() {
        for (name in listOf("Baratza Encore", "Fellow Ode Gen 2", "Timemore Chestnut S3")) assertNull(GrinderGuide.find(name)?.espresso)
        assertTrue(GrinderGuide.find("Niche Zero")?.espresso != null)
    }

    @Test fun findsByLooseName() {
        assertEquals("clicks", GrinderGuide.find("comandante c40 mk4")?.notation)
        assertNull(GrinderGuide.find("My grinder"))
        assertNull(GrinderGuide.find(null))
    }

    @Test fun mapsTheAppsMethodNames() {

        assertEquals(GrinderGuide.Method.POUR_OVER, GrinderGuide.method("Cone dripper"))
        assertEquals(GrinderGuide.Method.POUR_OVER, GrinderGuide.method("Switchable immersion dripper"))
        assertEquals(GrinderGuide.Method.FRENCH_PRESS, GrinderGuide.method("Press pot"))
        assertEquals(GrinderGuide.Method.AERO_PRESS, GrinderGuide.method("Inverted press"))
        assertEquals(GrinderGuide.Method.ESPRESSO, GrinderGuide.method("Espresso"))
        assertEquals(GrinderGuide.Method.COLD_BREW, GrinderGuide.method("Cold brew"))
        assertNull(GrinderGuide.method("Siphon"))
    }

    @Test fun recommendsOneSetting() {
        assertEquals("20", GrinderGuide.find("Comandante C40 MK4")?.recommended(GrinderGuide.Method.POUR_OVER))
        assertEquals("0.45", GrinderGuide.find("Niche Zero")?.recommended(GrinderGuide.Method.POUR_OVER))
        assertEquals("0.5.3", GrinderGuide.find("1Zpresso K-Ultra")?.recommended(GrinderGuide.Method.POUR_OVER))
        assertNull(GrinderGuide.find("Baratza Encore")?.recommended(GrinderGuide.Method.ESPRESSO))
    }

    @Test fun everyRecommendedSettingIsOnItsGrindersWheel() {
        for (guide in GrinderGuide.all) {
            val settings = guide.settings
            assertEquals("${guide.name} repeats a setting", settings.size, settings.toSet().size)
            for (method in GrinderGuide.Method.entries) {
                val start = guide.recommended(method) ?: continue
                assertTrue("${guide.name} $method: $start", GrinderGuide.setting(start, settings) != null)
            }
        }
        assertEquals("40", GrinderGuide.find("Comandante C40 MK4")?.settings?.last())
        assertTrue(GrinderGuide.find("Fellow Ode Gen 2")!!.settings.contains("3.7"))
        assertTrue(GrinderGuide.otherSettings.first() == "0" && GrinderGuide.otherSettings.last() == "40")
    }
}
