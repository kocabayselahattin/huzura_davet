package com.example.huzur_vakti.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import com.example.huzur_vakti.R
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 📜 Origami Paper Widget - Japon kağıt sanatından ilham
 * Minimalist, zarif ve wabi-sabi estetikli tasarım
 */
class OrigamiWidget : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == "com.example.huzur_vakti.UPDATE_WIDGETS") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = android.content.ComponentName(context, OrigamiWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        // Arapça rakam dönüştürücü
        private fun toArabicNumerals(text: String): String {
            val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
            val sb = StringBuilder()
            for (c in text) {
                if (c.isDigit()) {
                    sb.append(arabicDigits[c.toString().toInt()])
                } else {
                    sb.append(c)
                }
            }
            return sb.toString()
        }
        
        // Hicri ay isimlerini Arapça'ya çevir
        private fun toArabicHicri(hicri: String): String {
            val aylar = mapOf(
                "Muharrem" to "محرم",
                "Safer" to "صفر",
                "Rebiülevvel" to "ربيع الأول",
                "Rebiülahir" to "ربيع الآخر",
                "Cemaziyelevvel" to "جمادى الأولى",
                "Cemaziyelahir" to "جمادى الآخرة",
                "Recep" to "رجب",
                "Şaban" to "شعبان",
                "Ramazan" to "رمضان",
                "Şevval" to "شوال",
                "Zilkade" to "ذو القعدة",
                "Zilhicce" to "ذو الحجة"
            )
            
            var result = hicri
            for ((tr, ar) in aylar) {
                result = result.replace(tr, ar, ignoreCase = true)
            }
            return toArabicNumerals(result)
        }

        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            // Vakit saatlerini al
            val imsak = widgetData.getString("imsak_saati", "05:30") ?: "05:30"
            val gunes = widgetData.getString("gunes_saati", "07:00") ?: "07:00"
            val ogle = widgetData.getString("ogle_saati", "12:30") ?: "12:30"
            val ikindi = widgetData.getString("ikindi_saati", "15:30") ?: "15:30"
            val aksam = widgetData.getString("aksam_saati", "18:00") ?: "18:00"
            val yatsi = widgetData.getString("yatsi_saati", "19:30") ?: "19:30"
            
            // Geri sayımı Android tarafında hesapla
            val vakitBilgisi = WidgetUtils.hesaplaVakitBilgisi(imsak, gunes, ogle, ikindi, aksam, yatsi)
            val sonrakiVakit = vakitBilgisi["sonrakiVakit"] ?: "Öğle"
            val geriSayim = vakitBilgisi["geriSayim"] ?: "02:30:00"
            val mevcutVakit = vakitBilgisi["mevcutVakit"] ?: "Güneş"
            val ilerleme = vakitBilgisi["ilerleme"]?.toIntOrNull() ?: 50
            
            val konum = widgetData.getString("konum", "İstanbul") ?: "İstanbul"
            val hicriTarih = widgetData.getString("hicri_tarih", "28 Recep 1447") ?: "28 Recep 1447"
            
            val views = RemoteViews(context.packageName, R.layout.widget_origami)
            
            // Origami renkleri - mürekkep tarzı
            val murekkep = Color.parseColor("#2D3436")
            val murekkepLight = Color.parseColor("#636E72")
            
            // Verileri set et
            views.setTextViewText(R.id.tv_konum, konum)
            views.setTextColor(R.id.tv_konum, murekkep)
            
            // Hicri tarihi Arapça olarak göster
            views.setTextViewText(R.id.tv_hicri, toArabicHicri(hicriTarih))
            views.setTextColor(R.id.tv_hicri, murekkepLight)
            
            views.setTextViewText(R.id.tv_mevcut_vakit, "$mevcutVakit Vakti")
            views.setTextColor(R.id.tv_mevcut_vakit, murekkepLight)
            
            WidgetUtils.applyCountdown(views, R.id.tv_geri_sayim, geriSayim)
            views.setTextColor(R.id.tv_geri_sayim, murekkep)
            
            views.setTextViewText(R.id.tv_sonraki_vakit, "${sonrakiVakit.lowercase()} vaktine")
            views.setTextColor(R.id.tv_sonraki_vakit, murekkepLight)
            
            // Progress bar
            views.setProgressBar(R.id.progress_ecir, 100, ilerleme, false)
            
            // Vakit saatlerini güncelle
            views.setTextViewText(R.id.tv_imsak, imsak)
            views.setTextViewText(R.id.tv_gunes, gunes)
            views.setTextViewText(R.id.tv_ogle, ogle)
            views.setTextViewText(R.id.tv_ikindi, ikindi)
            views.setTextViewText(R.id.tv_aksam, aksam)
            views.setTextViewText(R.id.tv_yatsi, yatsi)
            
            // Tıklama olayı
            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
