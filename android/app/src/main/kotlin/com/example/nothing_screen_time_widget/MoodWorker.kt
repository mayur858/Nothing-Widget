package com.example.nothing_screen_time_widget

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Repaints all installed widget instances on Android's minimum 15-minute cadence. */
class MoodWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        MoodWidgetProvider.updateAll(applicationContext)
        return Result.success()
    }
}
