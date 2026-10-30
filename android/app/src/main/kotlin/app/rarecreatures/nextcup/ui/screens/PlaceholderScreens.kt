package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.rarecreatures.nextcup.ui.EmptyState
import app.rarecreatures.nextcup.ui.PageHeader
import app.rarecreatures.nextcup.ui.SettingsGear

@Composable
fun JournalScreen(openSettings: () -> Unit, startBrew: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize()) {
        item { PageHeader("Journal") { SettingsGear(openSettings) } }
        item { EmptyState("No brews yet", "Every cup you log shows up here, newest first.", "Brew a cup", startBrew) }
    }
}

@Composable
fun BeansScreen(openSettings: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize()) {
        item { PageHeader("Beans") { SettingsGear(openSettings) } }
        item { EmptyState("No beans yet", "Add a bag to track freshness, how much is left and your best brew of it.") }
    }
}

@Composable
fun ExploreScreen(openSettings: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize()) {
        item { PageHeader("Explore") { SettingsGear(openSettings) } }
        item { EmptyState("Explore", "Roasters, coffees and flavors to try next.") }
    }
}
