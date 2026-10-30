package app.rarecreatures.nextcup.beans

import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.data.BrewBean
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.data.Roaster
import app.rarecreatures.nextcup.data.RoastLevel
import app.rarecreatures.nextcup.data.now
import app.rarecreatures.nextcup.kit.BeanStock
import app.rarecreatures.nextcup.kit.Freshness
import app.rarecreatures.nextcup.kit.FreshnessState
import app.rarecreatures.nextcup.kit.FrozenSpan
import app.rarecreatures.nextcup.kit.StockLevel
import androidx.room.withTransaction
import java.time.Instant

/** The values the bean editor edits. Weight is in grams: the screen converts from the user's unit first. */
data class BeanFields(
    val name: String = "",
    val roasterName: String = "",
    val roasterCity: String = "",
    val roasterWebsite: String? = null,
    val originCountry: String = "",
    val region: String = "",
    val farm: String = "",
    val process: String = "",
    val varietal: String = "",
    val roastLevel: RoastLevel? = null,
    val roastDate: Long? = null,
    val flavorNotes: String = "",
    val bagWeightG: Double? = null,
    val status: BeanStatus = BeanStatus.IN_USE,
    val isDecaf: Boolean = false,
    val photo: ByteArray? = null,
) {
    companion object {
        fun of(bean: Bean, roaster: Roaster?) = BeanFields(
            bean.name, roaster?.name ?: "", roaster?.city ?: "", roaster?.website, bean.originCountry ?: "", bean.region ?: "",
            bean.farm ?: "", bean.process ?: "", bean.varietal ?: "", bean.roastLevel, bean.roastDate, bean.bagFlavorNotes.joinToString(", "),
            bean.bagWeightG, bean.status, bean.isDecaf, bean.photo,
        )

        /** Notes typed as "jasmine, peach; honey" become separate, de-duplicated notes. */
        fun notes(text: String): List<String> {
            val seen = mutableSetOf<String>()
            return text.split(',', ';', '\n').map { it.trim() }.filter { it.isNotEmpty() && seen.add(it.lowercase()) }
        }
    }

    override fun equals(other: Any?) = other is BeanFields && copy(photo = null).toString() == other.copy(photo = null).toString() &&
        (photo?.contentEquals(other.photo ?: ByteArray(0)) ?: (other.photo == null))
    override fun hashCode() = name.hashCode()
}

class BeanError(message: String) : Exception(message)

/** Add, change, move and delete beans. Deleting a bean keeps every brew: each keeps the bean's name as logged. */
class BeanService(private val db: NextCupDatabase) {
    suspend fun save(fields: BeanFields, editing: Bean? = null): Bean = db.withTransaction {
        val name = fields.name.trim()
        if (name.isEmpty()) throw BeanError("Give the bean a name.")
        if (fields.bagWeightG != null && fields.bagWeightG <= 0) throw BeanError("The bag weight must be more than zero.")
        val roaster = roaster(fields.roasterName)?.let { r ->
            val updated = r.copy(
                city = clean(fields.roasterCity) ?: r.city, website = fields.roasterWebsite ?: r.website, updatedAt = now(),
            )
            db.roasters().upsert(updated)
            updated
        }
        val base = editing ?: Bean()
        val bean = base.copy(
            name = name, originCountry = clean(fields.originCountry), region = clean(fields.region), farm = clean(fields.farm),
            process = clean(fields.process), varietal = clean(fields.varietal), roastLevel = fields.roastLevel, roastDate = fields.roastDate,
            bagFlavorNotes = BeanFields.notes(fields.flavorNotes), bagWeightG = fields.bagWeightG, status = fields.status,
            isDecaf = fields.isDecaf, photo = fields.photo, roasterId = roaster?.id, updatedAt = now(),
        )
        db.beans().upsert(bean)
        bean
    }

    suspend fun setStatus(bean: Bean, status: BeanStatus) = db.beans().upsert(bean.copy(status = status, updatedAt = now()))

    /** One freezer stay is kept per bag, so a second freeze is refused instead of dropping the first stay's days. */
    suspend fun freeze(bean: Bean, on: Long = now()) {
        if (bean.frozenOn != null) throw BeanError(
            if (bean.thawedOn == null) "This bag is already in the freezer." else "This bag has already had its freezer stay. Next Cup keeps one freezer stay per bag.",
        )
        db.beans().upsert(bean.copy(frozenOn = on, thawedOn = null, updatedAt = now()))
    }

    suspend fun thaw(bean: Bean, on: Long = now()) {
        val frozen = bean.frozenOn
        if (frozen == null || bean.thawedOn != null) throw BeanError("This bag is not in the freezer.")
        db.beans().upsert(bean.copy(thawedOn = maxOf(on, frozen), updatedAt = now()))
    }

    /** Makes the remaining amount equal [grams] by adjusting the correction, so logged brews are never rewritten. */
    suspend fun setRemaining(bean: Bean, uses: List<BrewBean>, grams: Double) {
        val adjustment = BeanStock.adjustmentG(grams, bean.bagWeightG, uses.map { it.grams })
            ?: throw BeanError("Enter how much is left, from zero up. This bag has no weight yet.")
        db.beans().upsert(bean.copy(remainingAdjustmentG = adjustment, updatedAt = now()))
    }

    private fun clean(text: String) = text.trim().ifEmpty { null }

    /** The roaster with this name (any case), created if none exists. An empty name means no roaster. */
    private suspend fun roaster(name: String): Roaster? {
        val clean = clean(name) ?: return null
        return db.roasters().all().firstOrNull { it.name.equals(clean, ignoreCase = true) } ?: Roaster(name = clean).also { db.roasters().upsert(it) }
    }
}

/** Derived bean values, never stored. */
object BeanMath {
    fun remainingG(bean: Bean, uses: List<BrewBean>) = BeanStock.remainingG(bean.bagWeightG, uses.map { it.grams }, bean.remainingAdjustmentG)
    fun stock(bean: Bean, uses: List<BrewBean>): StockLevel = BeanStock.level(remainingG(bean, uses), bean.bagWeightG)
    private fun spans(bean: Bean) = bean.frozenOn?.let { listOf(FrozenSpan(Instant.ofEpochMilli(it), bean.thawedOn?.let(Instant::ofEpochMilli))) } ?: emptyList()
    fun freshness(bean: Bean): FreshnessState = Freshness.state(bean.roastDate?.let(Instant::ofEpochMilli), spans(bean), Instant.now())
    fun ageDays(bean: Bean): Int? = Freshness.ageDays(bean.roastDate?.let(Instant::ofEpochMilli), spans(bean), Instant.now())

    fun freshnessTitle(state: FreshnessState) = when (state) {
        FreshnessState.UNKNOWN -> "No roast date"
        FreshnessState.RESTING -> "Resting"
        FreshnessState.PEAK -> "Peak"
        FreshnessState.PAST_PEAK -> "Past peak"
        FreshnessState.FROZEN -> "Frozen"
    }
}
