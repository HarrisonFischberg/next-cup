package app.rarecreatures.nextcup

import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.BrewBean
import app.rarecreatures.nextcup.data.DataArchive
import app.rarecreatures.nextcup.data.DataExchange
import app.rarecreatures.nextcup.data.RoastLevel
import app.rarecreatures.nextcup.data.Verdict
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DataArchiveTest {
    @Test fun datesAreSecondsSinceTwoThousandOneAsSwiftWritesThem() {
        assertEquals(0.0, DataArchive.swiftDate(978_307_200_000), 0.0)
        assertEquals(1_700_000_000_123, DataArchive.millis(DataArchive.swiftDate(1_700_000_000_123)))
    }

    @Test fun roundTripsRowsAndRelationships() {
        val bean = Bean(name = "Kenya Rukira", roastLevel = RoastLevel.LIGHT, roastDate = 1_760_000_000_000, bagFlavorNotes = listOf("blackcurrant"), photo = byteArrayOf(1, 2))
        val brew = Brew(doseG = 15.0, waterG = 250.0, verdict = Verdict.SOUR, alsoTasted = listOf("weak"), ratingTenths = 74, targetsJSON = """{"doseG":15}""")
        val use = BrewBean(grams = 15.0, beanNameSnapshot = bean.name, brewId = brew.id, beanId = bean.id)
        val text = DataArchive.encode(DataArchive(beans = listOf(bean), brews = listOf(brew), brewBeans = listOf(use)))
        assertTrue(text.contains("\"brewID\":\"${brew.id}\""))
        assertTrue(!text.contains("null"))
        val back = DataArchive.decode(text)
        assertEquals(bean.copy(photo = null).toString(), back.beans[0].copy(photo = null).toString())
        assertArrayEquals(bean.photo, back.beans[0].photo)
        assertEquals(brew.toString(), back.brews[0].toString())
        assertEquals(brew.targetsJSON, back.brews[0].targetsJSON)
        assertEquals(use, back.brewBeans[0])
    }

    @Test fun versionOneRatingsAreConvertedAndNewerArchivesRefused() {
        val v1 = """{"version":1,"exportedAt":0,"brews":[{"id":"a1b2c3d4-0000-0000-0000-000000000000","createdAt":0,"updatedAt":0,"date":0,"notes":"","isDraft":false,"ratingHalfSteps":7}]}"""
        val brew = DataArchive.decode(v1).brews.single()
        assertEquals(70, brew.ratingTenths)
        assertEquals("A1B2C3D4-0000-0000-0000-000000000000", brew.id)
        assertThrows(DataArchive.NewerVersion::class.java) { DataArchive.decode("""{"version":9}""") }
        assertThrows(DataArchive.Unreadable::class.java) { DataArchive.decode("not json") }
    }

    @Test fun csvQuotesAndDefusesFormulas() {
        val csv = DataExchange.csv(listOf(listOf("a", "notes"), listOf("1", "=SUM(A1), \"x\"")), setOf(1))
        assertEquals("a,notes\r\n1,\"'=SUM(A1), \"\"x\"\"\"\r\n", csv)
    }
}
