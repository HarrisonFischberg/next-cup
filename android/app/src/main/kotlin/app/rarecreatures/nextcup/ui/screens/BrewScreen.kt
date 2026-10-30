package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.PageHeader
import app.rarecreatures.nextcup.ui.SettingsGear
import app.rarecreatures.nextcup.ui.methodIcon
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.flow.combine

/** The Brew tab: the brew types the owner uses, each with how many styles it has. */
@Composable
fun BrewScreen(openSettings: () -> Unit) {
    val db = LocalContext.current.app.db
    val rows by remember {
        combine(db.methods().observeAll(), db.recipes().observeAll()) { methods, recipes ->
            methods.filter { !it.isHidden }.map { m -> m to recipes.count { it.methodId == m.id } }
        }
    }.collectAsStateWithLifecycle(null)

    LazyColumn(Modifier.fillMaxSize()) {
        item { PageHeader("Brew") { SettingsGear(openSettings) } }
        val list = rows
        when {
            list == null -> {}
            list.isEmpty() -> item { EmptyState("No brew types", "Built-in brew types appear here the first time the app opens.") }
            else -> items(list, key = { it.first.id }) { (method, count) ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = DS.colors.paper, contentColor = DS.colors.ink),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs)
                        .semantics(mergeDescendants = true) { contentDescription = "${method.name}, $count styles" },
                ) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = DS.Size.primary).padding(DS.Space.lg),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(DS.Space.md),
                    ) {
                        Icon(methodIcon(method.symbol), contentDescription = null, tint = DS.colors.accent, modifier = Modifier.size(28.dp))
                        Column(Modifier.weight(1f)) {
                            Text(method.name, style = MaterialTheme.typography.titleLarge)
                            Text(if (count == 1) "1 style" else "$count styles", style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2)
                        }
                    }
                }
            }
        }
    }
}
