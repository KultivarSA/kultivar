package io.kultivar.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.kultivar.app.R

/**
 * Kultivar home-screen glance widget.
 *
 * Reads values saved by [WidgetUpdateService] (Flutter) from the app's
 * SharedPreferences under the "FlutterSharedPreferences" file with
 * a "flutter." key prefix — the convention used by the home_widget package.
 *
 * ## Required AndroidManifest.xml entries (already added):
 * ```xml
 * <receiver android:name=".KultivarHomeWidget" android:exported="true">
 *     <intent-filter>
 *         <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
 *         <action android:name="es.antonborri.home_widget.action.UPDATE" />
 *     </intent-filter>
 *     <meta-data
 *         android:name="android.appwidget.provider"
 *         android:resource="@xml/kultivar_widget_info" />
 * </receiver>
 * ```
 */
class KultivarHomeWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )

        // Keys must match the constants in WidgetUpdateService.dart
        val spaceName = prefs.getString("flutter.widget_space_name", "—") ?: "—"
        val temp      = prefs.getString("flutter.widget_temp",       "—") ?: "—"
        val humidity  = prefs.getString("flutter.widget_humidity",   "—") ?: "—"
        val vpd       = prefs.getString("flutter.widget_vpd",        "—") ?: "—"
        val vpdStatus = prefs.getString("flutter.widget_vpd_status", "")  ?: ""
        val age       = prefs.getString("flutter.widget_age",        "—") ?: "—"
        val nextCare  = prefs.getString("flutter.widget_next_care",  "—") ?: "—"

        // VPD status colour: ideal → green, high → red, low → blue, else muted
        val vpdColor = when (vpdStatus) {
            "ideal" -> 0xFF00C896.toInt()
            "high"  -> 0xFFEF4565.toInt()
            "low"   -> 0xFF64B5F6.toInt()
            else    -> 0xFF9090AA.toInt()
        }

        // Tap-to-open intent
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kultivar_widget)

            views.setTextViewText(R.id.widget_space_name, spaceName)
            views.setTextViewText(R.id.widget_temp,       temp)
            views.setTextViewText(R.id.widget_humidity,   humidity)
            views.setTextViewText(R.id.widget_vpd,        vpd)
            views.setTextViewText(R.id.widget_vpd_status, if (vpdStatus.isNotEmpty()) "VPD · $vpdStatus" else "VPD")
            views.setTextViewText(R.id.widget_age,        age)
            views.setTextViewText(R.id.widget_next_care,  nextCare)

            views.setTextColor(R.id.widget_vpd, vpdColor)

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
