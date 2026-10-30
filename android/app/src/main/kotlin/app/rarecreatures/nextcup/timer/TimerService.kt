package app.rarecreatures.nextcup.timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import app.rarecreatures.nextcup.Fmt
import app.rarecreatures.nextcup.MainActivity
import app.rarecreatures.nextcup.R
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.kit.TimerPhase

/**
 * Keeps a running brew alive in the background and shows it as an ongoing notification whose chronometer
 * runs by itself (the Android stand-in for iOS's Live Activity). It is told only about phase and step changes.
 */
class TimerService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val timer = app.timer
        when (intent?.action) {
            ACTION_PAUSE -> timer.pause()
            ACTION_RESUME -> timer.resume()
            ACTION_NEXT -> timer.skipToNextStep()
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
        }
        val notification = build(this) ?: run { stopSelf(); return START_NOT_STICKY }
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL = "brew-timer"
        private const val NOTIFICATION_ID = 7
        private const val ACTION_PAUSE = "pause"
        private const val ACTION_RESUME = "resume"
        private const val ACTION_NEXT = "next"
        private const val ACTION_STOP = "stop"

        fun start(context: Context) = runCatching { ContextCompat.startForegroundService(context, Intent(context, TimerService::class.java)) }

        fun update(context: Context) {
            if (!context.app.timer.isActive) return
            val n = build(context) ?: return
            runCatching { NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, n) }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TimerService::class.java))
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }

        private fun action(context: Context, action: String) = PendingIntent.getService(
            context, action.hashCode(), Intent(context, TimerService::class.java).setAction(action),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        fun build(context: Context): Notification? {
            val timer = context.app.timer
            val setup = timer.setup.value ?: return null
            val state = timer.state.value ?: return null
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Brew timer", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "The brew that is running, with its current step."
                    setShowBadge(false)
                },
            )
            val step = state.current
            val target = step?.targetCumulativeWaterG?.let { " to ${Fmt.weight(it, context.app.prefs.units.value)}" } ?: ""
            val text = when {
                state.phase == TimerPhase.Paused -> "Paused at ${Fmt.clock(state.elapsedS.toInt())}"
                state.targetReached -> "Target time reached. Finish when it has drained."
                step != null -> "${step.label}$target"
                else -> "Starting"
            }
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java).setAction(MainActivity.ACTION_OPEN_TIMER)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            val running = state.phase == TimerPhase.Running
            return NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(setup.recipeName)
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(open)
                .setShowWhen(running)
                .setUsesChronometer(running)
                .setWhen(System.currentTimeMillis() - (state.elapsedS * 1000).toLong())
                .addAction(
                    0, if (running) "Pause" else "Resume", action(context, if (running) ACTION_PAUSE else ACTION_RESUME),
                )
                .addAction(0, if (state.next == null) "Finish" else "Next step", action(context, ACTION_NEXT))
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
        }
    }
}
