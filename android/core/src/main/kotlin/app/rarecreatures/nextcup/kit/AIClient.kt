package app.rarecreatures.nextcup.kit

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

enum class AIProviderKind(val raw: String) { ANTHROPIC("anthropic"), OPENAI("openAI") }

/** What one AI call carries. The image is kept out of the stored form; the queue keeps it as an attachment. */
@Serializable
data class AIRequestPayload(
    val system: String,
    val userText: String,
    val schemaName: String,
    val schema: JSONSchema,
    @Transient val imageJPEG: ByteArray? = null,
) {
    override fun equals(other: Any?) = other is AIRequestPayload && other.system == system && other.userText == userText &&
        other.schemaName == schemaName && other.schema == schema && (other.imageJPEG?.contentEquals(imageJPEG ?: ByteArray(0)) ?: (imageJPEG == null))
    override fun hashCode() = system.hashCode()
}

/** Output that already passed the payload's schema, as sorted JSON text. */
data class AIResult(val json: String)

sealed class AIError(message: String) : Exception(message) {
    data object DisclosureNotAccepted : AIError("Read and accept the AI disclosure first.")
    data object NoKey : AIError("Add an API key in Settings first.")
    data object KeyRejected : AIError("The provider rejected your key.")
    data object Offline : AIError("No connection. The request will wait.")
    data class Unavailable(val status: kotlin.Int?) : AIError("The provider is busy or unreachable. Try again later.")
    data class Http(val status: kotlin.Int) : AIError("The provider returned an error (HTTP $status).")
    data object InvalidResponse : AIError("The answer was not in the expected form, so it was discarded.")
    data object Cancelled : AIError("Cancelled.")
}

data class HttpRequest(
    val url: String,
    val method: String = "GET",
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
    val timeoutS: kotlin.Int = 30,
)

data class HTTPResult(val status: kotlin.Int, val body: ByteArray)

/** Thrown by a [Transport] when the device has no connection at all. */
class OfflineException : Exception("offline")

/** The only door to the network, so tests can prove when it is (not) opened. */
fun interface Transport {
    suspend fun send(request: HttpRequest): HTTPResult
}

/**
 * One AI call: refused before any I/O without disclosure and key, retried with backoff on 429 and 5xx
 * (max 3 attempts), and only ever returns schema-valid JSON.
 */
class AIClient(
    private val transport: Transport,
    private val key: (AIProviderKind) -> String?,
    private val disclosureAccepted: (AIProviderKind) -> Boolean,
    private val backoffMs: Long = 2_000,
    private val sleep: suspend (Long) -> Unit = { delay(it) },
) {
    companion object {
        const val MAX_ATTEMPTS = 3
        private val json = Json { ignoreUnknownKeys = true }

        internal fun request(payload: AIRequestPayload, provider: AIProviderKind, model: String, key: String, effort: String? = null): HttpRequest {
            val image = payload.imageJPEG?.let { java.util.Base64.getEncoder().encodeToString(it) }
            val headers: Map<String, String>
            val url: String
            val body: JsonObject
            when (provider) {
                AIProviderKind.ANTHROPIC -> {
                    url = "https://api.anthropic.com/v1/messages"
                    headers = mapOf("x-api-key" to key, "anthropic-version" to "2023-06-01")
                    val content = buildList {
                        if (image != null) add(
                            sortedObject(
                                "type" to JsonPrimitive("image"),
                                "source" to sortedObject("type" to JsonPrimitive("base64"), "media_type" to JsonPrimitive("image/jpeg"), "data" to JsonPrimitive(image)),
                            ),
                        )
                        add(sortedObject("type" to JsonPrimitive("text"), "text" to JsonPrimitive(payload.userText)))
                    }
                    // Structured output, not a forced tool: current Claude models refuse forced tool_choice.
                    val output = buildList<Pair<String, JsonElement>> {
                        add("format" to sortedObject("type" to JsonPrimitive("json_schema"), "schema" to payload.schema.json))
                        if (effort != null) add("effort" to JsonPrimitive(effort))
                    }
                    body = sortedObject(
                        "model" to JsonPrimitive(model), "max_tokens" to JsonPrimitive(16000), "system" to JsonPrimitive(payload.system),
                        "messages" to JsonArray(listOf(sortedObject("role" to JsonPrimitive("user"), "content" to JsonArray(content)))),
                        "output_config" to sortedObject(*output.toTypedArray()),
                    )
                }
                AIProviderKind.OPENAI -> {
                    url = "https://api.openai.com/v1/responses"
                    headers = mapOf("Authorization" to "Bearer $key")
                    val content = buildList {
                        add(sortedObject("type" to JsonPrimitive("input_text"), "text" to JsonPrimitive(payload.userText)))
                        if (image != null) add(sortedObject("type" to JsonPrimitive("input_image"), "image_url" to JsonPrimitive("data:image/jpeg;base64,$image")))
                    }
                    val fields = mutableListOf<Pair<String, JsonElement>>(
                        "model" to JsonPrimitive(model), "instructions" to JsonPrimitive(payload.system),
                        "input" to JsonArray(listOf(sortedObject("role" to JsonPrimitive("user"), "content" to JsonArray(content)))),
                        "text" to sortedObject(
                            "format" to sortedObject(
                                "type" to JsonPrimitive("json_schema"), "name" to JsonPrimitive(payload.schemaName),
                                "strict" to JsonPrimitive(true), "schema" to payload.schema.json,
                            ),
                        ),
                    )
                    if (effort != null) fields += "reasoning" to sortedObject("effort" to JsonPrimitive(effort))
                    body = sortedObject(*fields.toTypedArray())
                }
            }
            return HttpRequest(url, "POST", headers + ("content-type" to "application/json"), body.toString(), 120)
        }

        internal fun parse(data: ByteArray, payload: AIRequestPayload, provider: AIProviderKind): AIResult {
            val root = runCatching { json.parseToJsonElement(data.decodeToString()).jsonObject }.getOrNull() ?: throw AIError.InvalidResponse
            val text = runCatching {
                when (provider) {
                    AIProviderKind.ANTHROPIC -> (root["content"] as? JsonArray).orEmpty().map { it.jsonObject }
                        .firstOrNull { it["type"]?.jsonPrimitive?.contentOrNull == "text" }?.get("text")?.jsonPrimitive?.contentOrNull
                    AIProviderKind.OPENAI -> (root["output"] as? JsonArray).orEmpty().map { it.jsonObject }
                        .filter { it["type"]?.jsonPrimitive?.contentOrNull == "message" }
                        .flatMap { (it["content"] as? JsonArray).orEmpty().map { c -> c.jsonObject } }
                        .firstOrNull { it["type"]?.jsonPrimitive?.contentOrNull == "output_text" }?.get("text")?.jsonPrimitive?.contentOrNull
                }
            }.getOrNull()
            val answer = text?.let { runCatching { json.parseToJsonElement(it) }.getOrNull() }
            if (answer == null || !payload.schema.validates(answer)) throw AIError.InvalidResponse
            return AIResult(sortedDeep(answer).toString())
        }
    }

    /** [effort] is "low", "medium" or "high"; null leaves the provider's default. */
    suspend fun send(payload: AIRequestPayload, provider: AIProviderKind, model: String, effort: String? = null): AIResult {
        if (!disclosureAccepted(provider)) throw AIError.DisclosureNotAccepted
        val apiKey = key(provider)?.takeIf { it.isNotEmpty() } ?: throw AIError.NoKey
        val request = request(payload, provider, model, apiKey, effort)
        for (attempt in 1..MAX_ATTEMPTS) {
            val result = try {
                transport.send(request)
            } catch (e: CancellationException) {
                throw AIError.Cancelled
            } catch (e: OfflineException) {
                throw AIError.Offline
            } catch (e: Exception) {
                if (attempt == MAX_ATTEMPTS) throw AIError.Unavailable(null)
                pause(attempt)
                continue
            }
            when (result.status) {
                in 200..299 -> return parse(result.body, payload, provider)
                401 -> throw AIError.KeyRejected
                429, in 500..599 -> {
                    if (attempt == MAX_ATTEMPTS) throw AIError.Unavailable(result.status)
                    pause(attempt)
                }
                else -> throw AIError.Http(result.status)
            }
        }
        throw AIError.Unavailable(null)
    }

    /** The models this key can use. Also checks the key; sends only the key, never user data. */
    suspend fun models(provider: AIProviderKind): List<String> {
        val apiKey = key(provider)?.takeIf { it.isNotEmpty() } ?: throw AIError.NoKey
        val request = when (provider) {
            AIProviderKind.ANTHROPIC -> HttpRequest(
                "https://api.anthropic.com/v1/models?limit=1000",
                headers = mapOf("x-api-key" to apiKey, "anthropic-version" to "2023-06-01"),
            )
            AIProviderKind.OPENAI -> HttpRequest("https://api.openai.com/v1/models", headers = mapOf("Authorization" to "Bearer $apiKey"))
        }
        val result = try {
            transport.send(request)
        } catch (e: OfflineException) {
            throw AIError.Offline
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw AIError.Unavailable(null)
        }
        when (result.status) {
            in 200..299 -> {}
            401, 403 -> throw AIError.KeyRejected
            else -> throw AIError.Http(result.status)
        }
        val ids = runCatching {
            json.parseToJsonElement(result.body.decodeToString()).jsonObject["data"]!!.jsonArray
                .mapNotNull { it.jsonObject["id"]?.jsonPrimitive?.contentOrNull }
        }.getOrNull() ?: throw AIError.InvalidResponse
        if (provider != AIProviderKind.OPENAI) return ids
        // OpenAI lists every model it has; keep the chat ones that take a JSON schema.
        val skip = listOf("audio", "realtime", "tts", "transcribe", "image", "search", "embedding")
        return ids.filter { id ->
            (id.startsWith("gpt-") || (id.startsWith("o") && id.getOrNull(1)?.isDigit() == true)) && skip.none { id.contains(it) }
        }.sortedDescending()
    }

    private suspend fun pause(attempt: kotlin.Int) {
        try {
            sleep(backoffMs * (1L shl (attempt - 1)))
        } catch (e: CancellationException) {
            throw AIError.Cancelled
        }
    }
}
