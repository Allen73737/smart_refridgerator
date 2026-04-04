package com.example.smridge_frontend

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class SmridgeWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val ACTION_BLINK = "com.example.smridge_frontend.ACTION_BLINK"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_glass).apply {
                    val temp = widgetData.getString("temp", "--°C") ?: "--°C"
                    val hum  = widgetData.getString("hum",  "--%")  ?: "--%"
                    val freshness  = widgetData.getString("freshness",  "--")  ?: "--"
                    val door  = widgetData.getString("door",  "UNKNOWN")  ?: "UNKNOWN"
                    val status = widgetData.getString("status", "PROTOCOL: OPTIMAL") ?: "PROTOCOL: OPTIMAL"
                    val invJson = widgetData.getString("inventory_json", "[]") ?: "[]"
                    val notifJson = widgetData.getString("notifications_json", "[]") ?: "[]"
                    
                    setTextViewText(R.id.temp_value, temp)
                    setTextViewText(R.id.hum_value, hum)
                    setTextViewText(R.id.freshness_value, freshness)
                    setTextViewText(R.id.door_value, "DOOR: $door")
                    setTextViewText(R.id.status_text, status)
                    
                    try {
                        val invArray = JSONArray(invJson)
                        val builder = StringBuilder()
                        for (i in 0 until invArray.length()) {
                            builder.append("• ").append(invArray.getString(i)).append("\n")
                        }
                        setTextViewText(R.id.inventory_text, if (builder.length == 0) "So empty!" else builder.toString())

                        val notifArray = JSONArray(notifJson)
                        val nBuilder = StringBuilder()
                        for (i in 0 until notifArray.length()) {
                            nBuilder.append("! ").append(notifArray.getString(i)).append("\n")
                        }
                        setTextViewText(R.id.notifications_text, if (nBuilder.length == 0) "All good! 🎉" else nBuilder.toString())
                    } catch (e: Exception) {
                        setTextViewText(R.id.inventory_text, "Oops!")
                    }

                    // ⏲️ LIVE TIMER LOGIC
                    val timerTitle = widgetData.getString("timer_title", null)
                    val targetTimestamp = widgetData.getLong("target_timestamp", 0L)
                    val now = System.currentTimeMillis()

                    if (timerTitle != null && targetTimestamp > now) {
                        setViewVisibility(R.id.timer_section, android.view.View.VISIBLE)
                        setTextViewText(R.id.timer_title_text, "⏳ " + timerTitle.uppercase())
                        
                        // 🛠️ CRITICAL FIX: Base must be in SystemClock.elapsedRealtime()
                        val durationRemaining = targetTimestamp - now
                        val chronometerBase = SystemClock.elapsedRealtime() + durationRemaining
                        setChronometer(R.id.timer_countdown, chronometerBase, null, true)

                        // 🔔 Schedule Blink Alarm for precise finish
                        scheduleBlinkAlarm(context, targetTimestamp)
                    } else {
                        setViewVisibility(R.id.timer_section, android.view.View.GONE)
                    }

                    // 🚨 BLINK LOGIC (Triggers for 5s)
                    val shouldBlink = widgetData.getBoolean("blink_trigger", false)
                    if (shouldBlink) {
                        setViewVisibility(R.id.blink_overlay, android.view.View.VISIBLE)
                        
                        // Clear flag in SharedPreferences
                        widgetData.edit().putBoolean("blink_trigger", false).apply()
                        
                        // Schedule stop after 5 seconds
                        Handler(Looper.getMainLooper()).postDelayed({
                            try {
                                val stopViews = RemoteViews(context.packageName, R.layout.widget_glass)
                                stopViews.setViewVisibility(R.id.blink_overlay, android.view.View.GONE)
                                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, stopViews)
                            } catch (e: Exception) {}
                        }, 5000)
                    } else {
                        setViewVisibility(R.id.blink_overlay, android.view.View.GONE)
                    }
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {}
        }
    }

    private fun scheduleBlinkAlarm(context: Context, targetTimestamp: Long) {
        val intent = Intent(context, SmridgeWidgetProvider::class.java).apply {
            action = ACTION_BLINK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Use exact alarm for precise "blink at zero" experience
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, targetTimestamp, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, targetTimestamp, pendingIntent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_BLINK) {
            val widgetData = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)
            widgetData.edit().putBoolean("blink_trigger", true).apply()
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, SmridgeWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
        super.onReceive(context, intent)
    }
}
