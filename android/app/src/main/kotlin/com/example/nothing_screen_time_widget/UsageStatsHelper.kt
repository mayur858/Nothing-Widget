package com.example.nothing_screen_time_widget

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

/** Reads total device screen-on time, rather than per-app usage, since midnight. */
object UsageStatsHelper {
    enum class Mood { HAPPY, NEUTRAL, SAD }

    fun getScreenOnMillisToday(context: Context): Long {
        val usageStats = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val now = System.currentTimeMillis()

        val events = usageStats.queryEvents(startOfDay, now)
        val event = UsageEvents.Event()
        var total = 0L
        var interactiveSince = -1L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.SCREEN_INTERACTIVE -> interactiveSince = event.timeStamp
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    if (interactiveSince > 0) {
                        total += event.timeStamp - interactiveSince
                        interactiveSince = -1L
                    }
                }
            }
        }
        if (interactiveSince > 0) total += now - interactiveSince
        return total
    }

    fun moodFor(screenOnMillis: Long, happyLimitHours: Double, sadLimitHours: Double): Mood {
        val hours = screenOnMillis / 3_600_000.0
        return when {
            hours < happyLimitHours -> Mood.HAPPY
            hours < sadLimitHours -> Mood.NEUTRAL
            else -> Mood.SAD
        }
    }
}
