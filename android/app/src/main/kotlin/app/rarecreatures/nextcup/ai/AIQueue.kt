package app.rarecreatures.nextcup.ai

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import app.rarecreatures.nextcup.data.AIProvider
import app.rarecreatures.nextcup.data.AIRequest
import app.rarecreatures.nextcup.data.AIRequestStatus
import app.rarecreatures.nextcup.data.AIFeature
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.data.now
import app.rarecreatures.nextcup.kit.AIClient
import app.rarecreatures.nextcup.kit.AIError
import app.rarecreatures.nextcup.kit.AIProviderKind
import app.rarecreatures.nextcup.kit.AIRequestPayload
import app.rarecreatures.nextcup.kit.AIResult
import app.rarecreatures.nextcup.net.Http
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json

/**
 * Sends the AI requests the user queued with a tap. Offline requests stay `queued` and visible, and go when the
 * connection returns; each can be cancelled. Nothing is ever enqueued without [enqueue], so no AI traffic starts
 * by itself. A request that ends keeps neither its photo nor the text that was sent.
 */
class AIQueue(private val context: Context, private val db: NextCupDatabase, private val secrets: Secrets, val preferences: AIPreferences, private val scope: CoroutineScope) {
    private val json = Json { ignoreUnknownKeys = true }
    private val jobs = mutableMapOf<String, Job>()
    private val client = AIClient(
        Http, key = { kind -> secrets.key(if (kind == AIProviderKind.ANTHROPIC) AIProvider.ANTHROPIC else AIProvider.OPENAI) },
        disclosureAccepted = { kind -> preferences.hasAcceptedDisclosure(if (kind == AIProviderKind.ANTHROPIC) AIProvider.ANTHROPIC else AIProvider.OPENAI) },
    )

    init {
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        runCatching {
            connectivity.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) { scope.launch { processQueued() } }
            })
        }
    }

    /** Queues one request and starts it at once when online. */
    suspend fun enqueue(payload: AIRequestPayload, feature: AIFeature, provider: AIProvider, modelID: String, brewId: String? = null): AIRequest {
        val request = AIRequest(
            feature = feature, provider = provider, modelID = modelID, payloadJSON = json.encodeToString(AIRequestPayload.serializer(), payload),
            attachment = payload.imageJPEG, brewId = brewId,
        )
        db.aiRequests().insert(request)
        run(request)
        return request
    }

    suspend fun processQueued() = db.aiRequests().queued().forEach { run(it) }

    suspend fun cancel(request: AIRequest) {
        jobs.remove(request.id)?.cancel()
        val current = db.aiRequests().all().firstOrNull { it.id == request.id } ?: return
        if (current.status == AIRequestStatus.QUEUED || current.status == AIRequestStatus.SENDING) {
            db.aiRequests().upsert(current.copy(status = AIRequestStatus.CANCELLED, errorMessage = null, attachment = null, payloadJSON = "", updatedAt = now()))
        }
    }

    /** At launch: requests left queued or sending by an earlier run are cancelled, so they are never sent later. */
    suspend fun expireStale() {
        for (r in db.aiRequests().all()) if (r.status == AIRequestStatus.QUEUED || r.status == AIRequestStatus.SENDING) {
            db.aiRequests().upsert(r.copy(status = AIRequestStatus.CANCELLED, attachment = null, payloadJSON = "", updatedAt = now()))
        }
    }

    private fun run(request: AIRequest) {
        if (jobs[request.id]?.isActive == true) return
        jobs[request.id] = scope.launch {
            val payload = runCatching { json.decodeFromString(AIRequestPayload.serializer(), request.payloadJSON) }.getOrNull()?.copy(imageJPEG = request.attachment)
            if (payload == null) return@launch finish(request, Result.failure(AIError.InvalidResponse))
            val sending = request.copy(status = AIRequestStatus.SENDING, attempts = request.attempts + 1, errorMessage = null, updatedAt = now())
            db.aiRequests().upsert(sending)
            val outcome = runCatching {
                when (request.provider) {
                    AIProvider.ANTHROPIC -> client.send(payload, AIProviderKind.ANTHROPIC, request.modelID, preferences.effort)
                    AIProvider.OPENAI -> client.send(payload, AIProviderKind.OPENAI, request.modelID, preferences.effort)
                    else -> OnDeviceAI.send(payload)
                }
            }
            finish(sending, outcome)
        }
    }

    private suspend fun finish(request: AIRequest, outcome: Result<AIResult>) {
        jobs.remove(request.id)
        val current = db.aiRequests().all().firstOrNull { it.id == request.id } ?: return
        if (current.status == AIRequestStatus.CANCELLED) return
        val error = outcome.exceptionOrNull() as? AIError ?: outcome.exceptionOrNull()?.let { AIError.Unavailable(null) }
        val next = when {
            outcome.isSuccess -> current.copy(status = AIRequestStatus.DONE, resultJSON = outcome.getOrNull()!!.json, attachment = null, payloadJSON = "")
            error == AIError.Offline -> current.copy(status = AIRequestStatus.QUEUED, errorMessage = error.message)
            error == AIError.Cancelled -> current.copy(status = AIRequestStatus.CANCELLED, attachment = null, payloadJSON = "")
            else -> current.copy(status = AIRequestStatus.FAILED, errorMessage = error?.message, attachment = null, payloadJSON = "")
        }
        db.aiRequests().upsert(next.copy(updatedAt = now()))
        if (next.status == AIRequestStatus.DONE) AISuggestions.ingest(next, db)
    }

    /** Lists the models a key can use, which also checks the key. Sends only the key. */
    suspend fun models(provider: AIProvider): List<String> = client.models(if (provider == AIProvider.ANTHROPIC) AIProviderKind.ANTHROPIC else AIProviderKind.OPENAI)
}
