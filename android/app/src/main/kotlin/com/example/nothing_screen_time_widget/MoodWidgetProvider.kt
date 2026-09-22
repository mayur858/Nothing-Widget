package com.example.nothing_screen_time_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.PI
import kotlin.math.sin

class MoodWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { id -> updateOne(context, appWidgetManager, id) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MoodWidgetProvider::class.java))
            ids.forEach { id -> updateOne(context, manager, id) }
        }

        private fun updateOne(context: Context, manager: AppWidgetManager, id: Int) {
            val preferences = HomeWidgetPlugin.getData(context)
            val happyLimit = preferences.getDouble("happyLimitHours", 2.0)
            val sadLimit = preferences.getDouble("sadLimitHours", 4.0)
            val mood = UsageStatsHelper.moodFor(
                UsageStatsHelper.getScreenOnMillisToday(context),
                happyLimit,
                sadLimit,
            )

            val views = RemoteViews(context.packageName, R.layout.mood_widget).apply {
                setImageViewBitmap(R.id.widget_image, drawFace(mood))

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

        private fun colorFor(mood: UsageStatsHelper.Mood): Int = when (mood) {
            UsageStatsHelper.Mood.HAPPY -> Color.parseColor("#00B050")   // contrast green on white
            UsageStatsHelper.Mood.NEUTRAL -> Color.parseColor("#D97706") // contrast amber on white
            UsageStatsHelper.Mood.SAD -> Color.parseColor("#FF5252")     // bright red on black
        }

        /**
         * A compact Nothing-inspired dot face:
         * - Happy (green) & Neutral (yellow): White background card with subtle border.
         * - Sad (red): Black background card.
         */
        private fun drawFace(mood: UsageStatsHelper.Mood, size: Int = 360): Bitmap {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val isSad = mood == UsageStatsHelper.Mood.SAD
            val panelColor = Color.parseColor("#171A1D")
            val panelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = panelColor }
            val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colorFor(mood) }
            val side = size.toFloat()
            val dotRadius = side * 0.0115f

            canvas.drawRoundRect(
                RectF(0f, 0f, side, side),
                side * 0.135f,
                side * 0.135f,
                panelPaint,
            )

            // Draw subtle border around white card for happy and neutral modes
            if (!isSad) {
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#E5E7EB")
                    style = Paint.Style.STROKE
                    strokeWidth = side * 0.008f
                }
                canvas.drawRoundRect(
                    RectF(side * 0.004f, side * 0.004f, side * 0.996f, side * 0.996f),
                    side * 0.135f,
                    side * 0.135f,
                    borderPaint,
                )
            }

            val outline = RectF(side * 0.355f, side * 0.245f, side * 0.645f, side * 0.755f)
            drawDottedRoundRect(canvas, dotPaint, outline, side * 0.04f, dotRadius, side * 0.033f)

            // Speaker grill at the top inside the phone outline
            val speakerY = side * 0.285f
            val speakerSpacing = side * 0.024f
            canvas.drawCircle(side * 0.5f - speakerSpacing, speakerY, dotRadius * 0.95f, dotPaint)
            canvas.drawCircle(side * 0.5f,                  speakerY, dotRadius * 0.95f, dotPaint)
            canvas.drawCircle(side * 0.5f + speakerSpacing, speakerY, dotRadius * 0.95f, dotPaint)

            val eyeY = side * 0.465f
            canvas.drawCircle(side * 0.455f, eyeY, dotRadius * 1.12f, dotPaint)
            canvas.drawCircle(side * 0.545f, eyeY, dotRadius * 1.12f, dotPaint)

            // Nose — L shape: 4 dots down (top at eye level, between eyes) + 1 foot right
            val noseX     = side * 0.488f   // between left eye (45.5%) and centre
            val nose2Y    = side * 0.493f
            val nose3Y    = side * 0.521f
            val noseBotY  = side * 0.549f   // corner
            val noseFoot  = side * 0.516f   // one dot to the right
            canvas.drawCircle(noseX,    eyeY,    dotRadius, dotPaint) // at eye row
            canvas.drawCircle(noseX,    nose2Y,  dotRadius, dotPaint)
            canvas.drawCircle(noseX,    nose3Y,  dotRadius, dotPaint)
            canvas.drawCircle(noseX,    noseBotY,dotRadius, dotPaint)
            canvas.drawCircle(noseFoot, noseBotY,dotRadius, dotPaint)

            val mouthY = side * 0.615f
            val mouthWidth = side * 0.145f
            repeat(5) { index ->
                val t = index / 4f
                val x = side / 2f - mouthWidth / 2f + t * mouthWidth
                val curve = sin(t * PI).toFloat() * side * 0.025f
                val y = when (mood) {
                    // happy → corners at mouthY, middle BELOW → smile ∪
                    UsageStatsHelper.Mood.HAPPY   -> mouthY + curve
                    UsageStatsHelper.Mood.NEUTRAL -> mouthY
                    // sad   → corners at mouthY, middle ABOVE → frown ∩
                    UsageStatsHelper.Mood.SAD     -> mouthY - curve
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
