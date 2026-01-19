package com.example.huzur_vakti.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.example.huzur_vakti.MainActivity

object WidgetUtils {
    fun parseColorSafe(hex: String?, defaultColor: Int): Int {
        if (hex.isNullOrBlank()) {
            return defaultColor
        }
        val cleaned = hex.trim()
            .removePrefix("#")
            .removePrefix("0x")
            .removePrefix("0X")

        if (cleaned.length != 6 && cleaned.length != 8) {
            return defaultColor
        }

        return try {
            Color.parseColor("#$cleaned")
        } catch (_: IllegalArgumentException) {
            defaultColor
        }
    }

    fun createLaunchPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun applyCountdown(views: RemoteViews, viewId: Int, remaining: String) {
        // Chronometer widget update'lerinde sürekli reset oluyor
        // Basit TextView kullan - her 5 saniyede güncellenir
        views.setTextViewText(viewId, remaining)
    }

    fun applyFontStyle(views: RemoteViews, styleRes: Int, vararg viewIds: Int) {
        for (viewId in viewIds) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    views.setInt(viewId, "setTextAppearance", styleRes)
                }
            } catch (_: Throwable) {
                // Ignore font styling failures to avoid widget inflate errors.
            }
        }
    }
}
