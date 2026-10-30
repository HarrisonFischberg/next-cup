package app.rarecreatures.nextcup.kit

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/** What the recipe asked for, kept beside the values the user actually brewed with. Never locks the form. */
@Serializable
data class BrewTargets(
    val doseG: Double? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
)

/** A bean in a brew being repeated: which bean (when it still exists), its name as it was, and its share. */
@Serializable
data class DraftBean(
    @Serializable(UUIDSerializer::class) val beanID: UUID?,
    val name: String,
    val grams: Double,
)

/**
 * The open brew form, saved outside the database so typed input survives navigation, backgrounding
 * and a crash. Canonical units only (grams, °C, seconds); `verdict` holds the stored raw value.
 */
@Serializable
data class BrewDraft(
    @Serializable(UUIDSerializer::class) val id: UUID = UUID.randomUUID(),
    /** Identifies what opened the form (a finished timer run), so reopening restores this draft. */
    val sourceKey: String? = null,
    @Serializable(InstantSerializer::class) val date: Instant = Instant.now(),
    @Serializable(UUIDSerializer::class) val methodID: UUID? = null,
    @Serializable(UUIDSerializer::class) val recipeID: UUID? = null,
    val doseG: Double? = null,
    val waterG: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val grindSetting: String = "",
    val verdict: String? = null,
    val ratingTenths: Int = 0,
    val notes: String = "",
    @Serializable(Base64Serializer::class) val photo: ByteArray? = null,
    val targets: BrewTargets? = null,
    val endedEarly: Boolean = false,
    /** The beans in the brew, as shares of the dose. `null` leaves the brew's beans alone on save. */
    val beans: List<DraftBean>? = null,
    @Serializable(UUIDSerializer::class) val grinderID: UUID? = null,
    /** Total dissolved solids of the cup in percent, if measured. */
    val tds: Double? = null,
    @Serializable(UUIDSerializer::class) val waterProfileID: UUID? = null,
) {
    /** A brew needs the two numbers every derived value rests on. */
    val canSave: Boolean get() = doseG != null && waterG != null && doseG > 0 && waterG > 0

    // ByteArray has identity equality; compare photos by content so autosave can skip unchanged drafts.
    override fun equals(other: Any?): Boolean =
        other is BrewDraft && plainEquals(other) && photo.contentEq(other.photo)

    private fun plainEquals(o: BrewDraft) = id == o.id && sourceKey == o.sourceKey && date == o.date && methodID == o.methodID &&
        recipeID == o.recipeID && doseG == o.doseG && waterG == o.waterG && tempC == o.tempC && totalTimeS == o.totalTimeS &&
        grindSetting == o.grindSetting && verdict == o.verdict && ratingTenths == o.ratingTenths && notes == o.notes &&
        targets == o.targets && endedEarly == o.endedEarly && beans == o.beans && grinderID == o.grinderID && tds == o.tds &&
        waterProfileID == o.waterProfileID

    override fun hashCode(): Int = id.hashCode()

    companion object {
        /** Identifies a "Brew again" draft, so reopening the same repeat restores it. */
        fun repeatKey(sourceID: UUID): String = "again:${sourceID.toString().uppercase()}"

        /**
         * A fresh brew that repeats [source]: same method, recipe, beans, amounts, temperature and grind,
         * with the time reset. Date, verdict, grade, notes and photo belong to the cup that was drunk.
         */
        fun repeating(source: BrewDraft, sourceID: UUID, beans: List<DraftBean>, now: Instant = Instant.now(), id: UUID = UUID.randomUUID()) =
            BrewDraft(
                id = id, sourceKey = repeatKey(sourceID), date = now, methodID = source.methodID,
                recipeID = source.recipeID, doseG = source.doseG, waterG = source.waterG, tempC = source.tempC,
                totalTimeS = null, grindSetting = source.grindSetting, targets = source.targets, beans = beans,
                grinderID = source.grinderID, waterProfileID = source.waterProfileID,
            )
    }
}

private fun ByteArray?.contentEq(other: ByteArray?): Boolean =
    if (this == null || other == null) this === other else contentEquals(other)
