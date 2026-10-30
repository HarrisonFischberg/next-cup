package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.beans.BeanError
import app.rarecreatures.nextcup.beans.BeanInsights
import app.rarecreatures.nextcup.beans.BeanMath
import app.rarecreatures.nextcup.beans.BeanService
import app.rarecreatures.nextcup.beans.CatalogService
import app.rarecreatures.nextcup.data.BeanStatus
import app.rarecreatures.nextcup.kit.Rating
import app.rarecreatures.nextcup.kit.StarterRecipes
import app.rarecreatures.nextcup.kit.StarterRoast
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.Panel
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

private data class BeanDetailData(
    val bean: app.rarecreatures.nextcup.data.Bean?,
    val roaster: app.rarecreatures.nextcup.data.Roaster?,
    val uses: List<app.rarecreatures.nextcup.data.BrewBean>,
    val brews: List<app.rarecreatures.nextcup.data.Brew>,
    val all: Triple<List<app.rarecreatures.nextcup.data.Bean>, List<app.rarecreatures.nextcup.data.BrewMethod>, List<app.rarecreatures.nextcup.data.Recipe>>,
    val grinders: List<app.rarecreatures.nextcup.data.Grinder>,
    val aliases: List<app.rarecreatures.nextcup.data.TaxonomyAlias>,
)

/** One bean: freshness, what's left, its best brew so far, what to brew it with, and its brews. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BeanDetailScreen(beanId: String, back: () -> Unit, edit: () -> Unit, openBrew: (String) -> Unit, openRecipe: (String) -> Unit) {
    val app = LocalContext.current.app
    val db = app.db
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val units by app.prefs.units.collectAsStateWithLifecycle()
    val data by remember {
        combine(
            db.beans().observeAll(), db.roasters().observeAll(), db.brews().observeAllBeans(), db.brews().observeAll(),
            combine(db.methods().observeAll(), db.recipes().observeAll(), db.gear().observeGrinders(), db.gear().observeAliases()) { m, r, g, a -> listOf(m, r, g, a) },
        ) { beans, roasters, uses, brews, rest ->
            val bean = beans.firstOrNull { it.id == beanId }
            @Suppress("UNCHECKED_CAST")
            BeanDetailData(
                bean, roasters.firstOrNull { it.id == bean?.roasterId }, uses, brews,
                Triple(beans, rest[0] as List<app.rarecreatures.nextcup.data.BrewMethod>, rest[1] as List<app.rarecreatures.nextcup.data.Recipe>),
                rest[2] as List<app.rarecreatures.nextcup.data.Grinder>, rest[3] as List<app.rarecreatures.nextcup.data.TaxonomyAlias>,
            )
        }
    }.collectAsStateWithLifecycle(null)
    var settingLeft by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    Scaffold(containerColor = DS.colors.bg, snackbarHost = { SnackbarHost(snackbar) }, topBar = {
        BackBar(data?.bean?.name ?: "", back) { TextButton(onClick = edit) { Text("Edit") } }
    }) { padding ->
        val d = data ?: return@Scaffold
        val bean = d.bean ?: return@Scaffold
        val myUses = d.uses.filter { it.beanId == bean.id }
        val service = BeanService(db)
        fun act(block: suspend () -> Unit) = scope.launch { try { block(); message = null } catch (e: BeanError) { message = e.message } }
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.md)) {
            item {
                Kicker(listOfNotNull(d.roaster?.name, bean.originCountry).joinToString("  ·  ").ifEmpty { "Bean" })
                Text(bean.name, style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink)
                val facts = listOfNotNull(bean.process, bean.varietal, bean.roastLevel?.label?.let { "$it roast" }, "Decaf".takeIf { bean.isDecaf })
                if (facts.isNotEmpty()) Text(facts.joinToString(" · "), color = DS.colors.ink2)
                if (bean.bagFlavorNotes.isNotEmpty()) Text(bean.bagFlavorNotes.joinToString(", "), color = DS.colors.accent)
            }
            message?.let { item { Text(it, color = DS.colors.error) } }
            item {
                Panel("Freshness") {
                    val state = BeanMath.freshness(bean)
                    Text(BeanMath.freshnessTitle(state) + (BeanMath.ageDays(bean)?.let { " · day $it since roast" } ?: ""), style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
                    bean.roastDate?.let { Text("Roasted ${Fmt.day(it)}", color = DS.colors.ink2) }
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                        if (bean.frozenOn == null) OutlinedButton(onClick = { act { service.freeze(bean) } }) { Text("Put in freezer") }
                        else if (bean.thawedOn == null) OutlinedButton(onClick = { act { service.thaw(bean) } }) { Text("Take out of freezer") }
                    }
                    if (bean.frozenOn != null) Text("Frozen days don't count toward its age.", style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                }
            }
            item {
                Panel("What's left") {
                    val left = BeanMath.remainingG(bean, myUses)
                    Text(left?.let { "${Fmt.weight(it, units)} of ${Fmt.weight(bean.bagWeightG!!, units)}" } ?: "Add the bag weight to track what's left.", style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
                    if (bean.bagWeightG != null) TextButton(onClick = { settingLeft = true }) { Text("Weighed it? Set what's left") }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
                        BeanStatus.entries.filter { it != bean.status }.forEach { s -> OutlinedButton(onClick = { act { service.setStatus(bean, s) } }) { Text("Mark ${s.label.lowercase()}") } }
                    }
                }
            }
            val best = BeanInsights.bestSoFar(bean, d.brews, d.uses, d.grinders)
            if (best.brewCount > 0) item {
                Panel("Best so far") {
                    val b = best.best
                    if (b == null) Text("Rate a brew of this bean to see its best settings.", color = DS.colors.ink2)
                    else {
                        Text("${Rating.text(b.ratingTenths ?: 0)} of 10 on ${Fmt.day(b.date.toEpochMilli())}", style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
                        Text(listOfNotNull(b.doseG?.let { Fmt.weight(it, units) }, b.waterG?.let { Fmt.weight(it, units) }, b.tempC?.let { Fmt.temperature(it, units) },
                            b.totalTimeS?.let { Fmt.clock(it) }, b.grindSetting?.let { "grind $it" + (b.grinder?.let { g -> " on $g" } ?: "") }).joinToString(" · "), color = DS.colors.ink2)
                    }
                    Text("${best.brewCount} brews, ${best.ratedCount} rated" + (best.averageTenths?.let { ", average ${Rating.text(it)}" } ?: ""), style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    best.grindHistory.take(6).forEach { g ->
                        Text("${g.grinder ?: "Grinder not noted"} · ${g.doseG?.let { Fmt.weight(it, units) } ?: "—"} · ${g.setting}: ${g.brews}× " + (g.averageTenths?.let { "avg ${Rating.text(it)}" } ?: "unrated"),
                            style = MaterialTheme.typography.bodySmall, color = DS.colors.ink)
                    }
                }
            }
            item {
                val rec = BeanInsights.recommend(bean, d.all.first, d.brews, d.uses, d.all.second, d.all.third, app.taxonomy, BeanInsights.aliases(d.aliases))
                Panel(if (rec.isDefault) "A place to start" else "Brew it like this") {
                    rec.items.forEach { r ->
                        Text(r.methodName + (r.recipeName?.let { " · $it" } ?: ""), style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                        Text(listOfNotNull(r.start.doseG?.let { Fmt.weight(it, units) }, r.start.waterG?.let { Fmt.weight(it, units) },
                            r.start.tempC?.let { Fmt.temperature(it, units) }, r.start.totalTimeS?.let { Fmt.clock(it) }, r.start.grindSetting).joinToString(" · "), color = DS.colors.ink2)
                        Text(r.explanation, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
                    }
                }
            }
            item {
                Panel("Starting recipes for this bean") {
                    StarterRecipes.recipes(StarterRoast.of(bean.roastLevel?.raw), bean.process).forEach { s ->
                        TextButton(onClick = { scope.launch { openRecipe(CatalogService(db).recipe(s, "bean.${bean.id}", bean.name).id) } }) { Text(s.name) }
                    }
                }
            }
            val myBrews = d.brews.filter { b -> myUses.any { it.brewId == b.id } }
            if (myBrews.isNotEmpty()) {
                item { Kicker("Brews") }
                items(myBrews, key = { it.id }) { b ->
                    Text(
                        Fmt.date(b.date) + (b.ratingTenths?.takeIf { it > 0 }?.let { " · ${Rating.text(it)}" } ?: "") + (b.verdict?.let { " · ${it.label}" } ?: ""),
                        color = DS.colors.ink, modifier = Modifier.fillMaxWidth().clickable { openBrew(b.id) }.padding(vertical = DS.Space.sm),
                    )
                }
            }
            item {
                TextButton(onClick = {
                    scope.launch {
                        db.beans().delete(bean)
                        val undo = snackbar.showSnackbar("${bean.name} deleted. Its brews keep its name.", "Undo", duration = SnackbarDuration.Short)
                        if (undo == SnackbarResult.ActionPerformed) {
                            db.beans().upsert(bean)
                            db.brews().upsertBeans(myUses)
                        } else back()
                    }
                }) { Text("Delete bean", color = DS.colors.error) }
            }
        }
        if (settingLeft) {
            var text by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { settingLeft = false },
                title = { Text("How much is left?") },
                text = {
                    OutlinedTextField(text, { text = it }, label = { Text("Grams left (${units.weightSymbol})") }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                },
                confirmButton = {
                    TextButton(onClick = {
                        val v = text.replace(',', '.').toDoubleOrNull()
                        settingLeft = false
                        if (v != null) act { service.setRemaining(bean, myUses, units.grams(v)) } else message = "Enter how much is left, from zero up."
                    }) { Text("Set") }
                },
                dismissButton = { TextButton(onClick = { settingLeft = false }) { Text("Cancel") } },
            )
        }
    }
}
