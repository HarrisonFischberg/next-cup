package app.rarecreatures.nextcup

import app.rarecreatures.nextcup.data.BuiltInContent
import app.rarecreatures.nextcup.data.Verdict
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class BuiltInContentTest {
    private fun shared(name: String) = File("../../NextCup/Resources/$name.json").readText()

    @Test fun theSharedBundleParsesAndEveryRecipeHasItsMethod() {
        val content = BuiltInContent.parse(shared("methods"), shared("recipes"))
        val keys = content.methods.map { it.key }.toSet()
        assertTrue(content.methods.size >= 7)
        assertTrue(content.recipes.isNotEmpty())
        assertEquals(keys.size, content.methods.size)
        for (r in content.recipes) assertTrue("${r.key} → ${r.methodKey}", r.methodKey in keys)
        assertEquals(content.recipes.size, content.recipes.map { it.key }.toSet().size)
    }

    @Test fun anUnknownStepKindFailsLoudly() {
        val recipes = """{"version":1,"recipes":[{"key":"x","methodKey":"m","name":"X","doseG":1,"waterG":2,"includesIce":false,"steps":[{"kind":"teleport","startOffsetS":0,"instruction":""}]}]}"""
        assertThrows(BuiltInContent.UnknownValue::class.java) { BuiltInContent.parse("""{"version":1,"methods":[]}""", recipes) }
    }
}

class VerdictTest {
    @Test fun balancedStandsAlone() {
        assertEquals("sour", Verdict.toggled(Verdict.SOUR, null))
        assertEquals("sour,weak", Verdict.toggled(Verdict.WEAK, "sour"))
        assertEquals("balanced", Verdict.toggled(Verdict.BALANCED, "sour,weak"))
        assertEquals("bitter", Verdict.toggled(Verdict.BITTER, "balanced"))
        assertNull(Verdict.toggled(Verdict.BITTER, "bitter"))
        assertEquals(listOf(Verdict.SOUR, Verdict.WEAK), Verdict.picked("sour,nonsense,weak"))
    }
}
