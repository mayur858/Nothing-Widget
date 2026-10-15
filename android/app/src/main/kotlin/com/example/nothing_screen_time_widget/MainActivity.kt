package com.example.nothing_screen_time_widget

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mood_widget/usage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(UsageStatsHelper.hasUsageAccess(this))
                    "openUsageAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error("UNAVAILABLE", "Usage access settings not available", null)
                        }
                    }
                    "getScreenOnMinutesToday" -> result.success(
                        (UsageStatsHelper.getScreenOnMillisToday(this) / 60_000).toInt(),
                    )
                    else -> result.notImplemented()
                }
            }

        // The widget schedules its own refresh when it is added (onEnabled); this covers
        // widgets placed before that logic existed.
        MoodWorker.scheduleIfWidgetsPlaced(this)
    }
}
