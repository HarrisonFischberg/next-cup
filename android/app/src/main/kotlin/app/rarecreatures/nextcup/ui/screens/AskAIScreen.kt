package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.ai.AISuggestions
import app.rarecreatures.nextcup.ai.sends
import app.rarecreatures.nextcup.ai.title
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.AIFeature
import app.rarecreatures.nextcup.data.AIProvider
import app.rarecreatures.nextcup.data.AIRequestStatus
import app.rarecreatures.nextcup.kit.AIRequestPayload
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch

/**
 * "Ask AI about this brew". It shows the exact text that would be sent; nothing is queued until a model is
 * chosen, a key is in place, the disclosure for that provider is accepted, and Send is tapped.
 */
@Composable
fun AskAIScreen(brewId: String, back: () -> Unit, openSettings: () -> Unit) {
    val app = LocalContext.current.app
    val scope = rememberCoroutineScope()
    val prefs = app.aiPreferences
    val units by app.prefs.units.collectAsStateWithLifecycle()
    var payload by remember { mutableStateOf<AIRequestPayload?>(null) }
    var requestId by remember { mutableStateOf<String?>(null) }
    var refresh by remember { mutableIntStateOf(0) }
    LaunchedEffect(brewId) {
        val brew = app.db.brews().find(brewId) ?: return@LaunchedEffect
        val beans = app.db.brews().beans(brewId).mapNotNull { it.beanId?.let { id -> app.db.beans().find(id) } }
        payload = AISuggestions.payload(AISuggestions.Described(brew, brew.methodId?.let { app.db.methods().find(it) }, beans))
    }
    val request by remember(requestId) { requestId?.let { app.db.aiRequests().observe(it) } ?: flowOf(null) }.collectAsStateWithLifecycle(null)
    val suggestion by remember(request?.status) {
        kotlinx.coroutines.flow.flow { emit(request?.takeIf { it.status == AIRequestStatus.DONE }?.let { app.db.suggestions().find(it.id) }) }
    }.collectAsStateWithLifecycle(null)

    val feature = AIFeature.DIAGNOSIS
    val provider = remember(refresh) { prefs.provider(feature) }
    val model = remember(refresh) { prefs.modelID(feature) }
    val hasKey = provider?.let { app.secrets.hasKey(it) } ?: false
    val disclosed = provider?.let { prefs.hasAcceptedDisclosure(it) } ?: false

    Column(Modifier.fillMaxSize()) {
        BackBar("Ask AI about this brew", back)
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            item {
                Panel("What would be sent") {
                    Text(feature.sends, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    payload?.let { Text(it.userText, style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink) }
                }
            }
            item {
                when {
                    provider == null || model == null -> Panel("Choose a model") {
                        Text("Pick a provider and model for brew diagnosis in Settings → AI. Next Cup never picks a cloud model for you.", color = DS.colors.ink)
                        Button(onClick = openSettings) { Text("Open Settings") }
                    }
                    !hasKey -> Panel("Add your key") {
                        Text("Add your ${provider.title} API key in Settings → AI. It's stored encrypted on this phone only.", color = DS.colors.ink)
                        Button(onClick = openSettings) { Text("Open Settings") }
                    }
                    !disclosed -> Panel("Before the first request") {
                        Text("This sends the text above to ${provider.title} using your key, to model $model. ${provider.title} handles it under its own terms. Nothing is sent until you tap Send.", color = DS.colors.ink)
                        Button(onClick = { prefs.acceptDisclosure(provider); refresh++ }) { Text("I understand") }
                    }
                    else -> Panel(if (provider == AIProvider.ON_DEVICE) "On this phone" else "Ready") {
                        Text("${provider.title} · $model", color = DS.colors.ink2)
                        val working = request?.status == AIRequestStatus.QUEUED || request?.status == AIRequestStatus.SENDING
                        Button(
                            enabled = payload != null && !working,
                            onClick = { scope.launch { requestId = app.aiQueue.enqueue(payload!!, feature, provider, model, brewId).id } },
                            modifier = Modifier.fillMaxWidth().height(DS.Size.primary),
                        ) { Text("Send") }
                        if (working) {
                            CircularProgressIndicator()
                            Text(if (request?.status == AIRequestStatus.QUEUED) "Waiting for a connection. It will send when you're online." else "Asking…", color = DS.colors.ink2)
                            OutlinedButton(onClick = { scope.launch { request?.let { app.aiQueue.cancel(it) } } }) { Text("Cancel") }
                        }
                        request?.errorMessage?.takeIf { request?.status == AIRequestStatus.FAILED }?.let { Text(it, color = DS.colors.error) }
                    }
                }
            }
            suggestion?.let { s ->
                item {
                    Kicker("The answer")
                    Panel("Try this next time") {
                        Text(SuggestionText.headline(s, units), style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
                        Text(s.rationale, color = DS.colors.ink2)
                        Text("It waits on your next brew of these beans.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    }
                }
            }
            if (request?.status == AIRequestStatus.DONE && suggestion == null) item {
                Text("The answer wasn't a usable change, so it was discarded.", color = DS.colors.ink2)
            }
        }
    }
}
