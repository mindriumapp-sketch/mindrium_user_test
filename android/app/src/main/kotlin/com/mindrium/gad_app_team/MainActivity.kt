package com.mindrium.gad_app_team

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import java.io.File

class MainActivity : FlutterActivity() {
    private val methodChannelName = "mindrium/widget_launch"
    private val eventChannelName = "mindrium/widget_launch_events"
    private val manualPdfChannelName = "mindrium/manual_pdf"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, manualPdfChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openManual" -> openManualPdf(result)
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

    private fun openManualPdf(result: MethodChannel.Result) {
        try {
            val pdfFile = File(cacheDir, "Mindrium_manual.pdf")
            assets.open("flutter_assets/assets/Mindrium_manual.pdf").use { input ->
                pdfFile.outputStream().use { output -> input.copyTo(output) }
            }

            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                pdfFile,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.error("NO_VIEWER", "No PDF viewer is available.", null)
        } catch (error: Exception) {
            result.error("OPEN_FAILED", error.message ?: "Failed to open manual.", null)
        }
    }
}
