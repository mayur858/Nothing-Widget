package com.example.nothing_screen_time_widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/** Repaints all installed widget instances on Android's minimum 15-minute cadence. */
class MoodWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        MoodWidgetProvider.updateAll(applicationContext)
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "mood_widget_refresh"

        /** Starts the periodic refresh (no-op if it is already scheduled). */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<MoodWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        /**
         * Safety net for installs that already have a widget placed (the widget's
         * own onEnabled() only fires when the first instance is added): schedules
         * the refresh only if there is actually a widget to refresh.
         */
        fun scheduleIfWidgetsPlaced(context: Context) {
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, MoodWidgetProvider::class.java))
            if (ids.isNotEmpty()) schedule(context)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
