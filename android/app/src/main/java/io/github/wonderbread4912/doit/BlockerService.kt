package io.github.wonderbread4912.doit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Runs in the background, checks once a second which app is on screen, and
 * shows the DO IT stop screen when it is one of the blocked apps.
 */
class BlockerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastCheck = System.currentTimeMillis() - 5_000
    private var onScreen: String? = null

    private val loop = object : Runnable {
        override fun run() {
            check()
            handler.postDelayed(this, 1_000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        handler.removeCallbacks(loop)
        handler.post(loop)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(loop)
        super.onDestroy()
    }

    private fun check() {
        if (!hasUsageAccess(this)) return
        val now = System.currentTimeMillis()
        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usage.queryEvents(lastCheck, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            @Suppress("DEPRECATION")
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) onScreen = event.packageName
        }
        lastCheck = now

        val app = onScreen ?: return
        val store = Store(this)
        if (app == packageName || app !in store.blocked || store.onBreak) return
        if (StopActivity.showing) return
        startActivity(Intent(this, StopActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel("doit", "DO IT is watching", NotificationManager.IMPORTANCE_MIN)
        )
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val notification = Notification.Builder(this, "doit")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("DO IT is on")
            .setContentText("Blocking your distracting apps.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }
    }

    companion object {
        fun start(context: Context) {
            context.startForegroundService(Intent(context, BlockerService::class.java))
        }
    }
}
