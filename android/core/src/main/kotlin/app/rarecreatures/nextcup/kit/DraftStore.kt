package app.rarecreatures.nextcup.kit

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.util.UUID

/** What [DraftStore.load] found. */
sealed interface DraftLoad {
    data object None : DraftLoad
    data class Draft(val draft: BrewDraft) : DraftLoad
    /** The file could not be read as a draft. It was removed so the form opens blank. */
    data object DiscardedCorrupt : DraftLoad
}

/** A draft file found in the drafts folder, for the Journal's Unsaved brews. */
data class SavedDraft(val kind: Kind, val draft: BrewDraft, val changedAt: Instant, val store: DraftStore) {
    sealed interface Kind {
        data object NewBrew : Kind
        /** Unsaved changes to the saved brew with this id. */
        data class Editing(val brewID: UUID) : Kind
        /** A Brew again of the saved brew with this id. */
        data class Repeating(val brewID: UUID) : Kind
    }

    val id: String get() = store.file.path
}

/**
 * Autosaves the open brew form as one JSON file in the drafts folder. Writes are atomic and return a
 * result, so the form can show a failure and keep the draft in memory.
 */
class DraftStore(val file: File, private val write: (ByteArray, File) -> Unit = ::atomicWrite) {
    override fun equals(other: Any?) = other is DraftStore && other.file == file
    override fun hashCode() = file.hashCode()

    /** The file name without `.json`, used in links to an unsaved brew. */
    val name: String get() = file.nameWithoutExtension

    fun save(draft: BrewDraft): Result<Unit> = runCatching {
        write(json.encodeToString(BrewDraft.serializer(), draft).toByteArray(), file)
        bump()
    }

    fun load(): DraftLoad {
        if (!file.exists()) return DraftLoad.None
        val draft = runCatching { json.decodeFromString(BrewDraft.serializer(), file.readText()) }.getOrNull()
        if (draft == null) {
            file.delete()
            return DraftLoad.DiscardedCorrupt
        }
        return DraftLoad.Draft(draft)
    }

    fun clear(): Result<Unit> {
        if (!file.exists()) return Result.success(Unit)
        return if (file.delete()) Result.success(Unit).also { bump() } else Result.failure(IllegalStateException("Could not remove ${file.name}"))
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
        private val _changes = MutableStateFlow(0)
        /** Ticks after a draft file is written or removed, so lists of drafts refresh. */
        val changes: StateFlow<Int> = _changes
        private fun bump() { _changes.value++ }

        /** Set once at startup to the app's drafts folder (filesDir/Drafts). */
        @Volatile var folder: File = File(System.getProperty("java.io.tmpdir"), "Drafts")

        /** A fresh draft file for one opening of the form. */
        fun newBrew() = named("brew-draft-${UUID.randomUUID()}")
        /** A fresh draft file for a repeat of the saved brew [sourceID]. */
        fun repeating(sourceID: UUID) = named("brew-again-$sourceID-${UUID.randomUUID()}")
        /** A fresh draft file for changes to the saved brew [id]. */
        fun editing(id: UUID) = named("brew-edit-$id-${UUID.randomUUID()}")
        fun named(name: String) = DraftStore(File(folder, "$name.json"))

        /** Every readable draft in [directory], most recently changed first. Files that are not drafts are skipped. */
        fun all(directory: File = folder): List<SavedDraft> {
            val files = directory.listFiles()?.filter { it.extension == "json" } ?: emptyList()
            return files.mapNotNull { file ->
                val name = file.nameWithoutExtension
                fun brewID(prefix: String): UUID? =
                    if (!name.startsWith(prefix)) null else runCatching { UUID.fromString(name.drop(prefix.length).take(36)) }.getOrNull()
                val kind: SavedDraft.Kind = when {
                    name == "brew-draft" || name.startsWith("brew-draft-") -> SavedDraft.Kind.NewBrew
                    brewID("brew-edit-") != null -> SavedDraft.Kind.Editing(brewID("brew-edit-")!!)
                    brewID("brew-again-") != null -> SavedDraft.Kind.Repeating(brewID("brew-again-")!!)
                    else -> return@mapNotNull null
                }
                val store = DraftStore(file)
                val draft = (store.load() as? DraftLoad.Draft)?.draft ?: return@mapNotNull null
                SavedDraft(kind, draft, Instant.ofEpochMilli(file.lastModified()), store)
            }.sortedByDescending { it.changedAt }
        }

        fun atomicWrite(data: ByteArray, file: File) {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, ".${file.name}.tmp")
            tmp.writeBytes(data)
            if (!tmp.renameTo(file)) {
                tmp.delete()
                throw IllegalStateException("Could not write ${file.name}")
            }
        }
    }
}
