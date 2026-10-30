package app.rarecreatures.nextcup

import android.app.Application
import android.content.Context
import android.util.Log
import app.rarecreatures.nextcup.data.BuiltInContent
import app.rarecreatures.nextcup.data.BuiltInSeeder
import app.rarecreatures.nextcup.data.NextCupDatabase
import app.rarecreatures.nextcup.kit.DraftStore
import app.rarecreatures.nextcup.kit.Taxonomy
import app.rarecreatures.nextcup.timer.TimerController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File

/** Process-wide objects: the database, preferences, the bundled taxonomy. No accounts, no analytics. */
class NextCupApp : Application() {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val db: NextCupDatabase by lazy { NextCupDatabase.open(this) }
    val prefs: Prefs by lazy { Prefs(getSharedPreferences("nextcup", MODE_PRIVATE)) }
    val timer: TimerController by lazy { TimerController(this, db, prefs.raw, scope) }
    val taxonomy: Taxonomy by lazy { Taxonomy.fromJson(asset("taxonomy.json")) }

    fun asset(name: String): String = assets.open(name).bufferedReader().use { it.readText() }

    override fun onCreate() {
        super.onCreate()
        DraftStore.folder = File(filesDir, "Drafts")
        scope.launch {
            runCatching {
                BuiltInSeeder(db, prefs.raw).seed(BuiltInContent.parse(asset("methods.json"), asset("recipes.json")))
            }.onFailure { Log.e("NextCup", "Seeding built-in methods failed; retrying next launch", it) }
            // A brew that was running when the process died comes back with its notification.
            if (timer.restoreIfRunning()) timer.resumeService()
        }
    }
}

val Context.app: NextCupApp get() = applicationContext as NextCupApp
