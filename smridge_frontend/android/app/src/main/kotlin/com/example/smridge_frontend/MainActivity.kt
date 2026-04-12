package com.example.smridge_frontend

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "DISMISS_TIMER_NOTIFICATION") {
            val id = intent.getIntExtra("id", 0)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(id)
        }
    }
}

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.smridge.timer"
    private val NOTIFICATION_CHANNEL_ID = "smridge_urgent_v15"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showLiveTimer") {
                val id = call.argument<Int>("id") ?: 0
                val title = call.argument<String>("title") ?: "Timer"
                // Dart int can arrive as either Int or Long depending on magnitude.
                // Millisecond timestamps exceed Int.MAX_VALUE, so we must handle both.
                val targetTime = (call.argument<Number>("targetTime"))?.toLong() ?: 0L
                val payload = call.argument<String>("payload") ?: ""

                if (targetTime > System.currentTimeMillis()) {
                    showCustomTimerNotification(id, title, targetTime, payload)
                }
                result.success(null)
            } else if (call.method == "cancelLiveTimer") {
                val id = call.argument<Int>("id") ?: 0
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(id)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun showCustomTimerNotification(id: Int, title: String, targetTimeMillis: Long, payload: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create Default Channel if it doesn't exist
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Smridge Emergency Protocol",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        // Chronometer requires SystemClock.elapsedRealtime() base, not System.currentTimeMillis()
        val timeDiff = targetTimeMillis - System.currentTimeMillis()
        val chronometerBase = android.os.SystemClock.elapsedRealtime() + timeDiff

        // Custom Layout
        val remoteViews = RemoteViews(packageName, R.layout.live_timer_notification)
        remoteViews.setTextViewText(R.id.title, title)
        remoteViews.setChronometer(R.id.chronometer, chronometerBase, "%s", true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            remoteViews.setBoolean(R.id.chronometer, "setCountDown", true)
        }

        // Dismiss Intent
        val dismissIntent = Intent(this, NotificationDismissReceiver::class.java).apply {
            action = "DISMISS_TIMER_NOTIFICATION"
            putExtra("id", id)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingDismissIntent = PendingIntent.getBroadcast(this, id, dismissIntent, flags)
        remoteViews.setOnClickPendingIntent(R.id.btn_dismiss, pendingDismissIntent)

        // Application Intent (Tap body to open)
        val appIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            // flutter_local_notifications deeply hooks into the "payload" extra.
            putExtra("payload", payload)
            // It relies on SELECT_NOTIFICATION action sometimes, but setting standard action is ok
        }
        
        // We use 'id' as requestCode so multiple timers can coexist safely
        val pendingAppIntent = appIntent?.let {
            PendingIntent.getActivity(this, id, it, flags)
        }

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notif)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setOngoing(true) // Prevent swipe clear
            .setContentIntent(pendingAppIntent)
            .setFullScreenIntent(pendingAppIntent, true) // 🚨 Wake up screen for alarms
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // 🚨 Show on lock screen
            .setCategory(NotificationCompat.CATEGORY_ALARM) // 🚨 Treat as alarm

        manager.notify(id, builder.build())
    }
}
