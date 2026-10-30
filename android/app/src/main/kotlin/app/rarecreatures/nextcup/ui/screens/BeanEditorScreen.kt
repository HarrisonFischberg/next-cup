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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.beans.BagScanner
import app.rarecreatures.nextcup.beans.BeanError
import app.rarecreatures.nextcup.beans.BeanFields
import app.rarecreatures.nextcup.beans.BeanService
import app.rarecreatures.nextcup.beans.RoasterPlace
import app.rarecreatures.nextcup.beans.RoasterSearch
import app.rarecreatures.nextcup.beans.ScanMode
import app.rarecreatures.nextcup.beans.ScanResult
import app.rarecreatures.nextcup.beans.SearchArea
import app.rarecreatures.nextcup.beans.readText
import app.rarecreatures.nextcup.brew.PhotoSanitizer
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.data.RoastLevel
import app.rarecreatures.nextcup.kit.BarcodeLookup
import app.rarecreatures.nextcup.kit.LabelEvidence
import app.rarecreatures.nextcup.net.Http
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/** Add or edit a bean, by hand or from the bag: barcode → Open Food Facts → roaster match, or the label's text. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun BeanEditorScreen(beanId: String?, back: () -> Unit, saved: (String) -> Unit) {
    val app = LocalContext.current.app
    val db = app.db
    val scope = rememberCoroutineScope()
    val units by app.prefs.units.collectAsStateWithLifecycle()
    var fields by remember { mutableStateOf(BeanFields()) }
    var loaded by remember { mutableStateOf(beanId == null) }
    var error by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf<String?>(null) }
    var scanning by remember { mutableStateOf<ScanMode?>(null) }
    var pickDate by remember { mutableStateOf(false) }
    var weightText by remember { mutableStateOf("") }
    var matches by remember { mutableStateOf<List<RoasterPlace>?>(null) }

    LaunchedEffect(beanId) {
        if (beanId != null) {
            val bean = db.beans().find(beanId)
            if (bean != null) {
                fields = BeanFields.of(bean, bean.roasterId?.let { db.roasters().find(it) })
                weightText = bean.bagWeightG?.let { Fmt.weight(it, units, withSymbol = false) } ?: ""
            }
            loaded = true
        }
    }
    BackHandler(onBack = back)

    fun applyLabel(photo: ByteArray, lines: List<String>) {
        val before = fields
        var next = fields.copy(photo = photo)
        LabelEvidence.roastDate(lines)?.let { iso -> next = next.copy(roastDate = LocalDate.parse(iso).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()) }
        LabelEvidence.bagWeightGrams(lines)?.let { g -> next = next.copy(bagWeightG = g); weightText = Fmt.weight(g, units, withSymbol = false) }
        fields = next
        val filled = listOf(before.roastDate != next.roastDate, before.bagWeightG != next.bagWeightG).count { it }
        status = if (filled == 0) "Photo kept. The label didn't plainly state a roast date or weight, so nothing else was filled."
        else "Filled $filled ${if (filled == 1) "field" else "fields"} from the label. Check them."
    }

    fun lookUp(code: String) = scope.launch {
        status = "Looking up $code on Open Food Facts…"
        when (val outcome = BarcodeLookup.lookUp(code) { url -> Http.get(url, BarcodeLookup.USER_AGENT) }) {
            is BarcodeLookup.Outcome.Found -> {
                val p = outcome.product
                fields = fields.copy(name = p.name.ifEmpty { fields.name }, roasterName = p.brand ?: fields.roasterName)
                status = "Found ${listOfNotNull(p.name.ifEmpty { null }, p.brand).joinToString(" by ")}."
                p.brand?.let { brand ->
                    matches = runCatching { RoasterSearch.search(SearchArea.Named(brand)) }.getOrNull()?.takeIf { it.isNotEmpty() }
                }
            }
            is BarcodeLookup.Outcome.Failed -> status = when (outcome.failure) {
                BarcodeLookup.Failure.NOT_FOUND -> "That barcode isn't in Open Food Facts. Type the details instead."
                BarcodeLookup.Failure.OFFLINE -> "No connection, so the barcode couldn't be looked up."
                BarcodeLookup.Failure.INVALID_CODE -> "That isn't a retail barcode."
                BarcodeLookup.Failure.UNREADABLE -> "Open Food Facts didn't answer in a readable way. Try again later."
            }
        }
    }

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val clean = withContext(Dispatchers.IO) { runCatching { app.contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()?.let { PhotoSanitizer.sanitized(it) } }
            if (clean == null) status = "That file could not be read as a photo." else applyLabel(clean, readText(clean))
        }
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        BackBar(if (beanId == null) "Add beans" else "Edit bean", back)
        if (!loaded) return@Column
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            item {
                Panel("From the bag") {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                        OutlinedButton(onClick = { scanning = ScanMode.BARCODE }) { Text("Scan barcode") }
                        OutlinedButton(onClick = { scanning = ScanMode.LABEL }) { Text("Read the label") }
                        OutlinedButton(onClick = { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text("Choose a photo") }
                    }
                    status?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
                    fields.photo?.let { photo ->
                        val bitmap = remember(photo) { BitmapFactory.decodeByteArray(photo, 0, photo.size)?.asImageBitmap() }
                        if (bitmap != null) Image(bitmap, "Photo of the bag", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().height(180.dp))
                        TextButton(onClick = { fields = fields.copy(photo = null) }) { Text("Remove photo") }
                    }
                    Text("Barcodes are looked up on Open Food Facts. Label text is read on this phone.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                }
            }
            item {
                Panel("Coffee") {
                    Field("Name", fields.name, KeyboardCapitalization.Words) { fields = fields.copy(name = it) }
                    Field("Roaster", fields.roasterName, KeyboardCapitalization.Words) { fields = fields.copy(roasterName = it) }
                    Field("Roaster city", fields.roasterCity, KeyboardCapitalization.Words) { fields = fields.copy(roasterCity = it) }
                    Field("Origin country", fields.originCountry, KeyboardCapitalization.Words) { fields = fields.copy(originCountry = it) }
                    Field("Region", fields.region, KeyboardCapitalization.Words) { fields = fields.copy(region = it) }
                    Field("Farm or producer", fields.farm, KeyboardCapitalization.Words) { fields = fields.copy(farm = it) }
                    Field("Process", fields.process, KeyboardCapitalization.None) { fields = fields.copy(process = it) }
                    Field("Varietal", fields.varietal, KeyboardCapitalization.Words) { fields = fields.copy(varietal = it) }
                    Field("Flavor notes (comma separated)", fields.flavorNotes, KeyboardCapitalization.None) { fields = fields.copy(flavorNotes = it) }
                }
            }
            item {
                Panel("Roast") {
                    Picker("Roast level", RoastLevel.entries.map { it.raw to it.label }, fields.roastLevel?.raw, "Not listed") { raw ->
                        fields = fields.copy(roastLevel = RoastLevel.entries.firstOrNull { it.raw == raw })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Roasted " + (fields.roastDate?.let { Fmt.day(it) } ?: "— not set"), color = DS.colors.ink, modifier = Modifier.weight(1f))
                        TextButton(onClick = { pickDate = true }) { Text(if (fields.roastDate == null) "Set" else "Change") }
                        if (fields.roastDate != null) TextButton(onClick = { fields = fields.copy(roastDate = null) }) { Text("Clear") }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Decaf", color = DS.colors.ink, modifier = Modifier.weight(1f))
                        Switch(fields.isDecaf, { fields = fields.copy(isDecaf = it) })
                    }
                }
            }
            item {
                Panel("Bag") {
                    OutlinedTextField(
                        weightText, { t -> weightText = t; fields = fields.copy(bagWeightG = t.replace(',', '.').toDoubleOrNull()?.let { units.grams(it) }) },
                        label = { Text("Bag weight (${units.weightSymbol})") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Done),
                    )
                    Picker("Status", BeanStatus.entries.map { it.raw to it.label }, fields.status.raw, BeanStatus.IN_USE.label) { raw ->
                        fields = fields.copy(status = BeanStatus.entries.firstOrNull { it.raw == raw } ?: BeanStatus.IN_USE)
                    }
                }
            }
            error?.let { item { Text(it, color = DS.colors.error) } }
            item {
                Button(
                    onClick = {
                        scope.launch {
                            try {
                                val bean = BeanService(db).save(fields, beanId?.let { db.beans().find(it) })
                                saved(bean.id)
                            } catch (e: BeanError) {
                                error = e.message
                            } catch (e: Exception) {
                                error = "The change could not be saved: ${e.message}"
                            }
                        }
                    },
                    enabled = fields.name.isNotBlank(), modifier = Modifier.fillMaxWidth().height(DS.Size.primary),
                ) { Text("Save bean") }
            }
        }
    }

    if (pickDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = fields.roastDate?.let { java.time.Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() },
        )
        DatePickerDialog(
            onDismissRequest = { pickDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { utc ->
                        val day = java.time.Instant.ofEpochMilli(utc).atZone(ZoneOffset.UTC).toLocalDate()
                        fields = fields.copy(roastDate = day.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli())
                    }
                    pickDate = false
                }) { Text("Done") }
            },
            dismissButton = { TextButton(onClick = { pickDate = false }) { Text("Cancel") } },
        ) { DatePicker(state) }
    }

    scanning?.let { mode ->
        Dialog(onDismissRequest = { scanning = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            BagScanner(mode, onResult = { result ->
                scanning = null
                when (result) {
                    is ScanResult.Code -> lookUp(result.digits)
                    is ScanResult.Label -> applyLabel(result.photo, result.lines)
                }
            }, onCancel = { scanning = null })
        }
    }

    matches?.let { places ->
        AlertDialog(
            onDismissRequest = { matches = null },
            title = { Text("Which roaster is it?") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                    places.take(6).forEach { p ->
                        TextButton(onClick = {
                            fields = fields.copy(roasterName = p.name, roasterCity = p.city ?: fields.roasterCity, roasterWebsite = p.website ?: fields.roasterWebsite)
                            matches = null
                        }) { Text(listOfNotNull(p.name, p.city).joinToString(", ")) }
                    }
                    Text(RoasterSearch.ATTRIBUTION, style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { TextButton(onClick = { matches = null }) { Text("None of these") } },
        )
    }
}

@Composable
private fun Field(label: String, value: String, caps: KeyboardCapitalization, onChange: (String) -> Unit) {
    OutlinedTextField(
        value, onChange, label = { Text(label) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
        keyboardOptions = KeyboardOptions(capitalization = caps, imeAction = ImeAction.Next),
    )
}
