package com.example.nothing_screen_time_widget

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.util.Calendar

/** Reads total device screen-on time, rather than per-app usage, since midnight. */
object UsageStatsHelper {
    /** NO_ACCESS = Usage Access not granted, so we can't tell how the day is going. */
    enum class Mood { HAPPY, NEUTRAL, SAD, NO_ACCESS }

    /**
     * Events are queried from this long before midnight so a screen-on span that
     * began the previous evening is still seen (and counted from midnight on).
     */
    private const val LOOKBACK_MILLIS = 6L * 60 * 60 * 1000

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun getScreenOnMillisToday(context: Context): Long {
        val usageStats = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val now = System.currentTimeMillis()

        val events = usageStats.queryEvents(startOfDay - LOOKBACK_MILLIS, now)
        val event = UsageEvents.Event()
        var total = 0L
        var interactiveSince = NOT_INTERACTIVE

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.SCREEN_INTERACTIVE -> interactiveSince = event.timeStamp
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    if (interactiveSince != NOT_INTERACTIVE) {
                        total += overlapWithToday(interactiveSince, event.timeStamp, startOfDay)
                        interactiveSince = NOT_INTERACTIVE
                    }
                }
            }
        }
        if (interactiveSince != NOT_INTERACTIVE) {
            total += overlapWithToday(interactiveSince, now, startOfDay)
        }
        return total
    }

    /** Length of [start, end] that falls on or after [startOfDay]. */
    private fun overlapWithToday(start: Long, end: Long, startOfDay: Long): Long =
        (end - maxOf(start, startOfDay)).coerceAtLeast(0L)

    private const val NOT_INTERACTIVE = -1L

    /** Mirrors `MoodThresholds.moodFor` on the Dart side — keep in sync. */
    fun moodFor(screenOnMillis: Long, happyLimitHours: Double, sadLimitHours: Double): Mood {
        val hours = screenOnMillis / 3_600_000.0
        return when {
            hours < happyLimitHours -> Mood.HAPPY
            hours < sadLimitHours -> Mood.NEUTRAL
            else -> Mood.SAD
        }
    }
}
