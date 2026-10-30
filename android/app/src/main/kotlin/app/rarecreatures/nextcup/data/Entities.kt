package app.rarecreatures.nextcup.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * The iOS SwiftData models (Models.swift) as Room tables. Field names match, so export JSON matches.
 * Ids are uppercase UUID text, as Swift writes them; dates are epoch milliseconds; relationships are ids,
 * with the iOS delete rules as foreign-key actions (cascade or set null).
 */
fun newId(): String = UUID.randomUUID().toString().uppercase()
fun now(): Long = System.currentTimeMillis()

@Entity(
    tableName = "brew",
    foreignKeys = [
        ForeignKey(BrewMethod::class, ["id"], ["methodId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(Recipe::class, ["id"], ["recipeId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(Grinder::class, ["id"], ["grinderId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(WaterProfile::class, ["id"], ["waterProfileId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("methodId"), Index("recipeId"), Index("grinderId"), Index("waterProfileId"), Index("suggestionFollowedId"), Index("date")],
)
data class Brew(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val date: Long = now(),
    val doseG: Double? = null,
    val waterG: Double? = null,
    /** Unused: espresso output weight is kept in `waterG`. Kept so exports match iOS. */
    val yieldG: Double? = null,
    val grindSetting: String? = null,
    val grindValue: Double? = null,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val tds: Double? = null,
    /** 0 to 100: the rating out of 10 in tenths. */
    val ratingTenths: Int? = null,
    /** The first taste picked; dial-in and the journal's colours follow it. */
    val verdict: Verdict? = null,
    /** Further tastes picked with `verdict`, as raw values. */
    val alsoTasted: List<String>? = null,
    val notes: String = "",
    val photo: ByteArray? = null,
    val targetsJSON: String? = null,
    /** Unused: drafts live in files. Kept so exports match iOS. */
    val isDraft: Boolean = false,
    val methodId: String? = null,
    val recipeId: String? = null,
    val grinderId: String? = null,
    val waterProfileId: String? = null,
    /** The suggestion this brew followed. Not a foreign key: suggestions belong to their source brew. */
    val suggestionFollowedId: String? = null,
) {
    /** Every taste picked, the first one first. */
    val verdicts: List<Verdict> get() = listOfNotNull(verdict) + (alsoTasted ?: emptyList()).mapNotNull { rawOf<Verdict>(it) }

    override fun equals(other: Any?) = other is Brew && other.id == id && other.updatedAt == updatedAt
    override fun hashCode() = id.hashCode()
}

@Entity(
    tableName = "brew_bean",
    foreignKeys = [
        ForeignKey(Brew::class, ["id"], ["brewId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(Bean::class, ["id"], ["beanId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("brewId"), Index("beanId")],
)
data class BrewBean(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val grams: Double = 0.0,
    val beanNameSnapshot: String = "",
    val brewId: String? = null,
    val beanId: String? = null,
)

@Entity(
    tableName = "bean",
    foreignKeys = [ForeignKey(Roaster::class, ["id"], ["roasterId"], onDelete = ForeignKey.SET_NULL)],
    indices = [Index("roasterId")],
)
data class Bean(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val originCountry: String? = null,
    val region: String? = null,
    val farm: String? = null,
    val process: String? = null,
    val varietal: String? = null,
    val roastLevel: RoastLevel? = null,
    val roastDate: Long? = null,
    val bagFlavorNotes: List<String> = emptyList(),
    val bagWeightG: Double? = null,
    val remainingAdjustmentG: Double = 0.0,
    val status: BeanStatus = BeanStatus.IN_USE,
    val isDecaf: Boolean = false,
    val frozenOn: Long? = null,
    val thawedOn: Long? = null,
    val ratingTenths: Int? = null,
    val photo: ByteArray? = null,
    /** Values AI suggests from what it knows of the coffee, as JSON; shown for review, never applied unasked. */
    val aiSuggestion: String? = null,
    val roasterId: String? = null,
) {
    override fun equals(other: Any?) = other is Bean && other.id == id && other.updatedAt == updatedAt
    override fun hashCode() = id.hashCode()
}

@Entity(tableName = "roaster")
data class Roaster(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val city: String? = null,
    val website: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val savedFromMap: Boolean = false,
)

@Entity(tableName = "brew_method", indices = [Index("builtInKey")])
data class BrewMethod(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val style: BrewStyle = BrewStyle.POUR_OVER,
    /** The iOS SF Symbol name; Android maps it to a Material icon. */
    val symbol: String = "cup.and.saucer",
    val trackedParameters: List<BrewParameter> = emptyList(),
    val defaultStepKinds: List<StepKind> = emptyList(),
    val sortOrder: Int = 0,
    val isHidden: Boolean = false,
    val builtInKey: String? = null,
)

@Entity(
    tableName = "recipe",
    foreignKeys = [ForeignKey(BrewMethod::class, ["id"], ["methodId"], onDelete = ForeignKey.SET_NULL)],
    indices = [Index("methodId"), Index("builtInKey")],
)
data class Recipe(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val credit: String? = null,
    @ColumnInfo(name = "creditURL") val creditURL: String? = null,
    val doseG: Double = 0.0,
    val waterG: Double = 0.0,
    val tempC: Double? = null,
    val totalTimeS: Int? = null,
    val tuningNote: String? = null,
    val includesIce: Boolean = false,
    val iceG: Double? = null,
    val builtInKey: String? = null,
    val methodId: String? = null,
)

@Entity(
    tableName = "recipe_step",
    foreignKeys = [ForeignKey(Recipe::class, ["id"], ["recipeId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("recipeId")],
)
data class RecipeStep(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val order: Int = 0,
    val kind: StepKind = StepKind.POUR,
    val startOffsetS: Int = 0,
    val targetCumulativeWaterG: Double? = null,
    val instruction: String = "",
    val recipeId: String? = null,
)

@Entity(tableName = "grinder")
data class Grinder(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val notes: String? = null,
)

@Entity(
    tableName = "suggestion",
    foreignKeys = [ForeignKey(Brew::class, ["id"], ["sourceBrewId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("sourceBrewId")],
)
data class Suggestion(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val source: SuggestionSource = SuggestionSource.RULES,
    val field: BrewParameter = BrewParameter.GRIND,
    val fromValue: String = "",
    val toValue: String = "",
    val rationale: String = "",
    val state: SuggestionState = SuggestionState.PROPOSED,
    @ColumnInfo(name = "modelID") val modelID: String? = null,
    val sourceBrewId: String? = null,
)

@Entity(
    tableName = "ai_request",
    foreignKeys = [ForeignKey(Brew::class, ["id"], ["brewId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("brewId"), Index("status")],
)
data class AIRequest(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val feature: AIFeature = AIFeature.DIAGNOSIS,
    val provider: AIProvider = AIProvider.ANTHROPIC,
    @ColumnInfo(name = "modelID") val modelID: String = "",
    val status: AIRequestStatus = AIRequestStatus.QUEUED,
    val payloadJSON: String = "",
    val attachment: ByteArray? = null,
    val resultJSON: String? = null,
    val errorMessage: String? = null,
    val attempts: Int = 0,
    val brewId: String? = null,
) {
    override fun equals(other: Any?) = other is AIRequest && other.id == id && other.updatedAt == updatedAt
    override fun hashCode() = id.hashCode()
}

@Entity(tableName = "taxonomy_alias")
data class TaxonomyAlias(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val dimension: TaxonomyDimension = TaxonomyDimension.ORIGIN,
    val rawValue: String = "",
    val bucketKey: String = "",
)

@Entity(tableName = "water_profile")
data class WaterProfile(
    @PrimaryKey val id: String = newId(),
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
    val name: String = "",
    val ppmHardness: Double? = null,
    val ppmAlkalinity: Double? = null,
    val calcium: Double? = null,
    val magnesium: Double? = null,
    val sodium: Double? = null,
)
