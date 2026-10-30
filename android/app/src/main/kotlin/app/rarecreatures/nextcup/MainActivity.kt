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
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val prefs = app.prefs
        setContent {
            val style by prefs.style.collectAsStateWithLifecycle()
            val appearance by prefs.appearance.collectAsStateWithLifecycle()
            NextCupTheme(style, appearance) { RootScreen() }
        }
    }
}
