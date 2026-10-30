package app.rarecreatures.nextcup.kit

import app.rarecreatures.nextcup.kit.Taxonomy.Dimension.FLAVOR
import app.rarecreatures.nextcup.kit.Taxonomy.Dimension.ORIGIN
import app.rarecreatures.nextcup.kit.Taxonomy.Dimension.ROAST
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class TaxonomyTest {
    private val json = """
        {"version": 3, "dimensions": {
          "origin": {"buckets": [{"key": "east-africa", "name": "East Africa"}, {"key": "central-america", "name": "Central America"}],
                     "map": {"Ethiopia": "east-africa", "costa rica": "central-america"}},
          "flavor": {"buckets": [{"key": "citrus", "name": "Citrus"}, {"key": "berry", "name": "Berry"}],
                     "map": {"lemon": "citrus", "lime": "citrus", "blueberry": "berry"}}
        }}
    """.trimIndent()
    private val t = Taxonomy.fromJson(json)

    @Test fun mapsBundledValuesDeterministically() {
        val first = t.map("Ethiopia", ORIGIN)
        assertEquals(first, t.map("Ethiopia", ORIGIN))
        assertEquals(Taxonomy.Mapping.Mapped(Taxonomy.Bucket("east-africa", "East Africa"), Taxonomy.Mapping.Source.BUNDLE), first)
    }

    @Test fun normalizesCaseAccentsAndSpacing() {
        for (raw in listOf("  COSTA   RICA ", "costa-rica", "Costa Rica", "Costá Rica")) assertEquals("central-america", t.map(raw, ORIGIN).bucket?.key)
    }

    @Test fun unknownValueIsUnmapped() {
        assertEquals(Taxonomy.Mapping.Unmapped("atlantis"), t.map("Atlantis", ORIGIN))
        assertEquals(Taxonomy.Mapping.Unmapped(""), t.map("   ", ORIGIN))
        assertNull(t.map("lemon", ORIGIN).bucket)
    }

    @Test fun listsBundledWordsPerBucket() {
        assertEquals(listOf("lemon", "lime"), t.words("citrus", FLAVOR))
        assertEquals(listOf("ethiopia"), t.words("east-africa", ORIGIN))
        assertTrue(t.words("citrus", ORIGIN).isEmpty())
    }

    @Test fun userAliasMapsAnUnmappedValue() {
        val aliases = t.alias("Atlantis", "berry", FLAVOR)!!
        assertEquals(Taxonomy.Mapping.Mapped(Taxonomy.Bucket("berry", "Berry"), Taxonomy.Mapping.Source.USER_ALIAS), t.map("atlantis", FLAVOR, aliases))
    }

    @Test fun userAliasOverridesTheBundle() {
        assertEquals("citrus", t.map("lime", FLAVOR).bucket?.key)
        val aliases = t.alias("Lime", "berry", FLAVOR)!!
        assertEquals("berry", t.map("lime", FLAVOR, aliases).bucket?.key)
        assertEquals("citrus", t.map("lemon", FLAVOR, aliases).bucket?.key)
    }

    @Test fun aliasForAnotherDimensionDoesNotApply() = assertNull(t.map("lime", ORIGIN, t.alias("lime", "berry", FLAVOR)!!).bucket)

    @Test fun remappingReplacesTheEarlierAlias() {
        val first = t.alias("mystery", "berry", FLAVOR)!!
        val second = t.alias("Mystery", "citrus", FLAVOR, first)!!
        assertEquals(1, second.size)
        assertEquals("citrus", t.map("mystery", FLAVOR, second).bucket?.key)
    }

    @Test fun aliasToAMissingBucketOrEmptyValueIsRejected() {
        assertNull(t.alias("x", "nope", FLAVOR))
        assertNull(t.alias("  ", "berry", FLAVOR))
    }

    @Test fun staleAliasWithMissingBucketFallsBackToTheBundle() =
        assertEquals("citrus", t.map("lime", FLAVOR, listOf(Taxonomy.Alias(FLAVOR, "lime", "removed"))).bucket?.key)

    @Test fun bucketsForAListAreDistinctAndOrdered() =
        assertEquals(listOf("berry", "citrus"), t.buckets(listOf("blueberry", "lemon", "lime", "unknown"), FLAVOR).map { it.key })

    @Test fun unmappedListIsDistinctNormalizedAndOffersTheUserAlias() {
        val raws = listOf("Grape-Soda", "grape soda", "lime", "", "Dragon  Fruit")
        assertEquals(listOf("grape soda", "dragon fruit"), t.unmapped(raws, FLAVOR))
        assertEquals(listOf("dragon fruit"), t.unmapped(raws, FLAVOR, t.alias("grape soda", "berry", FLAVOR)!!))
    }

    @Test fun rejectsABadBundle() {
        assertEquals("unknownBucket(origin, b)", assertThrows(Taxonomy.LoadError::class.java) {
            Taxonomy.fromJson("""{"version":1,"dimensions":{"origin":{"buckets":[{"key":"a","name":"A"}],"map":{"x":"b"}}}}""")
        }.message)
        assertEquals("unknownDimension(mood)", assertThrows(Taxonomy.LoadError::class.java) {
            Taxonomy.fromJson("""{"version":1,"dimensions":{"mood":{"buckets":[],"map":{}}}}""")
        }.message)
    }

    @Test fun theShippedBundleLoadsAndEveryBucketIsReachable() {
        val shipped = Taxonomy.fromJson(File("../../NextCup/Resources/taxonomy.json").readText())
        assertEquals("east-africa", shipped.map("Ethiopia", ORIGIN).bucket?.key)
        assertEquals("light", shipped.map("Medium Light", ROAST).bucket?.key)
        for (d in Taxonomy.Dimension.entries) assertFalse(shipped.buckets(d).isEmpty())
    }

    @Test fun exposesVersionAndBuckets() {
        assertEquals(3, t.version)
        assertEquals(listOf("east-africa", "central-america"), t.buckets(ORIGIN).map { it.key })
        assertTrue(t.buckets(ROAST).isEmpty())
    }
}
