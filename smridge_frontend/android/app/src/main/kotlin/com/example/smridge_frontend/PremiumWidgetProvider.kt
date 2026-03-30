package com.example.smridge_frontend

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class PremiumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_premium).apply {
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
                    setTextViewText(R.id.door_value, "[ DOOR: $door ]")
                    setTextViewText(R.id.status_text, "[$status]")
                    
                    try {
                        val invArray = JSONArray(invJson)
                        val builder = java.lang.StringBuilder()
                        for (i in 0 until invArray.length()) {
                            builder.append("> ").append(invArray.getString(i)).append("\n")
                        }
                        setTextViewText(R.id.inventory_text, if (builder.length == 0) "NO ITEMS" else builder.toString())

                        val notifArray = JSONArray(notifJson)
                        val nBuilder = java.lang.StringBuilder()
                        for (i in 0 until notifArray.length()) {
                            nBuilder.append(">> ").append(notifArray.getString(i)).append("\n")
                        }
                        setTextViewText(R.id.notifications_text, if (nBuilder.length == 0) "ALL CLEAR" else nBuilder.toString())
                    } catch (e: Exception) {
                        setTextViewText(R.id.inventory_text, "ERR_SYNC")
                    }
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {}
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
    }
}
