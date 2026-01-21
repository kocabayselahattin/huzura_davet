package com.example.huzur_vakti.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.example.huzur_vakti.MainActivity
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object WidgetUtils {
    
    // Vakit isimleri sırası
    private val vakitSirasi = listOf("Imsak", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi")
    
    /**
     * Vakit saatlerinden geri sayım hesapla
     * @return Map içinde: sonrakiVakit, sonrakiSaat, mevcutVakit, mevcutSaat, geriSayim, ilerleme
     */
    fun hesaplaVakitBilgisi(
        imsak: String,
        gunes: String,
        ogle: String,
        ikindi: String,
        aksam: String,
        yatsi: String
    ): Map<String, String> {
        val now = Calendar.getInstance()
        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
        
        val vakitler = mapOf(
            "Imsak" to imsak,
            "Gunes" to gunes,
            "Ogle" to ogle,
            "Ikindi" to ikindi,
            "Aksam" to aksam,
            "Yatsi" to yatsi
        )
        
        // Her vakit için Calendar objesi oluştur
        val vakitCalendars = vakitler.map { (isim, saat) ->
            val parts = saat.split(":")
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, parts.getOrNull(0)?.toIntOrNull() ?: 0)
                set(Calendar.MINUTE, parts.getOrNull(1)?.toIntOrNull() ?: 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            isim to cal
        }
        
        // Sonraki vakti bul
        var sonrakiVakitIndex = -1
        for (i in vakitSirasi.indices) {
            val vakitAdi = vakitSirasi[i]
            val vakitCal = vakitCalendars.find { it.first == vakitAdi }?.second ?: continue
            if (now.before(vakitCal)) {
                sonrakiVakitIndex = i
                break
            }
        }
        
        // Eğer tüm vakitler geçtiyse, yarının imsak vakti
        val sonrakiVakit: String
        val sonrakiSaat: String
        val mevcutVakit: String
        val mevcutSaat: String
        val sonrakiVakitCal: Calendar
        val mevcutVakitCal: Calendar
        
        if (sonrakiVakitIndex == -1) {
            // Gece yarısından sonra, yarının imsak vaktine kadar
            sonrakiVakit = "Imsak"
            sonrakiSaat = imsak
            mevcutVakit = "Yatsı"
            mevcutSaat = yatsi
            
            sonrakiVakitCal = Calendar.getInstance().apply {
                val parts = imsak.split(":")
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, parts.getOrNull(0)?.toIntOrNull() ?: 5)
                set(Calendar.MINUTE, parts.getOrNull(1)?.toIntOrNull() ?: 30)
                set(Calendar.SECOND, 0)
            }
            mevcutVakitCal = vakitCalendars.find { it.first == "Yatsi" }?.second ?: now
        } else if (sonrakiVakitIndex == 0) {
            // İmsak'tan önce (gece)
            sonrakiVakit = "Imsak"
            sonrakiSaat = imsak
            mevcutVakit = "Yatsı"
            mevcutSaat = yatsi
            
            sonrakiVakitCal = vakitCalendars.find { it.first == "Imsak" }?.second ?: now
            mevcutVakitCal = Calendar.getInstance().apply {
                val parts = yatsi.split(":")
                add(Calendar.DAY_OF_YEAR, -1)
                set(Calendar.HOUR_OF_DAY, parts.getOrNull(0)?.toIntOrNull() ?: 19)
                set(Calendar.MINUTE, parts.getOrNull(1)?.toIntOrNull() ?: 30)
                set(Calendar.SECOND, 0)
            }
        } else {
            sonrakiVakit = vakitSirasi[sonrakiVakitIndex]
            sonrakiSaat = vakitler[sonrakiVakit] ?: ""
            mevcutVakit = vakitSirasi[sonrakiVakitIndex - 1]
            mevcutSaat = vakitler[mevcutVakit] ?: ""
            
            sonrakiVakitCal = vakitCalendars.find { it.first == sonrakiVakit }?.second ?: now
            mevcutVakitCal = vakitCalendars.find { it.first == mevcutVakit }?.second ?: now
        }
        
        // Geri sayım hesapla (saniye dahil - Flutter ile senkron)
        val kalanMs = sonrakiVakitCal.timeInMillis - now.timeInMillis
        val kalanSaat = (kalanMs / (1000 * 60 * 60)).toInt()
        val kalanDakika = ((kalanMs / (1000 * 60)) % 60).toInt()
        val kalanSaniye = ((kalanMs / 1000) % 60).toInt()
        
        // HH:mm:ss formatı (Flutter ile aynı)
        val geriSayim = String.format("%02d:%02d:%02d", kalanSaat, kalanDakika, kalanSaniye)
        
        // İlerleme hesapla
        val toplamMs = sonrakiVakitCal.timeInMillis - mevcutVakitCal.timeInMillis
        val gecenMs = now.timeInMillis - mevcutVakitCal.timeInMillis
        val ilerleme = if (toplamMs > 0) ((gecenMs.toDouble() / toplamMs) * 100).toInt().coerceIn(0, 100) else 0
        
        // Vakit isimlerini Türkçeleştir
        val sonrakiVakitTr = when (sonrakiVakit) {
            "Imsak" -> "İmsak"
            "Gunes" -> "Güneş"
            "Ogle" -> "Öğle"
            "Ikindi" -> "İkindi"
            "Aksam" -> "Akşam"
            "Yatsi" -> "Yatsı"
            else -> sonrakiVakit
        }
        
        val mevcutVakitTr = when (mevcutVakit) {
            "Imsak" -> "İmsak"
            "Gunes" -> "Güneş"
            "Ogle" -> "Öğle"
            "Ikindi" -> "İkindi"
            "Aksam" -> "Akşam"
            "Yatsi" -> "Yatsı"
            else -> mevcutVakit
        }
        
        return mapOf(
            "sonrakiVakit" to sonrakiVakitTr,
            "sonrakiSaat" to sonrakiSaat,
            "mevcutVakit" to mevcutVakitTr,
            "mevcutSaat" to mevcutSaat,
            "geriSayim" to geriSayim,
            "ilerleme" to ilerleme.toString()
        )
    }
    
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
