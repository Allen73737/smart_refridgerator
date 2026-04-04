package com.example.smridge_frontend

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class SmridgeChronoWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_REFRESH_WIDGET = "com.example.smridge_frontend.ACTION_REFRESH_WIDGET"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context, SmridgeChronoWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            
            // Trigger a formal update
            val widgetData = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        var earliestExpiry = Long.MAX_VALUE
        val now = System.currentTimeMillis()

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chrono)
            
            try {
                val timerJson = widgetData.getString("timer_list_json", "[]") ?: "[]"
                val timerArray = JSONArray(timerJson)
                
                val rowIds = intArrayOf(R.id.timer_row_1, R.id.timer_row_2, R.id.timer_row_3)
                val nameIds = intArrayOf(R.id.timer_name_1, R.id.timer_name_2, R.id.timer_name_3)
                val valIds = intArrayOf(R.id.timer_val_1, R.id.timer_val_2, R.id.timer_val_3)

                for (id in rowIds) views.setViewVisibility(id, View.GONE)
                
                if (timerArray.length() == 0) {
                    views.setViewVisibility(R.id.empty_state_text, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.empty_state_text, View.GONE)
                    
                    val count = Math.min(timerArray.length(), 3)
                    for (i in 0 until count) {
                        val timerObj = timerArray.getJSONObject(i)
                        val name = timerObj.getString("name")
                        val targetTs = timerObj.getLong("target")
                        
                        if (targetTs > now && targetTs < earliestExpiry) {
                            earliestExpiry = targetTs
                        }

                        views.setViewVisibility(rowIds[i], View.VISIBLE)
                        views.setTextViewText(nameIds[i], name.uppercase())
                        
                        val durationRemaining = targetTs - now
                        if (durationRemaining > 0) {
                             val base = SystemClock.elapsedRealtime() + durationRemaining
                             views.setChronometer(valIds[i], base, null, true)
                        } else {
                             views.setChronometer(valIds[i], SystemClock.elapsedRealtime(), null, false)
                             views.setTextViewText(valIds[i], "00:00")
                        }
                    }
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.empty_state_text, View.VISIBLE)
                views.setTextViewText(R.id.empty_state_text, "Syncing...")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // 🚀 Schedule Next Autonomous Refresh
        if (earliestExpiry != Long.MAX_VALUE) {
            scheduleNextUpdate(context, earliestExpiry)
        }
    }

    private fun scheduleNextUpdate(context: Context, timeMillis: Long) {
        val intent = Intent(context, SmridgeChronoWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_WIDGET
        }
        
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getBroadcast(context, 737, intent, flags)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Trigger exactly when the earliest timer is supposed to finish
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pendingIntent)
            } else {
                alarmManager.setWindow(AlarmManager.RTC_WAKEUP, timeMillis, 1000, pendingIntent)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pendingIntent)
        }
    }
}
