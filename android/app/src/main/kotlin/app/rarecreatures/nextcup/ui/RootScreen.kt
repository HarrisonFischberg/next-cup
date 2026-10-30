package app.rarecreatures.nextcup.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.ui.screens.BeansScreen
import app.rarecreatures.nextcup.ui.screens.BrewScreen
import app.rarecreatures.nextcup.ui.screens.ExploreScreen
import app.rarecreatures.nextcup.ui.screens.JournalScreen
import app.rarecreatures.nextcup.ui.screens.SettingsScreen
import app.rarecreatures.nextcup.ui.theme.DS

/** The tab shell. The selected tab persists in preferences, so it survives a relaunch, as on iOS. */
@Composable
fun RootScreen() {
    val prefs = LocalContext.current.app.prefs
    val nav = rememberNavController()
    val entry by nav.currentBackStackEntryAsState()
    val start = AppTab.of(prefs.selectedTab)
    val openSettings = { nav.navigate("settings") }

    Scaffold(
        containerColor = DS.colors.bg,
        bottomBar = {
            NavigationBar(containerColor = DS.colors.paper) {
                for (tab in AppTab.entries) {
                    val selected = entry?.destination?.hierarchy?.any { it.route == tab.raw } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            prefs.selectedTab = tab.raw
                            nav.navigate(tab.raw) {
                                popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(tab.title) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = DS.colors.accent, selectedTextColor = DS.colors.accent,
                            indicatorColor = DS.colors.kraft, unselectedIconColor = DS.colors.ink2, unselectedTextColor = DS.colors.ink2,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        NavHost(nav, startDestination = start.raw, modifier = Modifier.padding(padding)) {
            composable(AppTab.RECIPES.raw) { BrewScreen(openSettings) }
            composable(AppTab.JOURNAL.raw) { JournalScreen(openSettings) { nav.navigate(AppTab.RECIPES.raw) } }
            composable(AppTab.BEANS.raw) { BeansScreen(openSettings) }
            composable(AppTab.EXPLORE.raw) { ExploreScreen(openSettings) }
            composable("settings") { SettingsScreen { nav.popBackStack() } }
        }
    }
}
