package app.rarecreatures.nextcup.kit

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * The small slice of JSON Schema the AI features need. Objects require every property and allow no
 * extras, which is also what OpenAI strict mode demands.
 */
@Serializable(JSONSchemaSerializer::class)
sealed interface JSONSchema {
    data class Obj(val properties: Map<String, JSONSchema>) : JSONSchema
    data class Arr(val items: JSONSchema) : JSONSchema
    data class Str(val allowed: List<String>? = null) : JSONSchema
    data object Num : JSONSchema
    data object Int : JSONSchema
    data object Bool : JSONSchema

    /** The schema as JSON, keys sorted. */
    val json: JsonObject get() = when (this) {
        is Obj -> sortedObject(
            "type" to JsonPrimitive("object"),
            "properties" to sortedObject(*properties.map { it.key to it.value.json }.toTypedArray()),
            "required" to JsonArray(properties.keys.sorted().map { JsonPrimitive(it) }),
            "additionalProperties" to JsonPrimitive(false),
        )
        is Arr -> sortedObject("type" to JsonPrimitive("array"), "items" to items.json)
        is Str -> if (allowed == null) sortedObject("type" to JsonPrimitive("string"))
        else sortedObject("type" to JsonPrimitive("string"), "enum" to JsonArray(allowed.map { JsonPrimitive(it) }))
        Num -> sortedObject("type" to JsonPrimitive("number"))
        Int -> sortedObject("type" to JsonPrimitive("integer"))
        Bool -> sortedObject("type" to JsonPrimitive("boolean"))
    }

    /** Whether a decoded JSON value matches this schema exactly. */
    fun validates(value: JsonElement?): Boolean = when (this) {
        is Obj -> value is JsonObject && value.keys == properties.keys && properties.all { (k, s) -> s.validates(value[k]) }
        is Arr -> value is JsonArray && value.all { items.validates(it) }
        is Str -> value is JsonPrimitive && value.isString && (allowed?.contains(value.content) ?: true)
        Num -> number(value) != null
        Int -> number(value)?.let { it % 1.0 == 0.0 } ?: false
        Bool -> value is JsonPrimitive && !value.isString && value.booleanOrNull != null
    }

    companion object {
        /** Reads back what [json] wrote. */
        fun fromJson(o: JsonObject): JSONSchema = when (o["type"]?.jsonPrimitive?.contentOrNull) {
            "object" -> Obj(o["properties"]!!.jsonObject.mapValues { fromJson(it.value.jsonObject) })
            "array" -> Arr(fromJson(o["items"]!!.jsonObject))
            "string" -> Str((o["enum"] as? JsonArray)?.map { it.jsonPrimitive.content })
            "number" -> Num
            "integer" -> Int
            "boolean" -> Bool
            else -> throw IllegalArgumentException("unknown schema")
        }

        internal fun number(value: JsonElement?): Double? =
            if (value is JsonPrimitive && !value.isString && value.booleanOrNull == null) value.doubleOrNull else null
    }
}

/** Swift's JSONSerialization with `.sortedKeys`: objects written in key order. */
fun sortedObject(vararg pairs: Pair<String, JsonElement>): JsonObject = JsonObject(sortedMapOf(*pairs))

/** Re-sorts every object inside [element] by key. */
fun sortedDeep(element: JsonElement): JsonElement = when (element) {
    is JsonObject -> JsonObject(element.mapValues { sortedDeep(it.value) }.toSortedMap())
    is JsonArray -> JsonArray(element.map { sortedDeep(it) })
    else -> element
}

/** Stores a schema as its JSON text, so a queued request keeps its schema. */
object JSONSchemaSerializer : KSerializer<JSONSchema> {
    override val descriptor = PrimitiveSerialDescriptor("JSONSchema", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: JSONSchema) = encoder.encodeString(value.json.toString())
    override fun deserialize(decoder: Decoder): JSONSchema = JSONSchema.fromJson(Json.parseToJsonElement(decoder.decodeString()).jsonObject)
}
