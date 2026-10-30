package app.rarecreatures.nextcup.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import kotlin.math.abs

class BlendSharesTest {
    private fun total(s: List<Double>) = s.sum()

    @Test fun evenSplitGivesEachBeanTheSameShare() = assertEquals(listOf(10.0, 10.0), BlendShares.grams(20.0, listOf(1.0, 1.0)))
    @Test fun partsSetTheShares() = assertEquals(listOf(12.0, 8.0), BlendShares.grams(20.0, listOf(3.0, 2.0)))

    @Test fun thirdsStillAddUpToTheDose() {
        val shares = BlendShares.grams(20.0, listOf(1.0, 1.0, 1.0))
        assertEquals(3, shares.size)
        assertEquals(2000.0, Math.round(shares.sum() * 100).toDouble(), 0.0)
    }

    @Test fun singleBeanTakesTheWholeDose() = assertEquals(listOf(15.5), BlendShares.grams(15.5, listOf(1.0)))

    @Test fun zeroPartsFallBackToAnEvenSplit() {
        assertEquals(listOf(9.0, 9.0), BlendShares.grams(18.0, listOf(0.0, 0.0)))
        assertEquals(listOf(9.0, 9.0), BlendShares.grams(18.0, listOf(-1.0, Double.NaN)))
    }

    @Test fun noDoseOrNoBeansGivesZeros() {
        assertEquals(listOf(0.0, 0.0), BlendShares.grams(0.0, listOf(1.0, 1.0)))
        assertTrue(BlendShares.grams(18.0, emptyList()).isEmpty())
    }

    @Test fun percentagesAddUpToOneHundred() {
        assertEquals(listOf(75.0, 25.0), BlendShares.percentages(listOf(3.0, 1.0)))
        assertEquals(listOf(50.0, 50.0), BlendShares.percentages(listOf(0.0, 0.0)))
        assertTrue(BlendShares.percentages(emptyList()).isEmpty())
    }

    @Test fun addingABeanStartsItAtAnEvenShare() {
        assertEquals(listOf(100.0), BlendShares.appending(emptyList()))
        assertEquals(listOf(50.0, 50.0), BlendShares.appending(listOf(100.0)))
        val three = BlendShares.appending(listOf(60.0, 40.0))
        assertEquals(100.0 / 3.0, three[2], 0.0001)
        assertEquals(40.0, three[0], 0.0001)
        assertEquals(100.0, total(three), 0.0001)
    }

    @Test fun removingABeanGivesItsShareToTheOthers() {
        val rest = BlendShares.removing(1, listOf(50.0, 30.0, 20.0))
        assertEquals(2, rest.size)
        assertEquals(500.0 / 7.0, rest[0], 0.0001)
        assertEquals(100.0, total(rest), 0.0001)
        assertTrue(BlendShares.removing(0, listOf(100.0)).isEmpty())
    }

    @Test fun rebalancingKeepsTheTotalAndTheOthersInProportion() {
        val result = BlendShares.rebalanced(listOf(50.0, 30.0, 20.0), 0, 70.0)
        assertEquals(70.0, result[0], 0.0)
        assertEquals(18.0, result[1], 0.0001)
        assertEquals(12.0, result[2], 0.0001)
        assertEquals(100.0, total(result), 0.0001)
    }

    @Test fun aShareCannotDropOrTakeEverything() {
        assertEquals(listOf(5.0, 95.0), BlendShares.rebalanced(listOf(50.0, 50.0), 0, 0.0))
        assertEquals(listOf(95.0, 5.0), BlendShares.rebalanced(listOf(50.0, 50.0), 0, 100.0))
        assertEquals(listOf(100.0), BlendShares.rebalanced(listOf(100.0), 0, 40.0))
    }
}

class BestSoFarTest {
    private fun day(offset: Int) = Instant.ofEpochSecond(1_700_000_000L + offset * 86400L)

    @Test fun noBrewsGivesAnEmptySummary() {
        val s = BestSoFar.summarize(emptyList())
        assertEquals(0, s.brewCount)
        assertEquals(0, s.ratedCount)
        assertTrue(s.spread.isEmpty())
        assertNull(s.averageTenths)
        assertNull(s.best)
        assertTrue(s.grindHistory.isEmpty())
    }

    @Test fun spreadCountsEachGradeAndIgnoresUnrated() {
        val s = BestSoFar.summarize(
            listOf(BrewSample(day(0), 6), BrewSample(day(1), 8), BrewSample(day(2), 6), BrewSample(day(3), null), BrewSample(day(4), 0)),
        )
        assertEquals(5, s.brewCount)
        assertEquals(3, s.ratedCount)
        assertEquals(listOf(RatingCount(6, 2), RatingCount(8, 1)), s.spread)
        assertTrue(abs(s.averageTenths!! - 20.0 / 3.0) < 0.0001)
    }

    @Test fun bestIsTheHighestGradeAndTheNewestOfATie() {
        val older = BrewSample(day(0), 9, 15.0, 250.0, 94.0, 170, "21")
        val newer = BrewSample(day(5), 9, 16.0, 260.0, 93.0, 180, "22")
        val lower = BrewSample(day(9), 7, 15.0)
        assertEquals(newer, BestSoFar.summarize(listOf(older, lower, newer)).best)
    }

    @Test fun noGradeMeansNoBest() {
        val s = BestSoFar.summarize(listOf(BrewSample(day(0), grindSetting = "20")))
        assertNull(s.best)
        assertEquals(0, s.ratedCount)
    }

    @Test fun grindHistoryGroupsByGrinderDoseAndSetting() {
        val history = BestSoFar.summarize(
            listOf(
                BrewSample(day(0), 6, 15.0, grindSetting = "21", grinder = "Zed"),
                BrewSample(day(1), 8, 15.04, grindSetting = "21", grinder = "Zed"),
                BrewSample(day(2), 9, 18.0, grindSetting = "23", grinder = "Zed"),
                BrewSample(day(3), 5, 15.0, grindSetting = "30", grinder = "Alma"),
                BrewSample(day(4), doseG = 15.0, grindSetting = "25"),
                BrewSample(day(5), 10, 15.0, grindSetting = "   "),
            ),
        ).grindHistory
        assertEquals(listOf("Alma", "Zed", "Zed", null), history.map { it.grinder })
        assertEquals(listOf("30", "21", "23", "25"), history.map { it.setting })
        val zed = history[1]
        assertEquals(15.0, zed.doseG)
        assertEquals(2, zed.brews)
        assertEquals(7.0, zed.averageTenths)
        assertEquals(day(1), zed.lastUsed)
        assertNull(history[3].averageTenths)
    }
}
