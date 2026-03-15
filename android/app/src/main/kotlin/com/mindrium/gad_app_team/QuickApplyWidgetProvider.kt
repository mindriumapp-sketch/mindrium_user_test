package com.mindrium.gad_app_team

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
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
        private const val keyCompletedWeeks = "completed_weeks"

        fun saveStats(
            context: Context,
            diaryCount: Int,
            relaxationCount: Int,
            completedWeeks: Int,
        ) {
            context
                .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .putInt(keyDiaryCount, diaryCount)
                .putInt(keyRelaxationCount, relaxationCount)
                .putInt(keyCompletedWeeks, completedWeeks)
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
            val completedWeeks = prefs.getInt(keyCompletedWeeks, 0)
            val isWidgetUnlocked = completedWeeks >= 2
            val titleText = if (isWidgetUnlocked) "Relief" else "2주차 완료 후 이용 가능"
            val tagText = if (isWidgetUnlocked) "READY" else "LOCKED"
            val statsText =
                if (isWidgetUnlocked) {
                    "일기 ${diaryCount}건 · 이완 ${relaxationCount}회"
                } else {
                    "2주차 교육 완료 후 Relief를 바로 시작할 수 있어요."
                }
            val ctaText = if (isWidgetUnlocked) "지금 시작" else "교육 먼저 하기"

            val launchIntent =
                Intent(context, MainActivity::class.java).apply {
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    if (isWidgetUnlocked) {
                        putExtra("launch_action", "start_apply")
                    }
                }

            val pendingIntent =
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )

            return RemoteViews(context.packageName, R.layout.home_widget).apply {
                setTextViewText(R.id.widget_tag, tagText)
                setTextViewText(R.id.widget_title, titleText)
                setTextViewText(R.id.widget_stats, statsText)
                setTextViewText(R.id.widget_cta, ctaText)
                setTextColor(
                    R.id.widget_title,
                    Color.parseColor(if (isWidgetUnlocked) "#132D4A" else "#3A4B5D"),
                )
                setTextColor(
                    R.id.widget_stats,
                    Color.parseColor(if (isWidgetUnlocked) "#1F3D5C" else "#5D6A78"),
                )
                setTextColor(
                    R.id.widget_tag,
                    Color.parseColor(if (isWidgetUnlocked) "#2A6FB0" else "#6B7684"),
                )
                setTextColor(
                    R.id.widget_cta,
                    Color.parseColor(if (isWidgetUnlocked) "#FFFFFF" else "#5C6D81"),
                )
                setInt(
                    R.id.widget_tag,
                    "setBackgroundResource",
                    if (isWidgetUnlocked) {
                        R.drawable.widget_tag_unlocked_background
                    } else {
                        R.drawable.widget_tag_locked_background
                    },
                )
                setInt(
                    R.id.widget_cta,
                    "setBackgroundResource",
                    if (isWidgetUnlocked) {
                        R.drawable.widget_cta_primary_background
                    } else {
                        R.drawable.widget_cta_locked_background
                    },
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
        }
    }
}
