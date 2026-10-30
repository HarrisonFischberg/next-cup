package app.rarecreatures.nextcup.kit

import app.rarecreatures.nextcup.kit.Taxonomy.Dimension
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class RecommenderTest {
    private val eastAfrica = BucketRef(Dimension.ORIGIN, "east-africa", "East Africa")
    private val washed = BucketRef(Dimension.PROCESS, "washed", "Washed")
    private val natural = BucketRef(Dimension.PROCESS, "natural", "Natural")
    private val light = BucketRef(Dimension.ROAST, "light", "Light")
    private val dark = BucketRef(Dimension.ROAST, "dark", "Dark")
    private val citrus = BucketRef(Dimension.FLAVOR, "citrus", "Citrus")
    private fun day(o: Int) = Instant.ofEpochSecond(1_700_000_000L + o * 86_400L)

    private fun brew(method: String, key: String? = null, grade: Int?, day: Int = 0, buckets: List<BucketRef> = listOf(eastAfrica, washed, light), grind: String? = null) =
        RecommenderBrew(day(day), grade, key, method, doseG = 15.0, waterG = 250.0, tempC = 94.0, totalTimeS = 170, grindSetting = grind, buckets = buckets)

    private val bean = listOf(eastAfrica, washed, light, citrus)

    @Test fun ranksMethodsByAverageGrade() {
        val h = listOf(brew("Cone dripper", "cone-dripper", 9, 1), brew("Cone dripper", "cone-dripper", 8, 2), brew("Press pot", "press", 6, 3), brew("Press pot", "press", 5, 4))
        val r = Recommender.recommend(bean, h)
        assertFalse(r.isDefault)
        assertEquals(listOf("Cone dripper", "Press pot"), r.items.map { it.methodName })
        assertEquals(4, r.similarRatedCount)
    }

    @Test fun equalAveragesBreakTiesByBrewCountThenRecency() {
        val h = listOf(brew("A", "a", 8, 1), brew("B", "b", 8, 2), brew("B", "b", 8, 3), brew("C", "c", 8, 9))
        assertEquals(listOf("B", "C", "A"), Recommender.recommend(bean, h).items.map { it.methodName })
    }

    @Test fun startParametersComeFromTheBestBrewOfTheMethod() {
        val best = brew("Cone dripper", "cone-dripper", 10, 5, grind = " 21 clicks ").copy(doseG = 16.0, tempC = 95.0)
        val h = listOf(brew("Cone dripper", "cone-dripper", 7, 6, grind = "30"), best, brew("Cone dripper", "cone-dripper", 8, 7, grind = "25"))
        val item = Recommender.recommend(bean, h).items[0]
        assertEquals(16.0, item.start.doseG)
        assertEquals(95.0, item.start.tempC)
        assertEquals("21 clicks", item.start.grindSetting)
    }

    @Test fun explanationUsesOnlyComputedFacts() {
        val h = listOf(brew("Cone dripper", "cone-dripper", 90, 1), brew("Cone dripper", "cone-dripper", 80, 2), brew("Cone dripper", "cone-dripper", 70, 3))
        val item = Recommender.recommend(bean, h).items[0]
        val facts = (item.basis as Recommendation.Basis.History).facts
        assertEquals(3, facts.methodBrews)
        assertEquals(3, facts.similarBrews)
        assertEquals(80.0, facts.averageTenths, 0.0)
        assertEquals(90, facts.bestTenths)
        assertEquals(listOf("East Africa", "Washed", "Light"), facts.sharedBuckets)
        assertEquals("Your 3 brews with beans like this (East Africa, Washed, Light) averaged 8 of 10; the best was 9.", item.explanation)
    }

    @Test fun explanationSaysWhenTheMethodIsPartOfALargerSet() {
        val h = listOf(brew("Cone dripper", "cone-dripper", 9, 1), brew("Press pot", "press", 6, 2), brew("Press pot", "press", 6, 3))
        assertTrue(Recommender.recommend(bean, h).items[0].explanation.startsWith("Your 1 brew of 3 similar rated brews"))
    }

    @Test fun fewerThanThreeSimilarRatedBrewsFallBackToTheLabelledDefault() {
        val r = Recommender.recommend(bean, listOf(brew("Press pot", "press", 10, 1), brew("Press pot", "press", 10, 2)))
        assertTrue(r.isDefault)
        assertEquals(1, r.items.size)
        assertEquals("cone-dripper", r.items[0].methodKey)
        assertTrue(r.items[0].isDefault)
        assertTrue(r.items[0].explanation.contains("not based on your brews"))
        assertTrue(r.items[0].explanation.contains("light roasts"))
        assertEquals(2, r.similarRatedCount)
    }

    @Test fun coldStartWithNoHistoryUsesTheRoastBand() {
        val r = Recommender.recommend(listOf(dark), emptyList())
        assertTrue(r.isDefault)
        assertEquals("press", r.items[0].methodKey)
        assertEquals(90.0, r.items[0].start.tempC)
    }

    @Test fun beanWithoutRoastLevelGetsTheMediumDefaultAndSaysSo() {
        val r = Recommender.recommend(listOf(eastAfrica), emptyList())
        assertTrue(r.isDefault)
        assertEquals(93.0, r.items[0].start.tempC)
        assertTrue(r.items[0].explanation.contains("no roast level"))
    }

    @Test fun unratedAndDissimilarBrewsDoNotCount() {
        val h = listOf(
            brew("Cone dripper", "cone-dripper", null, 1), brew("Cone dripper", "cone-dripper", 0, 2),
            brew("Cone dripper", "cone-dripper", 9, 3, listOf(dark, natural)), brew("Cone dripper", "cone-dripper", 9, 4, listOf(light)),
        )
        val r = Recommender.recommend(bean, h)
        assertTrue(r.isDefault)
        assertEquals(0, r.similarRatedCount)
    }

    @Test fun flavorBucketsAloneNeverMakeBrewsSimilar() {
        val h = (1..4).map { brew("Cone dripper", "cone-dripper", 9, it, listOf(citrus)) }
        assertTrue(Recommender.recommend(listOf(citrus), h).isDefault)
    }

    @Test fun aBeanWithOnlyARoastLevelMatchesOnThatRoast() {
        val r = Recommender.recommend(listOf(dark), (1..3).map { brew("Press pot", "press", 8, it, listOf(dark)) })
        assertFalse(r.isDefault)
        assertEquals("Press pot", r.items[0].methodName)
    }

    @Test fun customMethodsGroupByNormalizedName() {
        val items = Recommender.recommend(bean, listOf(brew("Moka  Pot", grade = 8, day = 1), brew("moka pot", grade = 9, day = 2), brew("MOKA-POT", grade = 7, day = 3))).items
        assertEquals(1, items.size)
        assertNull(items[0].methodKey)
        assertEquals(15.0, items[0].start.doseG)
    }

    @Test fun limitCapsTheList() =
        assertEquals(2, Recommender.recommend(bean, (1..6).map { brew("M${it % 4}", "m${it % 4}", 8, it) }, 2).items.size)

    @Test fun sameInputGivesTheSameOrder() {
        val h = (1..8).map { brew("M${it % 3}", "m${it % 3}", 8, 1) }
        val first = Recommender.recommend(bean, h)
        repeat(5) { assertEquals(first, Recommender.recommend(bean, h)) }
    }
}
