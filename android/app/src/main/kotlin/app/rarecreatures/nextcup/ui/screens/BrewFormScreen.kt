package app.rarecreatures.nextcup.ui.screens

import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.MethodParameters
import app.rarecreatures.nextcup.brew.BrewFormViewModel
import app.rarecreatures.nextcup.brew.FormSource
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.data.BrewParameter
import app.rarecreatures.nextcup.data.BrewStyle
import app.rarecreatures.nextcup.data.Suggestion
import app.rarecreatures.nextcup.data.SuggestionState
import app.rarecreatures.nextcup.data.Verdict
import app.rarecreatures.nextcup.kit.Rating
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.StepperRow
import app.rarecreatures.nextcup.ui.theme.DS
import java.util.UUID

/** Log or edit one brew. Everything typed autosaves as a draft; Save writes the brew. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BrewFormScreen(source: FormSource, back: () -> Unit, vm: BrewFormViewModel = viewModel()) {
    val context = LocalContext.current
    LaunchedEffect(Unit) { vm.open(source) }
    val d by vm.draft.collectAsStateWithLifecycle()
    val units by vm.units.collectAsStateWithLifecycle()
    val methods by vm.methods.collectAsStateWithLifecycle(emptyList())
    val beans by vm.beans.collectAsStateWithLifecycle(emptyList())
    val grinders by vm.grinders.collectAsStateWithLifecycle(emptyList())
    val waters by vm.waterProfiles.collectAsStateWithLifecycle(emptyList())
    val saved by vm.savedBrewId.collectAsStateWithLifecycle()
    val editing by vm.editingId.collectAsStateWithLifecycle()
    val saving by vm.isSaving.collectAsStateWithLifecycle()
    val saveError by vm.saveError.collectAsStateWithLifecycle()
    val notice by vm.notice.collectAsStateWithLifecycle()
    val waiting by vm.waiting.collectAsStateWithLifecycle()
    val handled by vm.handledSuggestion.collectAsStateWithLifecycle()
    val suggestionError by vm.suggestionError.collectAsStateWithLifecycle()
    val made by vm.madeSuggestion.collectAsStateWithLifecycle()
    val dialInNote by vm.dialInNote.collectAsStateWithLifecycle()
    val newBest by vm.newBest.collectAsStateWithLifecycle()
    val photoError by vm.photoError.collectAsStateWithLifecycle()
    var addingGrinder by remember { mutableStateOf(false) }
    var addingWater by remember { mutableStateOf(false) }

    // Leaving or backgrounding writes the draft at once, so nothing typed is lost.
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_STOP) vm.flush() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    val leave = { vm.flush(); back() }
    BackHandler(onBack = leave)

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.attachPhoto(runCatching { context.contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull())
    }

    val method = methods.firstOrNull { it.id == d.methodID?.toString()?.uppercase() }
    val shown = MethodParameters.shown(method?.trackedParameters)
    val espresso = method?.style == BrewStyle.ESPRESSO

    Column(Modifier.fillMaxSize().imePadding()) {
        BackBar(if (editing != null) "Edit brew" else "Log a brew", leave)
        if (saved != null) {
            SavedPanel(made, dialInNote, newBest?.let { "New best for ${it.bean}: ${Rating.text(it.tenths)} of 10 (was ${Rating.text(it.previous)})." }, units, back)
            return@Column
        }
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            notice?.let { item { Panel { Text(it, color = DS.colors.ink); TextButton(onClick = { vm.notice.value = null }) { Text("Dismiss") } } } }
            (handled ?: waiting)?.let { s ->
                item { SuggestionCard(s, units, suggestionError, apply = { vm.applySuggestion(s) }, dismiss = { vm.dismissSuggestion(s) }, undo = { vm.undoSuggestion(s) }) }
            }
            item {
                Panel("Method") {
                    Picker("Method", methods.filter { !it.isHidden || it.id == method?.id }.map { it.id to it.name }, method?.id, "None") { id ->
                        vm.update { it.copy(methodID = id?.let(UUID::fromString)) }
                    }
                }
            }
            item {
                Panel("Beans") {
                    val list = d.beans.orEmpty()
                    if (list.isEmpty()) Text("No beans chosen. Add one bean, or several for a blend.", color = DS.colors.ink2)
                    val shares = vm.beanShares
                    list.forEachIndexed { i, b ->
                        if (list.size > 1) {
                            StepperRow(b.name, "%.0f%%".format(shares.getOrElse(i) { 0.0 }), { vm.stepShare(i, -5.0) }, { vm.stepShare(i, 5.0) })
                        } else Text(b.name, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                        TextButton(onClick = { vm.removeBean(i) }) { Text("Remove ${b.name}") }
                    }
                    if (list.size > 1) Text("A blend. Each bean's amount comes off its own bag.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    val addable = beans.filter { b -> b.status != BeanStatus.FINISHED && list.none { it.beanID?.toString()?.uppercase() == b.id } }
                    if (addable.isNotEmpty()) Picker("Add a bean", addable.map { it.id to it.name }, null, "Choose…") { id ->
                        addable.firstOrNull { it.id == id }?.let(vm::addBean)
                    }
                }
            }
            item {
                Panel("Amounts") {
                    StepperRow("Dose", d.doseG?.let { Fmt.weight(it, units) } ?: "Not set",
                        { vm.update { it.copy(doseG = vm.stepWeight(it.doseG, -1, 0.5, 0.05, BrewFormViewModel.DEFAULT_DOSE_G)) } },
                        { vm.update { it.copy(doseG = vm.stepWeight(it.doseG, 1, 0.5, 0.05, BrewFormViewModel.DEFAULT_DOSE_G)) } })
                    val waterLabel = if (espresso) "Output weight" else "Water"
                    StepperRow(waterLabel, d.waterG?.let { Fmt.weight(it, units) } ?: "Not set",
                        { vm.update { it.copy(waterG = vm.stepWeight(it.waterG, -1, if (espresso) 0.5 else 5.0, if (espresso) 0.05 else 0.25, if (espresso) 36.0 else BrewFormViewModel.DEFAULT_WATER_G)) } },
                        { vm.update { it.copy(waterG = vm.stepWeight(it.waterG, 1, if (espresso) 0.5 else 5.0, if (espresso) 0.05 else 0.25, if (espresso) 36.0 else BrewFormViewModel.DEFAULT_WATER_G)) } })
                    vm.ratioLabel?.let { Text("Ratio $it", style = MaterialTheme.typography.titleMedium, color = DS.colors.accent) }
                    d.targets?.let { t ->
                        val parts = listOfNotNull(t.doseG?.let { Fmt.weight(it, units) }, t.waterG?.let { Fmt.weight(it, units) }, t.tempC?.let { Fmt.temperature(it, units) }, t.totalTimeS?.let { Fmt.clock(it) })
                        if (parts.isNotEmpty()) Text("Recipe asked for " + parts.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    }
                }
            }
            if (BrewParameter.TEMPERATURE in shown || BrewParameter.TIME in shown) item {
                Panel("Heat and time") {
                    if (BrewParameter.TEMPERATURE in shown) StepperRow("Temperature", d.tempC?.let { Fmt.temperature(it, units) } ?: "Not set",
                        { vm.update { it.copy(tempC = vm.stepTemperature(it.tempC, -1)) } }, { vm.update { it.copy(tempC = vm.stepTemperature(it.tempC, 1)) } })
                    if (BrewParameter.TIME in shown) {
                        StepperRow("Time", d.totalTimeS?.let { Fmt.clock(it) } ?: "Not set",
                            { vm.update { it.copy(totalTimeS = it.totalTimeS?.let { t -> maxOf(0, t - 5) } ?: BrewFormViewModel.DEFAULT_TIME_S) } },
                            { vm.update { it.copy(totalTimeS = it.totalTimeS?.let { t -> t + 5 } ?: BrewFormViewModel.DEFAULT_TIME_S) } })
                        if (d.endedEarly) Text("Ended before the recipe's time.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    }
                }
            }
            if (BrewParameter.GRIND in shown) item {
                Panel("Grind") {
                    Picker("Grinder", grinders.map { it.id to it.name }, d.grinderID?.toString()?.uppercase(), "None") { id -> vm.update { it.copy(grinderID = id?.let(UUID::fromString)) } }
                    TextButton(onClick = { addingGrinder = true }) { Text("New grinder…") }
                    OutlinedTextField(
                        d.grindSetting, { v -> vm.update { it.copy(grindSetting = v) } }, label = { Text("Grind setting") }, singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next), modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            item {
                Panel("Water profile") {
                    Picker("Water", waters.map { it.id to it.name }, d.waterProfileID?.toString()?.uppercase(), "None") { id -> vm.update { it.copy(waterProfileID = id?.let(UUID::fromString)) } }
                    TextButton(onClick = { addingWater = true }) { Text("New water profile…") }
                }
            }
            if (BrewParameter.TDS in shown) item {
                Panel("TDS") {
                    StepperRow("TDS", d.tds?.let { "%.2f%%".format(it) } ?: "Not set",
                        { vm.update { it.copy(tds = it.tds?.let { t -> (Math.round((t - 0.05) / 0.05) * 0.05).takeIf { n -> n >= 0.05 } } ?: BrewFormViewModel.DEFAULT_TDS) } },
                        { vm.update { it.copy(tds = it.tds?.let { t -> Math.round((t + 0.05) / 0.05) * 0.05 } ?: BrewFormViewModel.DEFAULT_TDS) } })
                    vm.extractionLabel?.let { Text("Extraction $it", color = DS.colors.accent) }
                }
            }
            item {
                Panel("How it tasted") {
                    Text("Pick all that apply.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    val picked = Verdict.picked(d.verdict)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                        Verdict.entries.forEach { v -> FilterChip(selected = v in picked, onClick = { vm.toggleVerdict(v) }, label = { Text(v.label) }) }
                    }
                    if (picked.isEmpty() && editing == null) Text("Not tasted yet? Save without it and rate it while you sip.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                }
            }
            if (BrewParameter.RATING in shown) item {
                Panel("Rating") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(if (d.ratingTenths == 0) "Not rated" else "${Rating.text(d.ratingTenths)} / 10", style = MaterialTheme.typography.titleLarge, color = DS.colors.ink, modifier = Modifier.weight(1f))
                        if (d.ratingTenths != 0) TextButton(onClick = { vm.update { it.copy(ratingTenths = 0) } }) { Text("Clear") }
                    }
                    Slider(
                        value = d.ratingTenths.toFloat(), onValueChange = { v -> vm.update { it.copy(ratingTenths = v.toInt()) } }, valueRange = 0f..100f, steps = 99,
                        modifier = Modifier.semantics { contentDescription = "Rating"; stateDescription = if (d.ratingTenths == 0) "Not rated" else "${Rating.text(d.ratingTenths)} of 10" },
                    )
                }
            }
            if (BrewParameter.NOTES in shown) item {
                Panel("Notes") {
                    OutlinedTextField(
                        d.notes, { v -> vm.update { it.copy(notes = v) } }, modifier = Modifier.fillMaxWidth().height(120.dp),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences), placeholder = { Text("Sweet, a little thin…") },
                    )
                }
            }
            if (BrewParameter.PHOTO in shown) item {
                Panel("Photo") {
                    val photo = d.photo
                    val bitmap = remember(photo) { photo?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() } }
                    if (bitmap != null) {
                        Image(bitmap, "Photo of this brew", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().height(200.dp))
                        TextButton(onClick = { vm.update { it.copy(photo = null) } }) { Text("Remove photo") }
                    } else OutlinedButton(onClick = { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text("Add a photo") }
                    photoError?.let { Text(it, color = DS.colors.error) }
                    Text("Location and camera details are removed from photos before they are kept.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                }
            }
            saveError?.let { item { Text(it, color = DS.colors.error) } }
            item {
                Button(onClick = { vm.save() }, enabled = d.canSave && !saving, modifier = Modifier.fillMaxWidth().height(DS.Size.primary)) {
                    Text(if (saving) "Saving…" else "Save brew", style = MaterialTheme.typography.titleMedium)
                }
                if (!d.canSave) Text("A brew needs a dose and water.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
        }
    }
    if (addingGrinder) NameDialog("New grinder", "Its name is kept so grind settings can be compared by grinder.", onDone = { name -> vm.addGrinder(name); addingGrinder = false }) { addingGrinder = false }
    if (addingWater) NameDialog("New water profile", "Its name is kept so brews can be compared by water.", onDone = { name -> vm.addWaterProfile(name, ""); addingWater = false }) { addingWater = false }
}

@Composable
private fun SavedPanel(made: Suggestion?, note: String?, best: String?, units: app.rarecreatures.nextcup.kit.UnitPreferences, done: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
        Text("Saved in your journal.", style = MaterialTheme.typography.headlineSmall, color = DS.colors.ink)
        best?.let { Panel("New best") { Text(it, color = DS.colors.ink) } }
        if (made != null) Panel("Try this next time") {
            Text(SuggestionText.headline(made, units), style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
            Text(made.rationale, color = DS.colors.ink2)
            Text("It waits on your next brew of these beans.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
        } else note?.let { Panel("Dial-in") { Text(it, color = DS.colors.ink) } }
        Button(onClick = done, modifier = Modifier.fillMaxWidth().height(DS.Size.primary)) { Text("Done") }
    }
}

@Composable
fun SuggestionCard(s: Suggestion, units: app.rarecreatures.nextcup.kit.UnitPreferences, error: String?, apply: () -> Unit, dismiss: () -> Unit, undo: () -> Unit) {
    Panel("Try this next time") {
        Text(SuggestionText.headline(s, units), style = MaterialTheme.typography.titleLarge, color = DS.colors.ink,
            modifier = Modifier.semantics { contentDescription = SuggestionText.spoken(s, units) })
        Text(s.rationale, style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2)
        if (s.state == SuggestionState.PROPOSED) Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
            Button(onClick = apply) { Text("Apply") }
            OutlinedButton(onClick = dismiss) { Text("Dismiss") }
        } else Row(verticalAlignment = Alignment.CenterVertically) {
            Text(SuggestionText.state(s.state), color = DS.colors.accent, modifier = Modifier.weight(1f))
            TextButton(onClick = undo) { Text("Undo") }
        }
        error?.let { Text(it, color = DS.colors.error) }
    }
}

@Composable
fun NameDialog(title: String, message: String, onDone: (String) -> Unit, onCancel: () -> Unit) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                Text(message)
                OutlinedTextField(name, { name = it }, singleLine = true, label = { Text("Name") },
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done))
            }
        },
        confirmButton = { TextButton(onClick = { onDone(name) }, enabled = name.isNotBlank()) { Text("Add") } },
        dismissButton = { TextButton(onClick = onCancel) { Text("Cancel") } },
    )
}

/** Display strings for a suggestion, in the user's units. Stored values stay canonical. */
object SuggestionText {
    private fun title(p: BrewParameter) = Fmt.parameter(p)

    fun display(text: String, p: BrewParameter, units: app.rarecreatures.nextcup.kit.UnitPreferences): String {
        val clean = text.trim()
        if (clean.isEmpty()) return "not set"
        return when (p) {
            BrewParameter.WATER, BrewParameter.YIELD -> clean.toDoubleOrNull()?.let { Fmt.weight(it, units) } ?: clean
            BrewParameter.TEMPERATURE -> clean.toDoubleOrNull()?.let { Fmt.temperature(it, units) } ?: clean
            BrewParameter.TIME -> clean.toDoubleOrNull()?.let { Fmt.clock(it.toInt()) } ?: clean
            else -> clean
        }
    }

    fun headline(s: Suggestion, u: app.rarecreatures.nextcup.kit.UnitPreferences) = "${title(s.field)}: ${display(s.fromValue, s.field, u)} → ${display(s.toValue, s.field, u)}"
    fun spoken(s: Suggestion, u: app.rarecreatures.nextcup.kit.UnitPreferences) = "${title(s.field)} from ${display(s.fromValue, s.field, u)} to ${display(s.toValue, s.field, u)}"
    fun state(state: SuggestionState) = when (state) {
        SuggestionState.PROPOSED -> "Waiting"
        SuggestionState.ACCEPTED -> "Applied"
        SuggestionState.EDITED -> "Applied, edited"
        SuggestionState.DISMISSED -> "Dismissed"
    }
}
