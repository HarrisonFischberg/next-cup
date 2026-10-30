package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.Grinder
import app.rarecreatures.nextcup.data.now
import app.rarecreatures.nextcup.kit.GrinderGuide
import app.rarecreatures.nextcup.kit.TemperatureUnit
import app.rarecreatures.nextcup.kit.WeightUnit
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.launch

/** First run only, three screens, every one skippable: your brewers and grinder, your units, then go. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OnboardingScreen(done: (brewFirst: Boolean) -> Unit) {
    val app = LocalContext.current.app
    val scope = rememberCoroutineScope()
    var step by rememberSaveable { mutableIntStateOf(1) }
    val methods by remember { app.db.methods().observeAll() }.collectAsStateWithLifecycle(emptyList())
    val units by app.prefs.units.collectAsStateWithLifecycle()
    var grinder by rememberSaveable { mutableStateOf<String?>(null) }
    val finish = { brew: Boolean -> app.prefs.raw.edit().putBoolean(DONE_KEY, true).apply(); done(brew) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DS.Space.xl), verticalArrangement = Arrangement.spacedBy(DS.Space.lg)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Kicker("Step $step of 3", Modifier.weight(1f))
            if (step < 3) TextButton(onClick = { finish(false) }) { Text("Skip") }
        }
        when (step) {
            1 -> {
                Text("What do you brew with?", style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                Text("Pick every brewer you use. The rest stay under More on the Brew tab.", color = DS.colors.ink2)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                    methods.forEach { m ->
                        FilterChip(!m.isHidden, { scope.launch { app.db.methods().upsert(m.copy(isHidden = !m.isHidden, updatedAt = now())) } }, { Text(m.name) })
                    }
                }
                Text("Your grinder", style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                Picker("Grinder", GrinderGuide.all.map { it.name to it.name }, grinder, "None or not listed") { grinder = it }
                Text("Your grinder's starting setting then shows on each recipe.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
            2 -> {
                Text("Your units", style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                    FilterChip(units.weight == WeightUnit.GRAMS, { app.prefs.setUnits(units.copy(weight = WeightUnit.GRAMS)) }, { Text("Grams (g)") })
                    FilterChip(units.weight == WeightUnit.OUNCES, { app.prefs.setUnits(units.copy(weight = WeightUnit.OUNCES)) }, { Text("Ounces (oz)") })
                }
                Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                    FilterChip(units.temperature == TemperatureUnit.CELSIUS, { app.prefs.setUnits(units.copy(temperature = TemperatureUnit.CELSIUS)) }, { Text("Celsius (°C)") })
                    FilterChip(units.temperature == TemperatureUnit.FAHRENHEIT, { app.prefs.setUnits(units.copy(temperature = TemperatureUnit.FAHRENHEIT)) }, { Text("Fahrenheit (°F)") })
                }
            }
            else -> {
                Text("You're set", style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                Text("Brew a cup with the guided timer, then rate it. Next Cup suggests one change for the next cup.", color = DS.colors.ink2)
                Text("To use Claude or ChatGPT for advice, add your own key later in Settings.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
        }
        Spacer(Modifier.height(DS.Space.lg))
        if (step < 3) Button(onClick = {
            if (step == 1) grinder?.let { name ->
                scope.launch {
                    val existing = app.db.gear().grinders().firstOrNull { it.name.equals(name, true) } ?: Grinder(name = name).also { app.db.gear().upsertGrinder(it) }
                    app.prefs.lastGrinderId = existing.id
                }
            }
            step++
        }, modifier = Modifier.fillMaxWidth().height(DS.Size.primary)) { Text("Continue") }
        else {
            Button(onClick = { finish(true) }, modifier = Modifier.fillMaxWidth().height(DS.Size.primary)) { Text("Brew a cup") }
            OutlinedButton(onClick = { finish(false) }, modifier = Modifier.fillMaxWidth()) { Text("Look around first") }
        }
    }
}

const val DONE_KEY = "onboarding.done"
