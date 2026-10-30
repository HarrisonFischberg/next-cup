package app.rarecreatures.nextcup.ui.screens

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFeatureSettings
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.kit.TimerPhase
import app.rarecreatures.nextcup.ui.BackBar
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.theme.DS

/** The guided timer: the clock, the step now and the one after, and big controls for wet hands. */
@Composable
fun TimerScreen(back: () -> Unit, finished: () -> Unit) {
    val app = LocalContext.current.app
    val timer = app.timer
    val setup by timer.setup.collectAsStateWithLifecycle()
    val state by timer.state.collectAsStateWithLifecycle()
    val outcome by timer.outcome.collectAsStateWithLifecycle()
    val units by app.prefs.units.collectAsStateWithLifecycle()
    var confirmEnd by remember { mutableStateOf(false) }
    val askNotifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { timer.start() }

    // The screen stays on while a brew runs.
    val view = LocalView.current
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
    LaunchedEffect(outcome) { if (outcome != null) finished() }

    val s = setup
    val st = state
    Column(Modifier.fillMaxSize()) {
        BackBar(s?.recipeName ?: "Brew", back)
        if (s == null || st == null) return@Column
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DS.Space.lg),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DS.Space.lg),
        ) {
            val groups = s.plan.displayGroups
            val group = st.currentIndex?.let { s.plan.groupIndex(it) }
            Kicker(
                when {
                    st.phase == TimerPhase.NotStarted -> "Ready · ${Fmt.weight(s.scaled.doseG, units)} → ${Fmt.weight(s.scaled.waterG, units)}"
                    group != null -> "%02d / %02d".format(group + 1, groups.size) + " · " + (st.current?.label ?: "")
                    else -> "Starting"
                },
            )
            Box(Modifier.widthIn(max = 360.dp).fillMaxWidth().aspectRatio(1f), contentAlignment = Alignment.Center) {
                val track = DS.colors.line.copy(alpha = 0.3f)
                val accent = DS.colors.accent
                Canvas(Modifier.fillMaxSize().padding(8.dp)) {
                    val stroke = Stroke(width = 18.dp.toPx(), cap = StrokeCap.Round)
                    drawArc(track, 0f, 360f, false, style = stroke)
                    drawArc(accent, -90f, 360f * st.progress.toFloat(), false, style = stroke)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    val shown = if (st.targetReached) st.elapsedS.toInt() else st.remainingS.toInt()
                    Text(
                        Fmt.clock(if (st.phase == TimerPhase.NotStarted) s.plan.totalDurationS else shown),
                        fontSize = 72.sp, style = MaterialTheme.typography.displaySmall.copy(fontFeatureSettings = "tnum"),
                        color = DS.colors.ink,
                        modifier = Modifier.semantics {
                            contentDescription = if (st.targetReached) "Elapsed ${Fmt.spokenTime(st.elapsedS.toInt())}" else "${Fmt.spokenTime(st.remainingS.toInt())} left"
                        },
                    )
                    Text(
                        when {
                            st.phase == TimerPhase.Paused -> "Paused"
                            st.targetReached -> "+${Fmt.clock(st.overtimeS.toInt())} past target"
                            else -> "left of ${Fmt.clock(s.plan.totalDurationS)}"
                        },
                        color = DS.colors.ink2,
                    )
                }
            }
            val current = st.current
            Column(Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite }, horizontalAlignment = Alignment.CenterHorizontally) {
                if (current != null) {
                    val target = current.targetCumulativeWaterG?.let { " to ${Fmt.weight(it, units)}" } ?: ""
                    Text(current.label + target, style = MaterialTheme.typography.headlineMedium, color = DS.colors.ink, textAlign = TextAlign.Center)
                    if (current.instruction.isNotBlank()) Text(current.instruction, style = MaterialTheme.typography.bodyLarge, color = DS.colors.ink2, textAlign = TextAlign.Center)
                } else if (st.phase == TimerPhase.NotStarted) {
                    Text("Press Start when the water is ready.", style = MaterialTheme.typography.bodyLarge, color = DS.colors.ink2, textAlign = TextAlign.Center)
                    s.tempC?.let { Text("Water at ${Fmt.temperature(it, units)}", style = MaterialTheme.typography.titleMedium, color = DS.colors.ink) }
                }
                st.next?.let { next ->
                    Spacer(Modifier.height(DS.Space.sm))
                    val inS = st.secondsToNextChange?.toInt()
                    Text(
                        "Next: ${next.label}" + (next.targetCumulativeWaterG?.let { " to ${Fmt.weight(it, units)}" } ?: "") + (inS?.let { " in ${Fmt.clock(it)}" } ?: ""),
                        style = MaterialTheme.typography.bodyMedium, color = DS.colors.accent,
                    )
                }
            }
            val big = Modifier.fillMaxWidth().height(DS.Size.timerControl)
            when (st.phase) {
                TimerPhase.NotStarted -> Button(
                    onClick = {
                        if (Build.VERSION.SDK_INT >= 33 && !app.prefs.raw.getBoolean("asked.notifications", false)) {
                            app.prefs.raw.edit().putBoolean("asked.notifications", true).apply()
                            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else timer.start()
                    },
                    modifier = big,
                ) { Text("Start", style = MaterialTheme.typography.titleLarge) }
                TimerPhase.Running, TimerPhase.Paused -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(DS.Space.md)) {
                        val running = st.phase == TimerPhase.Running
                        Button(onClick = { if (running) timer.pause() else timer.resume() }, modifier = Modifier.weight(1f).height(DS.Size.timerControl)) {
                            Text(if (running) "Pause" else "Resume", style = MaterialTheme.typography.titleMedium)
                        }
                        OutlinedButton(onClick = { timer.skipToNextStep() }, modifier = Modifier.weight(1f).height(DS.Size.timerControl)) {
                            Text(if (st.next == null) "Finish" else "Skip step", style = MaterialTheme.typography.titleMedium)
                        }
                    }
                    if (st.targetReached) Button(onClick = { timer.finish() }, modifier = big) { Text("Done brewing", style = MaterialTheme.typography.titleMedium) }
                    else TextButton(onClick = { confirmEnd = true }) { Text("End brew") }
                }
                is TimerPhase.Finished -> {}
            }
            if (st.phase == TimerPhase.NotStarted) TextButton(onClick = { timer.cancel(); back() }) { Text("Cancel") }
        }
    }
    if (confirmEnd) AlertDialog(
        onDismissRequest = { confirmEnd = false },
        title = { Text("End brew?") },
        text = { Text("The time reached so far is kept and goes into the journal entry.") },
        confirmButton = { TextButton(onClick = { confirmEnd = false; timer.endEarly() }) { Text("End and log it") } },
        dismissButton = { TextButton(onClick = { confirmEnd = false }) { Text("Keep brewing") } },
    )
}
