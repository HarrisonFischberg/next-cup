package app.rarecreatures.nextcup

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.ui.RootScreen
import app.rarecreatures.nextcup.ui.theme.NextCupTheme

class MainActivity : ComponentActivity() {
    /** Bumped when the brew notification is tapped, so the shell opens the timer. */
    val openTimer = kotlinx.coroutines.flow.MutableStateFlow(0)

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (intent.action == ACTION_OPEN_TIMER) openTimer.value++
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (intent?.action == ACTION_OPEN_TIMER) openTimer.value++
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val prefs = app.prefs
        setContent {
            val style by prefs.style.collectAsStateWithLifecycle()
            val appearance by prefs.appearance.collectAsStateWithLifecycle()
            NextCupTheme(style, appearance) { RootScreen(openTimer) }
        }
    }

    companion object {
        const val ACTION_OPEN_TIMER = "app.rarecreatures.nextcup.OPEN_TIMER"
    }
}
