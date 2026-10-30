package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.data.BrewStyle
import app.rarecreatures.nextcup.kit.BrewMath
import app.rarecreatures.nextcup.kit.RecipeScaler
import app.rarecreatures.nextcup.kit.RecipeTiming
import app.rarecreatures.nextcup.scalable
import app.rarecreatures.nextcup.timer.TimerRun
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.Figure
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.StepperRow
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.launch
import java.util.UUID

/** One recipe: its numbers at the dose you choose, its steps, and Start brew. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipeDetailScreen(recipeId: String, back: () -> Unit, openTimer: () -> Unit) {
    val app = LocalContext.current.app
    val scope = rememberCoroutineScope()
    val recipe by remember { app.db.recipes().observe(recipeId) }.collectAsStateWithLifecycle(null)
    val steps by remember { app.db.recipes().observeSteps(recipeId) }.collectAsStateWithLifecycle(emptyList())
    val methods by remember { app.db.methods().observeAll() }.collectAsStateWithLifecycle(emptyList())
    val beans by remember { app.db.beans().observeAll() }.collectAsStateWithLifecycle(emptyList())
    val grinders by remember { app.db.gear().observeGrinders() }.collectAsStateWithLifecycle(emptyList())
    val units by app.prefs.units.collectAsStateWithLifecycle()
    var dose by rememberSaveable { mutableStateOf<Double?>(null) }
    var beanId by rememberSaveable { mutableStateOf<String?>(null) }
    var grinderId by rememberSaveable { mutableStateOf(app.prefs.lastGrinderId) }
    var grind by rememberSaveable { mutableStateOf("") }

    val r = recipe
    Column(Modifier.fillMaxSize()) {
        BackBar(r?.name ?: "", back)
        if (r == null) return@Column
        val method = methods.firstOrNull { it.id == r.methodId }
        val doseG = dose ?: r.doseG
        val scaled = runCatching { RecipeScaler.scale(r.scalable(steps), doseG) }.getOrNull()
        val factor = RecipeTiming.factor(method?.style == BrewStyle.POUR_OVER, r.doseG, doseG)
        val ordered = steps.sortedWith(compareBy({ it.order }, { it.startOffsetS }))
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            item {
                Kicker(method?.name ?: "Recipe")
                Text(r.name, style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                r.credit?.let { Text("Recipe credit: $it", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
            }
            item {
                Panel("How much coffee?") {
                    StepperRow(
                        "Dose", Fmt.weight(doseG, units),
                        onMinus = { dose = maxOf(1.0, doseG - 0.5) }, onPlus = { dose = minOf(200.0, doseG + 0.5) },
                    )
                    if (dose != null && dose != r.doseG) TextButton(onClick = { dose = null }) { Text("Reset to recipe ${Fmt.weight(r.doseG, units)}") }
                    val s = scaled?.recipe
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.lg)) {
                        Figure("Water", s?.let { Fmt.weight(it.waterG, units) } ?: "—", Modifier.weight(1f))
                        Figure("Ratio", BrewMath.ratioLabel(BrewMath.ratio(doseG, s?.waterG, if (r.includesIce) s?.iceG else null)) ?: "—", Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.lg)) {
                        Figure("Temperature", r.tempC?.let { Fmt.temperature(it, units) } ?: "—", Modifier.weight(1f))
                        Figure("Time", r.totalTimeS?.let { Fmt.clock(RecipeTiming.scaled(it, factor)) } ?: "—", Modifier.weight(1f))
                    }
                    if (r.includesIce && s?.iceG != null) Text("Includes ${Fmt.weight(s.iceG!!, units)} of ice in the server.", color = DS.colors.ink2)
                    s?.let { BrewMath.cupG(it.totalWaterG, doseG) }?.let {
                        Text("Makes about ${Fmt.weight(it, units)}", style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2)
                    }
                    scaled?.notes?.forEach { Text(it, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
                }
            }
            item {
                Panel("Brew steps") {
                    if (ordered.isEmpty()) EmptyState("No steps", "This recipe has no steps yet.")
                }
            }
            itemsIndexed(ordered, key = { _, s -> s.id }) { i, step ->
                val target = scaled?.recipe?.steps?.getOrNull(i)?.targetCumulativeWaterG
                val at = RecipeTiming.scaled(step.startOffsetS, factor)
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = DS.Space.sm).semantics(mergeDescendants = true) {
                        contentDescription = listOfNotNull(step.kind.label, "at ${Fmt.spokenTime(at)}", target?.let { "target ${Fmt.weight(it, units)}" }, step.instruction).joinToString(", ")
                    },
                    horizontalArrangement = Arrangement.spacedBy(DS.Space.md),
                ) {
                    Text(Fmt.clock(at), style = MaterialTheme.typography.titleMedium, color = DS.colors.accent, modifier = Modifier.width(56.dp))
                    Column(Modifier.weight(1f)) {
                        Text(step.kind.label + (target?.let { " to ${Fmt.weight(it, units)}" } ?: ""), style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                        if (step.instruction.isNotBlank()) Text(step.instruction, style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2)
                    }
                }
            }
            r.tuningNote?.let { note -> item { Panel("Tuning") { Text(note, color = DS.colors.ink) } } }
            item {
                Panel("Start brew") {
                    Picker(
                        "Beans", beans.filter { it.status == BeanStatus.IN_USE || it.id == beanId }.map { it.id to it.name },
                        beanId, "No beans",
                    ) { beanId = it }
                    Picker("Grinder", grinders.map { it.id to it.name }, grinderId, "None") { grinderId = it }
                    OutlinedTextField(
                        grind, { grind = it }, label = { Text("Grind setting") }, singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), modifier = Modifier.fillMaxWidth(),
                    )
                    Button(
                        enabled = ordered.isNotEmpty() && scaled != null,
                        onClick = {
                            scope.launch {
                                val run = TimerRun(
                                    UUID.randomUUID().toString(), r.id, doseG, beanId, beans.firstOrNull { it.id == beanId }?.name, grinderId, grind.trim(),
                                )
                                if (app.timer.prepare(run) != null) openTimer()
                            }
                        },
                        modifier = Modifier.fillMaxWidth().height(DS.Size.primary),
                    ) { Text("Start brew", style = MaterialTheme.typography.titleMedium) }
                }
            }
        }
    }
}

/** A labelled drop-down choice with a "none" entry. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Picker(label: String, options: List<Pair<String, String>>, selected: String?, none: String, onPick: (String?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = open, onExpandedChange = { open = it }) {
        OutlinedTextField(
            value = options.firstOrNull { it.first == selected }?.second ?: none, onValueChange = {}, readOnly = true,
            label = { Text(label) }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(open) },
            modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(text = { Text(none) }, onClick = { onPick(null); open = false })
            options.forEach { (id, name) -> DropdownMenuItem(text = { Text(name) }, onClick = { onPick(id); open = false }) }
        }
    }
}
