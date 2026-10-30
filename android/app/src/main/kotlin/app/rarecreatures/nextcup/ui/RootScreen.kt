package app.rarecreatures.nextcup.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.brew.FormSource
import app.rarecreatures.nextcup.ui.screens.BeanDetailScreen
import app.rarecreatures.nextcup.ui.screens.BeanEditorScreen
import app.rarecreatures.nextcup.ui.screens.BeansScreen
import app.rarecreatures.nextcup.ui.screens.RoasterDetailScreen
import app.rarecreatures.nextcup.ui.screens.RoasterDiscoveryScreen
import app.rarecreatures.nextcup.ui.screens.BrewFormScreen
import app.rarecreatures.nextcup.ui.screens.BrewScreen
import app.rarecreatures.nextcup.ui.screens.ExploreScreen
import app.rarecreatures.nextcup.ui.screens.JournalScreen
import app.rarecreatures.nextcup.ui.screens.MethodStylesScreen
import app.rarecreatures.nextcup.ui.screens.RecipeDetailScreen
import app.rarecreatures.nextcup.ui.screens.SettingsScreen
import app.rarecreatures.nextcup.ui.screens.TimerScreen
import app.rarecreatures.nextcup.ui.theme.DS
import kotlinx.coroutines.flow.StateFlow

/** Routes inside the shell. Tabs use their persisted raw values. */
object Routes {
    const val SETTINGS = "settings"
    const val TIMER = "timer"
    fun method(id: String) = "method/$id"
    fun recipe(id: String) = "recipe/$id"
    fun brew(id: String) = "brew/$id"
    fun again(id: String) = "again/$id"
    fun unsaved(name: String) = "unsaved/$name"
    const val NEW_BREW = "newBrew"
    const val FINISHED_BREW = "finishedBrew"
}

private fun NavHostController.selectTab(tab: AppTab) = navigate(tab.raw) {
    popUpTo(graph.findStartDestination().id) { saveState = true }
    launchSingleTop = true
    restoreState = true
}

/** The tab shell. The selected tab persists in preferences, so it survives a relaunch, as on iOS. */
@Composable
fun RootScreen(openTimer: StateFlow<Int>) {
    val app = LocalContext.current.app
    val prefs = app.prefs
    val nav = rememberNavController()
    val entry by nav.currentBackStackEntryAsState()
    val start = AppTab.of(prefs.selectedTab)
    val openSettings = { nav.navigate(Routes.SETTINGS) }
    val timerTaps by openTimer.collectAsStateWithLifecycle()
    LaunchedEffect(timerTaps) {
        if (timerTaps > 0 && app.timer.setup.value != null) nav.navigate(Routes.TIMER) { launchSingleTop = true }
    }
    val idArg = listOf(navArgument("id") { type = NavType.StringType })

    Scaffold(
        containerColor = DS.colors.bg,
        bottomBar = {
            NavigationBar(containerColor = DS.colors.paper) {
                for (tab in AppTab.entries) {
                    val selected = entry?.destination?.hierarchy?.any { it.route == tab.raw } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = { prefs.selectedTab = tab.raw; nav.selectTab(tab) },
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
            composable(AppTab.RECIPES.raw) { BrewScreen(openSettings) { nav.navigate(Routes.method(it)) } }
            composable(AppTab.JOURNAL.raw) {
                JournalScreen(
                    openSettings, startBrew = { prefs.selectedTab = AppTab.RECIPES.raw; nav.selectTab(AppTab.RECIPES) },
                    logBrew = { nav.navigate(Routes.NEW_BREW) }, openBrew = { nav.navigate(Routes.brew(it)) },
                    brewAgain = { nav.navigate(Routes.again(it)) }, resume = { nav.navigate(Routes.unsaved(it)) },
                )
            }
            composable(AppTab.BEANS.raw) { BeansScreen(openSettings, addBean = { nav.navigate("newBean") }) { nav.navigate("bean/$it") } }
            composable(AppTab.EXPLORE.raw) { ExploreScreen(openSettings, openRoaster = { nav.navigate("roaster/$it") }) { nav.navigate("discover") } }
            composable("newBean") { BeanEditorScreen(null, { nav.popBackStack() }) { id -> nav.navigate("bean/$id") { popUpTo("newBean") { inclusive = true } } } }
            composable("editBean/{id}", idArg) { e -> BeanEditorScreen(e.arguments!!.getString("id"), { nav.popBackStack() }) { nav.popBackStack() } }
            composable("bean/{id}", idArg) { e ->
                val id = e.arguments!!.getString("id")!!
                BeanDetailScreen(id, { nav.popBackStack() }, edit = { nav.navigate("editBean/$id") }, openBrew = { nav.navigate(Routes.brew(it)) }) { nav.navigate(Routes.recipe(it)) }
            }
            composable("roaster/{id}", idArg) { e ->
                RoasterDetailScreen(e.arguments!!.getString("id")!!, { nav.popBackStack() }, openBean = { nav.navigate("bean/$it") }) { nav.navigate(Routes.recipe(it)) }
            }
            composable("discover") { RoasterDiscoveryScreen { nav.popBackStack() } }
            composable(Routes.SETTINGS) { SettingsScreen { nav.popBackStack() } }
            composable("method/{id}", idArg) { e -> MethodStylesScreen(e.arguments!!.getString("id")!!, { nav.popBackStack() }) { nav.navigate(Routes.recipe(it)) } }
            composable("recipe/{id}", idArg) { e -> RecipeDetailScreen(e.arguments!!.getString("id")!!, { nav.popBackStack() }) { nav.navigate(Routes.TIMER) } }
            composable(Routes.TIMER) {
                TimerScreen(back = { nav.popBackStack() }) {
                    nav.navigate(Routes.FINISHED_BREW) { popUpTo(Routes.TIMER) { inclusive = true } }
                }
            }
            composable(Routes.FINISHED_BREW) {
                val outcome = app.timer.outcome.value
                BrewFormScreen(outcome?.let { FormSource.FromTimer(it) } ?: FormSource.New, back = { app.timer.consumeOutcome(); nav.popBackStack() })
            }
            composable(Routes.NEW_BREW) { BrewFormScreen(FormSource.New, back = { nav.popBackStack() }) }
            composable("brew/{id}", idArg) { e -> BrewFormScreen(FormSource.Editing(e.arguments!!.getString("id")!!), back = { nav.popBackStack() }) }
            composable("again/{id}", idArg) { e -> BrewFormScreen(FormSource.Repeating(e.arguments!!.getString("id")!!), back = { nav.popBackStack() }) }
            composable("unsaved/{id}", idArg) { e -> BrewFormScreen(FormSource.Resuming(e.arguments!!.getString("id")!!), back = { nav.popBackStack() }) }
        }
    }
}
