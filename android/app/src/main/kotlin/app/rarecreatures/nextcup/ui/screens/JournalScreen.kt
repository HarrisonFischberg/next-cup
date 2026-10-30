package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.Verdict
import app.rarecreatures.nextcup.kit.DraftStore
import app.rarecreatures.nextcup.kit.Rating
import app.rarecreatures.nextcup.kit.SavedDraft
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.PageHeader
import app.rarecreatures.nextcup.ui.SettingsGear
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private data class JournalRow(val brew: Brew, val method: String?, val beans: String, val recipe: String?)

/** Every brew, newest first, with unsaved brews on top. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun JournalScreen(
    openSettings: () -> Unit, startBrew: () -> Unit, logBrew: () -> Unit,
    openBrew: (String) -> Unit, brewAgain: (String) -> Unit, resume: (String) -> Unit,
) {
    val app = LocalContext.current.app
    val db = app.db
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val rows by remember {
        combine(db.brews().observeAll(), db.brews().observeAllBeans(), db.methods().observeAll(), db.recipes().observeAll(), db.beans().observeAll()) { brews, uses, methods, recipes, beans ->
            brews.map { b ->
                JournalRow(
                    b, methods.firstOrNull { it.id == b.methodId }?.name,
                    uses.filter { it.brewId == b.id }.joinToString(" + ") { u -> beans.firstOrNull { it.id == u.beanId }?.name ?: u.beanNameSnapshot },
                    recipes.firstOrNull { it.id == b.recipeId }?.name,
                )
            }
        }
    }.collectAsStateWithLifecycle(null)
    val drafts by remember { DraftStore.changes.map { DraftStore.all() }.flowOn(Dispatchers.IO) }.collectAsStateWithLifecycle(emptyList())
    var query by rememberSaveable { mutableStateOf("") }

    Scaffold(
        containerColor = DS.colors.bg,
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            ExtendedFloatingActionButton(onClick = logBrew, icon = { Icon(Icons.Filled.Add, null) }, text = { Text("Log a brew") })
        },
    ) { padding ->
        val list = rows
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(bottom = 96.dp)) {
            item { PageHeader("Journal") { SettingsGear(openSettings) } }
            if (drafts.isNotEmpty()) {
                item {
                    Column(Modifier.padding(horizontal = DS.Space.lg, vertical = DS.Space.sm)) {
                        Kicker("Unsaved Brews")
                        Text("Started or changed, but not saved yet. Tap one to finish it.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    }
                }
                items(drafts, key = { it.id }) { entry -> DraftRow(entry, list.orEmpty()) { resume(entry.store.name) } }
            }
            if (list == null) return@LazyColumn
            if (list.isEmpty()) {
                item { EmptyState("No brews yet", "Every cup you log shows up here, newest first.", "Brew a cup", startBrew) }
                return@LazyColumn
            }
            if (list.size > 15) item {
                OutlinedTextField(
                    query, { query = it }, singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null) }, placeholder = { Text("Search brews") },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.sm),
                )
            }
            val q = query.trim().lowercase()
            val shown = if (q.isEmpty()) list else list.filter { r -> listOfNotNull(r.method, r.beans, r.recipe, r.brew.notes).any { it.lowercase().contains(q) } }
            if (shown.isEmpty()) item { EmptyState("No matches", "No brew mentions \"$query\".") }
            items(shown, key = { it.brew.id }) { row ->
                BrewRow(
                    row, open = { openBrew(row.brew.id) }, again = { brewAgain(row.brew.id) },
                    delete = {
                        scope.launch {
                            val brew = row.brew
                            val uses = db.brews().beans(brew.id)
                            val suggestions = db.suggestions().all().filter { it.sourceBrewId == brew.id }
                            db.brews().delete(brew)
                            val result = snackbar.showSnackbar("Brew deleted", "Undo", duration = SnackbarDuration.Short)
                            if (result == SnackbarResult.ActionPerformed) {
                                db.brews().save(brew, uses)
                                db.suggestions().upsertAll(suggestions)
                            }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun verdictColor(v: Verdict?): Color = when (v) {
    Verdict.SOUR, Verdict.WEAK -> DS.colors.accent
    Verdict.BITTER, Verdict.STRONG -> DS.colors.error
    Verdict.BALANCED, Verdict.BRIGHT -> DS.colors.ok
    null -> DS.colors.line
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BrewRow(row: JournalRow, open: () -> Unit, again: () -> Unit, delete: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val b = row.brew
    Surface(
        color = DS.colors.paper, shape = MaterialTheme.shapes.medium,
        modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs)
            .combinedClickable(onClick = open, onLongClick = { menu = true })
            .semantics {
                customActions = listOf(
                    CustomAccessibilityAction("Brew again") { again(); true },
                    CustomAccessibilityAction("Delete") { delete(); true },
                )
            },
    ) {
        Row(Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            Box(Modifier.size(12.dp).padding(0.dp)) { Surface(color = verdictColor(b.verdict), shape = CircleShape, modifier = Modifier.fillMaxSize()) {} }
            Column(Modifier.weight(1f)) {
                Text(row.beans.ifEmpty { row.method ?: "Brew" }, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                val parts = listOfNotNull(row.method.takeIf { row.beans.isNotEmpty() }, Fmt.date(b.date), b.verdicts.joinToString(", ") { it.label }.ifEmpty { null })
                Text(parts.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2, maxLines = 2)
            }
            b.ratingTenths?.takeIf { it > 0 }?.let { Text(Rating.text(it), style = MaterialTheme.typography.titleLarge, color = DS.colors.accent) }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "Brew actions", tint = DS.colors.ink2) }
                DropdownMenu(menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Edit") }, onClick = { menu = false; open() })
                    DropdownMenuItem(text = { Text("Brew again") }, onClick = { menu = false; again() })
                    DropdownMenuItem(text = { Text("Delete") }, onClick = { menu = false; delete() })
                }
            }
        }
    }
}

@Composable
private fun DraftRow(entry: SavedDraft, rows: List<JournalRow>, open: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val title = when (val k = entry.kind) {
        SavedDraft.Kind.NewBrew -> entry.draft.beans?.firstOrNull()?.name ?: "New brew"
        is SavedDraft.Kind.Editing -> "Changes to " + (rows.firstOrNull { it.brew.id == k.brewID.toString().uppercase() }?.beans?.ifEmpty { null } ?: "a brew")
        is SavedDraft.Kind.Repeating -> "Brew again"
    }
    Surface(
        color = DS.colors.kraft, contentColor = DS.colors.onKraft, shape = MaterialTheme.shapes.medium,
        modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs).clickable(onClick = open),
    ) {
        Row(Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text("Changed ${Fmt.date(entry.changedAt.toEpochMilli())}", style = MaterialTheme.typography.bodySmall)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "Unsaved brew actions") }
                DropdownMenu(menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Finish it") }, onClick = { menu = false; open() })
                    DropdownMenuItem(text = { Text("Discard") }, onClick = { menu = false; entry.store.clear() })
                }
            }
        }
    }
}
