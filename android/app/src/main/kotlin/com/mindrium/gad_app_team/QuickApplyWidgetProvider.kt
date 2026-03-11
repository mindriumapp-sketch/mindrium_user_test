package com.mindrium.gad_app_team

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class QuickApplyWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(appWidgetId, createRemoteViews(context, appWidgetId))
        }
    }

    companion object {
        private const val prefsName = "quick_apply_widget"
        private const val keyDiaryCount = "diary_count"
        private const val keyRelaxationCount = "relaxation_count"

        fun saveStats(context: Context, diaryCount: Int, relaxationCount: Int) {
            context
                .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .putInt(keyDiaryCount, diaryCount)
                .putInt(keyRelaxationCount, relaxationCount)
                .apply()
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, QuickApplyWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)
            appWidgetIds.forEach { appWidgetId ->
                appWidgetManager.updateAppWidget(appWidgetId, createRemoteViews(context, appWidgetId))
            }
        }

        private fun createRemoteViews(context: Context, appWidgetId: Int): RemoteViews {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val diaryCount = prefs.getInt(keyDiaryCount, 0)
            val relaxationCount = prefs.getInt(keyRelaxationCount, 0)
            val statsText = "일기 ${diaryCount}건 · 이완 ${relaxationCount}회"

            val launchIntent =
                Intent(context, MainActivity::class.java).apply {
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("launch_action", "start_apply")
                }

            val pendingIntent =
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )

            return RemoteViews(context.packageName, R.layout.home_widget).apply {
                setTextViewText(R.id.widget_stats, statsText)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
        }
    }
}
