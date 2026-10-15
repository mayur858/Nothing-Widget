package com.example.nothing_screen_time_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.PI
import kotlin.math.sin

/**
 * Face proportions, as fractions of the (square) bitmap side.
 * Mirrors `FaceGeometry` in lib/widgets/mood_face_painter.dart — keep in sync.
 */
private object FaceGeometry {
    const val DOT_RADIUS = 0.0115f

    // Dotted rounded-rect "screen" outline
    const val OUTLINE_LEFT = 0.355f
    const val OUTLINE_TOP = 0.245f
    const val OUTLINE_RIGHT = 0.645f // left + width (0.29)
    const val OUTLINE_BOTTOM = 0.755f // top + height (0.51)
    const val OUTLINE_CORNER_RADIUS = 0.04f
    const val OUTLINE_SPACING = 0.033f

    // Speaker grill
    const val SPEAKER_Y = 0.285f
    const val SPEAKER_SPACING = 0.024f
    const val SPEAKER_DOT_SCALE = 0.95f

    // Eyes
    const val EYE_Y = 0.465f
    const val EYE_LEFT_X = 0.455f
    const val EYE_RIGHT_X = 0.545f
    const val EYE_DOT_SCALE = 1.12f

    // Nose — L shape: top dot at eye level, three more going down, one foot
    const val NOSE_X = 0.488f
    const val NOSE_2_Y = 0.493f
    const val NOSE_3_Y = 0.521f
    const val NOSE_BOTTOM_Y = 0.549f
    const val NOSE_FOOT_X = 0.516f

    // Mouth — 5-dot arc
    const val MOUTH_Y = 0.615f
    const val MOUTH_WIDTH = 0.145f
    const val MOUTH_DOTS = 5
    const val MOUTH_CURVE = 0.025f
}

/** Dot colours per mood, with a shade for each device theme (mirrors `MoodStatePalette` in Dart). */
private object MoodPalette {
    fun dotColor(mood: UsageStatsHelper.Mood, night: Boolean): Int = Color.parseColor(
        when (mood) {
            UsageStatsHelper.Mood.HAPPY -> if (night) "#00E676" else "#00B050"
            UsageStatsHelper.Mood.NEUTRAL -> if (night) "#FFB300" else "#D97706"
            UsageStatsHelper.Mood.SAD -> if (night) "#FF5252" else "#E53935"
            UsageStatsHelper.Mood.NO_ACCESS -> if (night) "#9CA3AF" else "#6B7280"
        },
    )

    fun isNight(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightMode == Configuration.UI_MODE_NIGHT_YES
    }
}

class MoodWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { id -> updateOne(context, appWidgetManager, id) }
    }

    /** First widget instance added: start the periodic refresh. */
    override fun onEnabled(context: Context) {
        MoodWorker.schedule(context)
    }

    /** Last widget instance removed: stop refreshing, nothing is left to repaint. */
    override fun onDisabled(context: Context) {
        MoodWorker.cancel(context)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MoodWidgetProvider::class.java))
            ids.forEach { id -> updateOne(context, manager, id) }
        }

        private fun currentMood(context: Context): UsageStatsHelper.Mood {
            if (!UsageStatsHelper.hasUsageAccess(context)) return UsageStatsHelper.Mood.NO_ACCESS
            val preferences = HomeWidgetPlugin.getData(context)
            return UsageStatsHelper.moodFor(
                UsageStatsHelper.getScreenOnMillisToday(context),
                preferences.getDouble("happyLimitHours", 2.0),
                preferences.getDouble("sadLimitHours", 4.0),
            )
        }

        private fun descriptionFor(mood: UsageStatsHelper.Mood): Int = when (mood) {
            UsageStatsHelper.Mood.HAPPY -> R.string.widget_description_happy
            UsageStatsHelper.Mood.NEUTRAL -> R.string.widget_description_neutral
            UsageStatsHelper.Mood.SAD -> R.string.widget_description_sad
            UsageStatsHelper.Mood.NO_ACCESS -> R.string.widget_description_no_access
        }

        private fun updateOne(context: Context, manager: AppWidgetManager, id: Int) {
            val mood = currentMood(context)

            val views = RemoteViews(context.packageName, R.layout.mood_widget).apply {
                // The card (fill + border) is the layout's day/night-aware background drawable,
                // so the launcher flips it with the device theme on its own. The bitmap is only a
                // white dot mask, tinted below with the mood colour for the current theme.
                setImageViewBitmap(R.id.widget_image, drawFaceMask(mood))

                val lightDots = MoodPalette.dotColor(mood, night = false)
                val darkDots = MoodPalette.dotColor(mood, night = true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Resolved by the host, so the dots follow theme changes without a repaint.
                    setColorInt(R.id.widget_image, "setColorFilter", lightDots, darkDots)
                } else {
                    // Older Android: use the theme at update time (refreshed on the next update).
                    setInt(
                        R.id.widget_image,
                        "setColorFilter",
                        if (MoodPalette.isNight(context)) darkDots else lightDots,
                    )
                }

                setContentDescription(R.id.widget_image, context.getString(descriptionFor(mood)))

                // Tapping widget opens the app
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_image, pendingIntent)
            }

            manager.updateAppWidget(id, views)
        }

        private fun android.content.SharedPreferences.getDouble(key: String, fallback: Double): Double {
            return if (getBoolean("home_widget.double.$key", false)) {
                Double.fromBits(getLong(key, fallback.toBits()))
            } else {
                getFloat(key, fallback.toFloat()).toDouble()
            }
        }

        /**
         * The Nothing-inspired dot face as a white-on-transparent mask. The mood decides the
         * mouth shape (smile / flat / frown); colour is applied later by the ImageView tint,
         * and the card behind it comes from the layout's background drawable.
         */
        private fun drawFaceMask(mood: UsageStatsHelper.Mood, size: Int = 360): Bitmap {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
            val side = size.toFloat()
            val dotRadius = side * FaceGeometry.DOT_RADIUS

            val outline = RectF(
                side * FaceGeometry.OUTLINE_LEFT,
                side * FaceGeometry.OUTLINE_TOP,
                side * FaceGeometry.OUTLINE_RIGHT,
                side * FaceGeometry.OUTLINE_BOTTOM,
            )
            drawDottedRoundRect(
                canvas,
                dotPaint,
                outline,
                side * FaceGeometry.OUTLINE_CORNER_RADIUS,
                dotRadius,
                side * FaceGeometry.OUTLINE_SPACING,
            )

            // Speaker grill at the top inside the phone outline
            val speakerY = side * FaceGeometry.SPEAKER_Y
            val speakerSpacing = side * FaceGeometry.SPEAKER_SPACING
            val speakerRadius = dotRadius * FaceGeometry.SPEAKER_DOT_SCALE
            canvas.drawCircle(side * 0.5f - speakerSpacing, speakerY, speakerRadius, dotPaint)
            canvas.drawCircle(side * 0.5f, speakerY, speakerRadius, dotPaint)
            canvas.drawCircle(side * 0.5f + speakerSpacing, speakerY, speakerRadius, dotPaint)

            val eyeY = side * FaceGeometry.EYE_Y
            val eyeRadius = dotRadius * FaceGeometry.EYE_DOT_SCALE
            canvas.drawCircle(side * FaceGeometry.EYE_LEFT_X, eyeY, eyeRadius, dotPaint)
            canvas.drawCircle(side * FaceGeometry.EYE_RIGHT_X, eyeY, eyeRadius, dotPaint)

            // Nose — L shape: 4 dots down (top at eye level, between eyes) + 1 foot right
            val noseX = side * FaceGeometry.NOSE_X
            val noseBottomY = side * FaceGeometry.NOSE_BOTTOM_Y
            canvas.drawCircle(noseX, eyeY, dotRadius, dotPaint) // at eye row
            canvas.drawCircle(noseX, side * FaceGeometry.NOSE_2_Y, dotRadius, dotPaint)
            canvas.drawCircle(noseX, side * FaceGeometry.NOSE_3_Y, dotRadius, dotPaint)
            canvas.drawCircle(noseX, noseBottomY, dotRadius, dotPaint)
            canvas.drawCircle(side * FaceGeometry.NOSE_FOOT_X, noseBottomY, dotRadius, dotPaint)

            // Mouth — happy curves down = smile ∪, sad curves up = frown ∩
            val mouthY = side * FaceGeometry.MOUTH_Y
            val mouthWidth = side * FaceGeometry.MOUTH_WIDTH
            val lastDot = FaceGeometry.MOUTH_DOTS - 1
            repeat(FaceGeometry.MOUTH_DOTS) { index ->
                val t = index / lastDot.toFloat()
                val x = side / 2f - mouthWidth / 2f + t * mouthWidth
                val curve = sin(t * PI).toFloat() * side * FaceGeometry.MOUTH_CURVE
                val y = when (mood) {
                    // corners at mouthY, middle BELOW → smile ∪
                    UsageStatsHelper.Mood.HAPPY -> mouthY + curve
                    UsageStatsHelper.Mood.NEUTRAL, UsageStatsHelper.Mood.NO_ACCESS -> mouthY
                    // corners at mouthY, middle ABOVE → frown ∩
                    UsageStatsHelper.Mood.SAD -> mouthY - curve
                }
                canvas.drawCircle(x, y, dotRadius, dotPaint)
            }
            return bitmap
        }

        private fun drawDottedRoundRect(
            canvas: Canvas,
            paint: Paint,
            rect: RectF,
            cornerRadius: Float,
            dotRadius: Float,
            spacing: Float,
        ) {
            val path = Path().apply { addRoundRect(rect, cornerRadius, cornerRadius, Path.Direction.CW) }
            val measure = PathMeasure(path, false)
            val position = FloatArray(2)
            var distance = 0f
            while (distance < measure.length) {
                measure.getPosTan(distance, position, null)
                canvas.drawCircle(position[0], position[1], dotRadius, paint)
                distance += spacing
            }
        }
    }
}
