package app.rarecreatures.nextcup.kit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.UUID

class DraftStoreTest {
    private val folder: File = Files.createTempDirectory("nextcup-draft").toFile()
    private fun file() = File(folder, "brew-draft.json")

    @Test fun listsEveryDraftWithWhatItBelongsTo() {
        val edited = UUID.randomUUID()
        val repeated = UUID.randomUUID()
        DraftStore(File(folder, "brew-draft.json")).save(BrewDraft(notes = "new"))
        DraftStore(File(folder, "brew-draft-${UUID.randomUUID()}.json")).save(BrewDraft(notes = "another new"))
        DraftStore(File(folder, "brew-edit-$edited-${UUID.randomUUID()}.json")).save(BrewDraft(id = edited, notes = "edit"))
        DraftStore(File(folder, "brew-again-$repeated.json")).save(BrewDraft(notes = "again"))
        File(folder, "notes.txt").writeText("not a draft")

        val found = DraftStore.all(folder)
        assertEquals(4, found.size)
        assertEquals(setOf("new", "another new"), found.filter { it.kind == SavedDraft.Kind.NewBrew }.map { it.draft.notes }.toSet())
        assertEquals("edit", found.first { it.kind == SavedDraft.Kind.Editing(edited) }.draft.notes)
        assertEquals("again", found.first { it.kind == SavedDraft.Kind.Repeating(repeated) }.draft.notes)
    }

    @Test fun loadsNothingBeforeAnythingIsSaved() = assertEquals(DraftLoad.None, DraftStore(file()).load())

    @Test fun roundTripsEveryField() {
        val store = DraftStore(file())
        val draft = BrewDraft(
            sourceKey = "run-1", methodID = UUID.randomUUID(), recipeID = UUID.randomUUID(), doseG = 15.5, waterG = 250.0,
            tempC = 94.0, totalTimeS = 187, grindSetting = "21 clicks", verdict = "sour", ratingTenths = 7,
            notes = "Bright, a little thin.", photo = byteArrayOf(1, 2, 3),
            targets = BrewTargets(15.0, 250.0, 96.0, 180), endedEarly = true,
        )
        assertTrue(store.save(draft).isSuccess)
        assertEquals(DraftLoad.Draft(draft), store.load())
    }

    @Test fun laterSaveReplacesEarlier() {
        val store = DraftStore(file())
        store.save(BrewDraft(doseG = 15.0))
        val later = BrewDraft(doseG = 15.0, notes = "typed after")
        store.save(later)
        assertEquals(DraftLoad.Draft(later), store.load())
    }

    @Test fun corruptFileIsDiscardedNotFatal() {
        file().writeText("{ not json")
        val store = DraftStore(file())
        assertEquals(DraftLoad.DiscardedCorrupt, store.load())
        assertFalse(file().exists())
        assertEquals(DraftLoad.None, store.load())
    }

    @Test fun failedWriteIsReportedAndKeepsThePreviousDraft() {
        val good = DraftStore(file())
        val first = BrewDraft(doseG = 15.0)
        good.save(first)
        val failing = DraftStore(file()) { _, _ -> throw IllegalStateException("boom") }
        assertTrue(failing.save(BrewDraft(doseG = 99.0)).isFailure)
        assertEquals(DraftLoad.Draft(first), good.load())
    }

    @Test fun clearRemovesTheDraftAndIsIdempotent() {
        val store = DraftStore(file())
        store.save(BrewDraft(doseG = 15.0))
        assertTrue(store.clear().isSuccess)
        assertEquals(DraftLoad.None, store.load())
        assertTrue(store.clear().isSuccess)
    }

    @Test fun canSaveNeedsPositiveDoseAndWater() {
        assertFalse(BrewDraft().canSave)
        assertFalse(BrewDraft(doseG = 15.0).canSave)
        assertFalse(BrewDraft(doseG = 0.0, waterG = 250.0).canSave)
        assertTrue(BrewDraft(doseG = 15.0, waterG = 250.0).canSave)
    }
}
