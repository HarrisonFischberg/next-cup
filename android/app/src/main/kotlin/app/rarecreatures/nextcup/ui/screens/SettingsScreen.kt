package app.rarecreatures.nextcup.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.ai.AIPreferences
import app.rarecreatures.nextcup.ai.OnDeviceAI
import app.rarecreatures.nextcup.ai.title
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.AIFeature
import app.rarecreatures.nextcup.data.AIProvider
import app.rarecreatures.nextcup.data.BuiltInContent
import app.rarecreatures.nextcup.data.BuiltInSeeder
import app.rarecreatures.nextcup.data.DataArchive
import app.rarecreatures.nextcup.data.DataExchange
import app.rarecreatures.nextcup.kit.AIError
import app.rarecreatures.nextcup.kit.DraftStore
import app.rarecreatures.nextcup.kit.NextCupKit
import app.rarecreatures.nextcup.kit.TemperatureUnit
import app.rarecreatures.nextcup.kit.WeightUnit
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.theme.AppStyle
import app.rarecreatures.nextcup.ui.theme.AppearanceMode
import app.rarecreatures.nextcup.ui.theme.Colors
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun SettingsScreen(back: () -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val prefs = app.prefs
    val scope = rememberCoroutineScope()
    val style by prefs.style.collectAsStateWithLifecycle()
    val appearance by prefs.appearance.collectAsStateWithLifecycle()
    val units by prefs.units.collectAsStateWithLifecycle()
    var sound by remember { mutableStateOf(prefs.timerSound) }
    var message by remember { mutableStateOf<String?>(null) }
    var plan by remember { mutableStateOf<DataExchange.Plan?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var aiTick by remember { mutableIntStateOf(0) }
    val exchange = remember { DataExchange(app.db) }

    fun write(uri: android.net.Uri?, text: suspend () -> String) {
        uri ?: return
        scope.launch {
            message = runCatching {
                val body = text()
                withContext(Dispatchers.IO) { context.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(body.toByteArray()) } }
                "Exported."
            }.getOrElse { "The export could not be written: ${it.message}" }
        }
    }
    val stamp = java.time.LocalDate.now().toString()
    val exportJson = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { write(it) { exchange.exportJSON() } }
    val exportBrews = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { write(it) { exchange.brewsCSV() } }
    val exportBeans = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { write(it) { exchange.beansCSV() } }
    val importJson = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            try {
                val text = withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() } }
                plan = exchange.plan(DataArchive.decode(text))
            } catch (e: Exception) {
                message = e.message ?: "That file isn't a Next Cup export."
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        BackBar("Settings", back)
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            message?.let { item { Panel { Text(it, color = DS.colors.ink); TextButton(onClick = { message = null }) { Text("Dismiss") } } } }
            item {
                Kicker("Appearance", Modifier.padding(bottom = DS.Space.sm))
                Segments(AppearanceMode.entries.map { it.title }, AppearanceMode.entries.indexOf(appearance)) { prefs.setAppearance(AppearanceMode.entries[it]) }
            }
            item { Kicker("Look", Modifier.padding(top = DS.Space.sm)) }
            items(AppStyle.entries) { option -> LookRow(option, option == style) { prefs.setStyle(option) } }
            item {
                Panel("Units") {
                    Segments(listOf("Grams (g)", "Ounces (oz)"), units.weight.ordinal) { prefs.setUnits(units.copy(weight = WeightUnit.entries[it])) }
                    Segments(listOf("Celsius (°C)", "Fahrenheit (°F)"), units.temperature.ordinal) { prefs.setUnits(units.copy(temperature = TemperatureUnit.entries[it])) }
                }
            }
            item {
                Panel("Brew timer") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("A chime at each step", color = DS.colors.ink, modifier = Modifier.weight(1f))
                        Switch(sound, { sound = it; prefs.timerSound = it })
                    }
                }
            }
            item { AISettings(aiTick) { aiTick++ } }
            item {
                Panel("Your data") {
                    Text("Everything stays on this phone. Exports open in Next Cup on iPhone or Android, and the CSV files in any spreadsheet.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    OutlinedButton(onClick = { exportJson.launch("NextCup-$stamp.json") }) { Text("Export everything (JSON)") }
                    OutlinedButton(onClick = { exportBrews.launch("brews.csv") }) { Text("Export brews (CSV)") }
                    OutlinedButton(onClick = { exportBeans.launch("beans.csv") }) { Text("Export beans (CSV)") }
                    OutlinedButton(onClick = { importJson.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }) { Text("Import an export") }
                    TextButton(onClick = { confirmDelete = true }) { Text("Delete all data", color = DS.colors.error) }
                }
            }
            item {
                Panel("Privacy") {
                    Text(
                        "No account, no ads, no analytics. Brews, beans and photos stay on this phone. Network use only happens when you ask: " +
                            "barcode lookups go to Open Food Facts, roaster searches to OpenStreetMap Nominatim, and AI requests to the provider you chose with your own key, after you've read what is sent.",
                        style = MaterialTheme.typography.bodySmall, color = DS.colors.ink,
                    )
                }
            }
            item { Text("Next Cup ${NextCupKit.VERSION}", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
        }
    }

    plan?.let { p ->
        var replace by remember { mutableStateOf(false) }
        AlertDialog(
            onDismissRequest = { plan = null },
            title = { Text("Import") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                    Text("${p.newCount} new · ${p.sameCount} already here · ${p.conflicts.size} different from what's here")
                    if (p.conflicts.isNotEmpty()) Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(replace, { replace = it })
                        Text("Replace the ${p.conflicts.size} that differ with the imported versions")
                    }
                    Text("Nothing here is deleted.", style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    plan = null
                    scope.launch {
                        message = runCatching { exchange.apply(p, if (replace) p.conflicts.map { it.id }.toSet() else emptySet()) }
                            .fold({ "Imported: ${it.added} added, ${it.replaced} replaced." }, { "Nothing was imported: ${it.message}" })
                    }
                }) { Text("Import") }
            },
            dismissButton = { TextButton(onClick = { plan = null }) { Text("Cancel") } },
        )
    }

    // The one place a confirm dialog is right: delete-all cannot be undone.
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text("Delete all data?") },
        text = { Text("Every brew, bean, recipe change, photo, unsaved brew and saved AI key on this phone is removed. Export first if you want a copy. This can't be undone.") },
        confirmButton = {
            TextButton(onClick = {
                confirmDelete = false
                scope.launch {
                    app.timer.cancel()
                    exchange.deleteAll()
                    app.secrets.clearAll()
                    DraftStore.all().forEach { it.store.clear() }
                    prefs.raw.edit().clear().apply()
                    prefs.setStyle(AppStyle.DEFAULT)
                    prefs.setAppearance(AppearanceMode.SYSTEM)
                    prefs.setUnits(app.rarecreatures.nextcup.kit.UnitPreferences())
                    BuiltInSeeder(app.db, prefs.raw).seed(BuiltInContent.parse(app.asset("methods.json"), app.asset("recipes.json")))
                    message = "All data was deleted. The built-in brew types are back."
                }
            }) { Text("Delete everything", color = DS.colors.error) }
        },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
    )
}

@Composable
private fun Segments(labels: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        labels.forEachIndexed { i, label ->
            SegmentedButton(selected = i == selected, onClick = { onSelect(i) }, shape = SegmentedButtonDefaults.itemShape(i, labels.size)) { Text(label) }
        }
    }
}

/** Keys for the two cloud providers, the model each feature uses, and the on-device model's state. */
@Composable
private fun AISettings(tick: Int, changed: () -> Unit) {
    val app = LocalContext.current.app
    val scope = rememberCoroutineScope()
    val prefs = app.aiPreferences
    Panel("AI") {
        Text(
            if (OnDeviceAI.isAvailable) "Gemini Nano on this phone is ready. It's used when no cloud model is chosen, and nothing leaves the phone."
            else "This phone has no on-device model, so AI is off until you add a key for Anthropic or OpenAI.",
            style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2,
        )
        AIPreferences.keyed.forEach { provider ->
            var key by remember(tick) { mutableStateOf("") }
            var models by remember { mutableStateOf<List<String>>(emptyList()) }
            var status by remember { mutableStateOf<String?>(null) }
            val has = remember(tick) { app.secrets.hasKey(provider) }
            Text(provider.title, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
            OutlinedTextField(
                key, { key = it }, singleLine = true, label = { Text(if (has) "Key saved · paste a new one to replace" else "API key") },
                visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                Button(enabled = key.isNotBlank(), onClick = { app.secrets.setKey(provider, key); key = ""; changed() }) { Text("Save key") }
                if (has) OutlinedButton(onClick = {
                    scope.launch {
                        status = "Checking…"
                        status = try {
                            models = app.aiQueue.models(provider)
                            "Key works. ${models.size} models."
                        } catch (e: AIError) {
                            e.message
                        }
                    }
                }) { Text("Check key") }
                if (has) TextButton(onClick = { app.secrets.removeKey(provider); changed() }) { Text("Remove") }
            }
            status?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
            if (models.isNotEmpty()) {
                Picker("Model for brew diagnosis", models.map { it to it }, prefs.modelID(AIFeature.DIAGNOSIS).takeIf { prefs.provider(AIFeature.DIAGNOSIS) == provider }, "Not this provider") { m ->
                    if (m == null) prefs.clearChoice(AIFeature.DIAGNOSIS) else prefs.setChoice(provider, m, AIFeature.DIAGNOSIS)
                    changed()
                }
                Picker("Model for paper import", models.map { it to it }, prefs.modelID(AIFeature.PAPER_IMPORT).takeIf { prefs.provider(AIFeature.PAPER_IMPORT) == provider }, "Not this provider") { m ->
                    if (m == null) prefs.clearChoice(AIFeature.PAPER_IMPORT) else prefs.setChoice(provider, m, AIFeature.PAPER_IMPORT)
                    changed()
                }
            }
        }
        val chosen = remember(tick) { prefs.provider(AIFeature.DIAGNOSIS)?.let { p -> "${p.title} · ${prefs.modelID(AIFeature.DIAGNOSIS) ?: "no model"}" } ?: "Off" }
        Text("Brew diagnosis uses: $chosen", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
        Text("Keys are encrypted with this phone's keystore and never leave it except to the provider you chose.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
    }
}

@Composable
private fun LookRow(style: AppStyle, selected: Boolean, onSelect: () -> Unit) {
    val swatch = Colors.of(style.palette, DS.colors.isDark)
    Surface(
        color = DS.colors.paper, shape = MaterialTheme.shapes.medium,
        border = if (selected) BorderStroke(2.dp, DS.colors.accent) else null,
        modifier = Modifier.fillMaxWidth().selectable(selected = selected, onClick = onSelect, role = Role.RadioButton),
    ) {
        Row(
            Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.md),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy((-8).dp)) {
                for (c in listOf(swatch.bg, swatch.signal, swatch.accent)) {
                    Surface(color = c, shape = CircleShape, border = BorderStroke(1.dp, DS.colors.line), modifier = Modifier.size(28.dp)) { Box(Modifier) }
                }
            }
            Column(Modifier.weight(1f)) {
                Text(style.title, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                Text(style.mood, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
            RadioButton(selected = selected, onClick = null)
        }
    }
}
