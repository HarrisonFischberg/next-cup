package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.kit.BrewMath
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.theme.DS

/** "Pick a style": the recipes for one brew type. */
@Composable
fun MethodStylesScreen(methodId: String, back: () -> Unit, openRecipe: (String) -> Unit) {
    val app = LocalContext.current.app
    val method by remember { app.db.methods().observe(methodId) }.collectAsStateWithLifecycle(null)
    val recipes by remember { app.db.recipes().observeForMethod(methodId) }.collectAsStateWithLifecycle(null)
    val units by app.prefs.units.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize()) {
        BackBar(method?.name ?: "", back)
        val list = recipes ?: return@Column
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
            item {
                Kicker("Pick a style")
                Text(
                    if (list.size == 1) "1 way to brew on the ${method?.name}" else "${list.size} ways to brew on the ${method?.name}",
                    style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2, modifier = Modifier.padding(bottom = DS.Space.sm),
                )
            }
            if (list.isEmpty()) item { EmptyState("No styles yet", "This brew type has no recipes yet.") }
            items(list, key = { it.id }) { recipe ->
                Surface(color = DS.colors.paper, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth().clickable { openRecipe(recipe.id) }) {
                    Row(Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.lg), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(recipe.name, style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
                            val parts = listOfNotNull(
                                Fmt.weight(recipe.doseG, units), BrewMath.ratioLabel(BrewMath.ratio(recipe.doseG, recipe.waterG, if (recipe.includesIce) recipe.iceG else null)),
                                recipe.tempC?.let { Fmt.temperature(it, units) }, recipe.totalTimeS?.let { Fmt.clock(it) },
                            )
                            Text(parts.joinToString(" · "), style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2)
                        }
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = DS.colors.ink2)
                    }
                }
            }
        }
    }
}
