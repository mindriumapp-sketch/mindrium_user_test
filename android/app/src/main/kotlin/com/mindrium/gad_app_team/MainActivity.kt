package com.mindrium.gad_app_team

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val methodChannelName = "mindrium/widget_launch"
    private val eventChannelName = "mindrium/widget_launch_events"
    private var latestLaunchAction: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        latestLaunchAction = parseLaunchAction(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLaunchAction" -> {
                        result.success(latestLaunchAction)
                        latestLaunchAction = null
                    }
                    "updateWidgetStats" -> {
                        val diaryCount = parseIntArg(call.argument<Any?>("diaryCount"))
                        val relaxationCount =
                            parseIntArg(call.argument<Any?>("relaxationCount"))
                        val completedWeeks =
                            parseIntArg(call.argument<Any?>("completedWeeks"))
                        QuickApplyWidgetProvider.saveStats(
                            this,
                            diaryCount,
                            relaxationCount,
                            completedWeeks,
                        )
                        QuickApplyWidgetProvider.updateAllWidgets(this)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                        eventSink = sink
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                    }
                },
            )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launchAction = parseLaunchAction(intent) ?: return
        if (eventSink != null) {
            eventSink?.success(launchAction)
        } else {
            latestLaunchAction = launchAction
        }
    }

    private fun parseLaunchAction(intent: Intent?): String? {
        if (intent == null) return null
        val actionFromExtra = intent.getStringExtra("launch_action")?.trim()
        if (!actionFromExtra.isNullOrEmpty()) {
            return actionFromExtra
        }
        val data = intent.data ?: return null
        if (data.scheme != "mindrium" || data.host != "widget") {
            return null
        }
        val actionFromQuery = data.getQueryParameter("action")?.trim()
        return if (actionFromQuery.isNullOrEmpty()) null else actionFromQuery
    }

    private fun parseIntArg(value: Any?): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            is Float -> value.toInt()
            is String -> value.toIntOrNull() ?: 0
            else -> 0
        }
    }
}
