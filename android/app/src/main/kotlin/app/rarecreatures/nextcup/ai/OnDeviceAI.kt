package app.rarecreatures.nextcup.ai

import app.rarecreatures.nextcup.kit.AIError
import app.rarecreatures.nextcup.kit.AIRequestPayload
import app.rarecreatures.nextcup.kit.AIResult

/** Gemini Nano through ML Kit's GenAI Prompt API, where the phone has it. Nothing leaves the phone. */
object OnDeviceAI {
    const val MODEL_ID = "gemini-nano"

    @Volatile var isAvailable: Boolean = false
        private set

    suspend fun refresh() {
        isAvailable = false
    }

    suspend fun send(payload: AIRequestPayload): AIResult = throw AIError.Unavailable(null)
}
