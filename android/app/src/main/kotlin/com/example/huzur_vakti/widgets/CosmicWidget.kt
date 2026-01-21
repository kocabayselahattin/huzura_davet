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
 * 🌌 Cosmic Galaxy Widget - Uzayın derinliklerinden ilham alan tasarım
 * Nebula, yıldız tozu ve galaktik renklerle büyüleyici bir deneyim
 */
class CosmicWidget : AppWidgetProvider() {
    
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
            val thisWidget = android.content.ComponentName(context, CosmicWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
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
            
            val views = RemoteViews(context.packageName, R.layout.widget_cosmic)
            
            // Galaktik renkler
            val cosmicPink = Color.parseColor("#E040FB")
            val cosmicCyan = Color.parseColor("#00BCD4")
            val cosmicPurple = Color.parseColor("#7C4DFF")
            val beyaz = Color.WHITE
            
            // Verileri set et
            views.setTextViewText(R.id.tv_konum, konum)
            views.setTextColor(R.id.tv_konum, cosmicPink)
            
            views.setTextViewText(R.id.tv_hicri, hicriTarih)
            
            views.setTextViewText(R.id.tv_mevcut_vakit, "✦ $mevcutVakit ✦")
            views.setTextColor(R.id.tv_mevcut_vakit, cosmicPurple)
            
            WidgetUtils.applyCountdown(views, R.id.tv_geri_sayim, geriSayim)
            views.setTextColor(R.id.tv_geri_sayim, beyaz)
            
            views.setTextViewText(R.id.tv_sonraki_vakit, "$sonrakiVakit galaksisine")
            views.setTextColor(R.id.tv_sonraki_vakit, cosmicCyan)
            
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
