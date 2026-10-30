package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.beans.BeanMath
import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.data.BrewBean
import app.rarecreatures.nextcup.data.Roaster
import app.rarecreatures.nextcup.kit.Rating
import app.rarecreatures.nextcup.kit.StockLevel
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.PageHeader
import app.rarecreatures.nextcup.ui.SettingsGear
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.flow.combine

enum class BeanSort(val raw: String, val title: String) { RECENT("recent", "Recently added"), NAME("name", "Name"), ROAST_DATE("roastDate", "Roast date"), GRADE("grade", "Highest rating") }

private data class BeanRow(val bean: Bean, val roaster: Roaster?, val uses: List<BrewBean>)

/** The bean library: search, a status filter and an order, all remembered. */
@Composable
fun BeansScreen(openSettings: () -> Unit, addBean: () -> Unit, openBean: (String) -> Unit) {
    val app = LocalContext.current.app
    val db = app.db
    val rows by remember {
        combine(db.beans().observeAll(), db.roasters().observeAll(), db.brews().observeAllBeans()) { beans, roasters, uses ->
            beans.map { b -> BeanRow(b, roasters.firstOrNull { it.id == b.roasterId }, uses.filter { it.beanId == b.id }) }
        }
    }.collectAsStateWithLifecycle(null)
    var query by rememberSaveable { mutableStateOf("") }
    var status by rememberSaveable { mutableStateOf(app.prefs.raw.getString("beans.status", null)) }
    var sort by rememberSaveable { mutableStateOf(app.prefs.raw.getString("beans.sort", BeanSort.RECENT.raw)!!) }
    var sortMenu by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = DS.colors.bg,
        floatingActionButton = { ExtendedFloatingActionButton(onClick = addBean, icon = { Icon(Icons.Filled.Add, null) }, text = { Text("Add beans") }) },
    ) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(bottom = 96.dp)) {
            item {
                PageHeader("Beans") {
                    Box {
                        IconButton(onClick = { sortMenu = true }) { Icon(Icons.AutoMirrored.Filled.Sort, "Sort", tint = DS.colors.ink) }
                        DropdownMenu(sortMenu, { sortMenu = false }) {
                            BeanSort.entries.forEach { s ->
                                DropdownMenuItem(text = { Text(s.title + if (s.raw == sort) "  ✓" else "") }, onClick = {
                                    sort = s.raw; app.prefs.raw.edit().putString("beans.sort", s.raw).apply(); sortMenu = false
                                })
                            }
                        }
                    }
                    SettingsGear(openSettings)
                }
            }
            val all = rows ?: return@LazyColumn
            if (all.isEmpty()) {
                item { EmptyState("No beans yet", "Add a bag to track freshness, how much is left and your best brew of it.", "Add beans", addBean) }
                return@LazyColumn
            }
            item {
                OutlinedTextField(
                    query, { query = it }, singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null) }, placeholder = { Text("Search beans, roasters, notes") },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs),
                )
            }
            item {
                LazyRow(contentPadding = PaddingValues(horizontal = DS.Space.lg), horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                    item { FilterChip(status == null, { status = null; app.prefs.raw.edit().remove("beans.status").apply() }, { Text("All") }) }
                    items(BeanStatus.entries) { s ->
                        FilterChip(status == s.raw, { status = s.raw; app.prefs.raw.edit().putString("beans.status", s.raw).apply() }, { Text(s.label) })
                    }
                }
            }
            val term = query.trim().lowercase()
            val kept = all.filter { r ->
                (status == null || r.bean.status.raw == status) && (term.isEmpty() || (listOfNotNull(
                    r.bean.name, r.roaster?.name, r.bean.originCountry, r.bean.region, r.bean.farm, r.bean.process, r.bean.varietal,
                ) + r.bean.bagFlavorNotes).any { it.lowercase().contains(term) })
            }
            val sorted = when (sort) {
                BeanSort.NAME.raw -> kept.sortedBy { it.bean.name.lowercase() }
                BeanSort.ROAST_DATE.raw -> kept.sortedWith(compareByDescending<BeanRow> { it.bean.roastDate ?: Long.MIN_VALUE }.thenBy { it.bean.name.lowercase() })
                BeanSort.GRADE.raw -> kept.sortedWith(compareByDescending<BeanRow> { it.bean.ratingTenths ?: 0 }.thenByDescending { it.bean.createdAt })
                else -> kept.sortedByDescending { it.bean.createdAt }
            }
            if (sorted.isEmpty()) item {
                EmptyState("No matches", "Nothing matches this search or filter.", "Clear filters") { query = ""; status = null; app.prefs.raw.edit().remove("beans.status").apply() }
            }
            items(sorted, key = { it.bean.id }) { r -> BeanRowView(r, app.prefs.units.value) { openBean(r.bean.id) } }
        }
    }
}

@Composable
private fun BeanRowView(r: BeanRow, units: app.rarecreatures.nextcup.kit.UnitPreferences, open: () -> Unit) {
    val b = r.bean
    Surface(
        color = DS.colors.paper, shape = MaterialTheme.shapes.medium,
        modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs).clickable(onClick = open),
    ) {
        Row(Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(b.name, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                val sub = listOfNotNull(r.roaster?.name, b.originCountry).joinToString("  ·  ")
                if (sub.isNotEmpty()) Text(sub, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                val facts = listOfNotNull(
                    BeanMath.freshnessTitle(BeanMath.freshness(b)).takeIf { b.roastDate != null }?.let { f -> BeanMath.ageDays(b)?.let { "$f · day $it" } ?: f },
                    BeanMath.remainingG(b, r.uses)?.let { "${Fmt.weight(it, units)} left" + if (BeanMath.stock(b, r.uses) == StockLevel.LOW) " (low)" else "" },
                    b.status.label.takeIf { b.status != BeanStatus.IN_USE },
                )
                if (facts.isNotEmpty()) Text(facts.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = DS.colors.accent)
            }
            b.ratingTenths?.takeIf { it > 0 }?.let { Text(Rating.text(it), style = MaterialTheme.typography.titleLarge, color = DS.colors.accent) }
        }
    }
}
