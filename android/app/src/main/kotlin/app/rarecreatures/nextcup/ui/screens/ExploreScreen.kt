package app.rarecreatures.nextcup.ui.screens

import android.Manifest
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.beans.CatalogService
import app.rarecreatures.nextcup.beans.DeviceLocation
import app.rarecreatures.nextcup.beans.RoasterPlace
import app.rarecreatures.nextcup.beans.RoasterSearch
import app.rarecreatures.nextcup.beans.SearchArea
import app.rarecreatures.nextcup.data.Roaster
import app.rarecreatures.nextcup.data.RoastLevel
import app.rarecreatures.nextcup.data.rawOf
import app.rarecreatures.nextcup.kit.OfflineException
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.PageHeader
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.SettingsGear
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.launch

/** Explore: the starter roaster catalog and a way to find roasters nearby. */
@Composable
fun ExploreScreen(openSettings: () -> Unit, openRoaster: (String) -> Unit, discover: () -> Unit) {
    val app = LocalContext.current.app
    val catalog = app.catalog
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = DS.Space.xl)) {
        item { PageHeader("Explore") { SettingsGear(openSettings) } }
        item {
            Panel("Find roasters", Modifier.padding(horizontal = DS.Space.lg, vertical = DS.Space.xs)) {
                Text("Roasters near you or in a city you name.", color = DS.colors.ink2)
                Button(onClick = discover) { Text("Find roasters") }
            }
        }
        if (catalog == null) {
            item { EmptyState("Catalog unavailable", "The roaster catalog could not be read.") }
            return@LazyColumn
        }
        item {
            Column(Modifier.padding(horizontal = DS.Space.lg, vertical = DS.Space.sm)) {
                Kicker("Roasters to try")
                Text("Checked on ${catalog.checkedOn}. Line-ups change.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
        }
        items(catalog.roasters, key = { it.key }) { r ->
            Surface(color = DS.colors.paper, shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.xs).clickable { openRoaster(r.key) }) {
                Column(Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md)) {
                    Text(r.name, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                    Text("${r.place} · ${r.coffees.size} coffees", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                }
            }
        }
    }
}

/** One catalog roaster: its coffees, each addable to the library with Next Cup's starting recipes. */
@Composable
fun RoasterDetailScreen(key: String, back: () -> Unit, openBean: (String) -> Unit, openRecipe: (String) -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val scope = rememberCoroutineScope()
    val roaster = app.catalog?.roasters?.firstOrNull { it.key == key }
    Column(Modifier.fillMaxSize()) {
        BackBar(roaster?.name ?: "", back)
        if (roaster == null) { EmptyState("Roaster not found", "It is no longer in the catalog."); return@Column }
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            item {
                Kicker(roaster.place)
                Text(roaster.name, style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(roaster.website))) }) { Text("Visit their shop") }
                Text(app.catalog!!.note, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
            items(roaster.coffees, key = { it.key }) { c ->
                Panel {
                    Text(c.name, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                    val facts = listOfNotNull(c.originCountry, c.process, rawOf<RoastLevel>(c.roastLevel)?.label?.let { "$it roast" }, "Blend".takeIf { c.isBlend }, "Decaf".takeIf { c.isDecaf })
                    if (facts.isNotEmpty()) Text(facts.joinToString(" · "), color = DS.colors.ink2)
                    c.flavorNotes?.takeIf { it.isNotEmpty() }?.let { Text(it.joinToString(", "), color = DS.colors.accent) }
                    OutlinedButton(onClick = { scope.launch { openBean(CatalogService(app.db).addBean(c, roaster).first.id) } }) { Text("Add to my beans") }
                    Text("Next Cup's starting recipes", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    c.starterRecipes.forEach { s -> TextButton(onClick = { scope.launch { openRecipe(CatalogService(app.db).recipe(s, c.key, c.name).id) } }) { Text(s.name) } }
                }
            }
        }
    }
}

/** Finds roasters near the user or in a typed city. Location is asked for only on "Use my location". */
@Composable
fun RoasterDiscoveryScreen(back: () -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val scope = rememberCoroutineScope()
    var city by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var places by remember { mutableStateOf<List<RoasterPlace>?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    val saved by remember { app.db.roasters().observeAll() }.collectAsStateWithLifecycle(emptyList())

    fun run(area: SearchArea) = scope.launch {
        busy = true
        notice = null
        places = try {
            RoasterSearch.search(area)
        } catch (e: OfflineException) {
            notice = "No connection. Try again when you're online."; null
        } catch (e: Exception) {
            notice = e.message ?: "The search failed."; null
        }
        busy = false
    }
    val askLocation = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) { notice = "Location is off for Next Cup. Type a city to search, or allow location in system settings."; return@rememberLauncherForActivityResult }
        scope.launch {
            busy = true
            val here = DeviceLocation.current(context)
            busy = false
            if (here == null) notice = "Your location is not available right now. Type a city to search." else run(SearchArea.Near(here.latitude, here.longitude))
        }
    }

    Column(Modifier.fillMaxSize()) {
        BackBar("Find roasters", back)
        LazyColumn(contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
            item {
                OutlinedTextField(
                    city, { city = it }, label = { Text("City") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { if (city.isNotBlank()) run(SearchArea.City(city.trim())) }),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm), verticalAlignment = Alignment.CenterVertically) {
                    Button(enabled = city.isNotBlank() && !busy, onClick = { run(SearchArea.City(city.trim())) }) { Text("Search") }
                    OutlinedButton(enabled = !busy, onClick = { askLocation.launch(Manifest.permission.ACCESS_COARSE_LOCATION) }) { Text("Use my location") }
                    if (busy) CircularProgressIndicator()
                }
                Text("Your location is used for one search and never stored.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                notice?.let { Text(it, color = DS.colors.error) }
            }
            places?.let { list ->
                if (list.isEmpty()) item { EmptyState("No roasters found", "Try a nearby bigger city.") }
                items(list, key = { it.id }) { p ->
                    val isSaved = saved.any { it.name.equals(p.name, true) }
                    Panel {
                        Text(p.name, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                        p.city?.let { Text(it, color = DS.colors.ink2) }
                        Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                            OutlinedButton(enabled = !isSaved, onClick = {
                                scope.launch { app.db.roasters().upsert(Roaster(name = p.name, city = p.city, website = p.website, latitude = p.latitude, longitude = p.longitude, savedFromMap = true)) }
                            }) { Text(if (isSaved) "Saved" else "Save roaster") }
                            p.website?.let { url -> TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }) { Text("Website") } }
                        }
                    }
                }
                item { Text(RoasterSearch.ATTRIBUTION, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2) }
            }
        }
    }
}
