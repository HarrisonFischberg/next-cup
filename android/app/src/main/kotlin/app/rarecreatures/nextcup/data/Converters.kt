package app.rarecreatures.nextcup.data

import androidx.room.TypeConverter
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

/** Enums are stored as their iOS raw values; lists as JSON arrays of raw values. */
class Converters {
    private val strings = ListSerializer(String.serializer())
    private fun encode(list: List<String>) = Json.encodeToString(strings, list)
    private fun decode(text: String?): List<String> = text?.let { runCatching { Json.decodeFromString(strings, it) }.getOrNull() } ?: emptyList()

    @TypeConverter fun fromStrings(v: List<String>?): String? = v?.let(::encode)
    @TypeConverter fun toStrings(v: String?): List<String>? = v?.let(::decode)
    @TypeConverter fun fromParameters(v: List<BrewParameter>?): String? = v?.let { encode(it.map { p -> p.raw }) }
    @TypeConverter fun toParameters(v: String?): List<BrewParameter>? = v?.let { decode(it).mapNotNull { r -> rawOf<BrewParameter>(r) } }
    @TypeConverter fun fromStepKinds(v: List<StepKind>?): String? = v?.let { encode(it.map { p -> p.raw }) }
    @TypeConverter fun toStepKinds(v: String?): List<StepKind>? = v?.let { decode(it).mapNotNull { r -> rawOf<StepKind>(r) } }
    @TypeConverter fun fromVerdict(v: Verdict?): String? = v?.raw
    @TypeConverter fun toVerdict(v: String?): Verdict? = rawOf<Verdict>(v)
    @TypeConverter fun fromRoastLevel(v: RoastLevel?): String? = v?.raw
    @TypeConverter fun toRoastLevel(v: String?): RoastLevel? = rawOf<RoastLevel>(v)
    @TypeConverter fun fromBeanStatus(v: BeanStatus?): String? = v?.raw
    @TypeConverter fun toBeanStatus(v: String?): BeanStatus? = rawOf<BeanStatus>(v)
    @TypeConverter fun fromBrewStyle(v: BrewStyle?): String? = v?.raw
    @TypeConverter fun toBrewStyle(v: String?): BrewStyle? = rawOf<BrewStyle>(v)
    @TypeConverter fun fromBrewParameter(v: BrewParameter?): String? = v?.raw
    @TypeConverter fun toBrewParameter(v: String?): BrewParameter? = rawOf<BrewParameter>(v)
    @TypeConverter fun fromStepKind(v: StepKind?): String? = v?.raw
    @TypeConverter fun toStepKind(v: String?): StepKind? = rawOf<StepKind>(v)
    @TypeConverter fun fromSuggestionSource(v: SuggestionSource?): String? = v?.raw
    @TypeConverter fun toSuggestionSource(v: String?): SuggestionSource? = rawOf<SuggestionSource>(v)
    @TypeConverter fun fromSuggestionState(v: SuggestionState?): String? = v?.raw
    @TypeConverter fun toSuggestionState(v: String?): SuggestionState? = rawOf<SuggestionState>(v)
    @TypeConverter fun fromAIFeature(v: AIFeature?): String? = v?.raw
    @TypeConverter fun toAIFeature(v: String?): AIFeature? = rawOf<AIFeature>(v)
    @TypeConverter fun fromAIProvider(v: AIProvider?): String? = v?.raw
    @TypeConverter fun toAIProvider(v: String?): AIProvider? = rawOf<AIProvider>(v)
    @TypeConverter fun fromAIRequestStatus(v: AIRequestStatus?): String? = v?.raw
    @TypeConverter fun toAIRequestStatus(v: String?): AIRequestStatus? = rawOf<AIRequestStatus>(v)
    @TypeConverter fun fromTaxonomyDimension(v: TaxonomyDimension?): String? = v?.raw
    @TypeConverter fun toTaxonomyDimension(v: String?): TaxonomyDimension? = rawOf<TaxonomyDimension>(v)
}
