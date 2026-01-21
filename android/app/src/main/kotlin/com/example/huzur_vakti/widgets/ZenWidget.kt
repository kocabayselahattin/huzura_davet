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
 * Zen Widget - Minimalist ve huzur verici tasarım
 * Beyaz arka plan, ince çizgiler, zarif tipografi
 */
class ZenWidget : AppWidgetProvider() {
    
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
            val thisWidget = android.content.ComponentName(context, ZenWidget::class.java)
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
            val ilerleme = vakitBilgisi["ilerleme"]?.toIntOrNull() ?: 50
            
            val konum = widgetData.getString("konum", "İstanbul") ?: "İstanbul"
            val sehir = konum.split("/").firstOrNull()?.trim()?.uppercase() ?: konum.uppercase()
            
            val views = RemoteViews(context.packageName, R.layout.widget_zen)
            
            // Zen temalı renkler (sabit - minimalist)
            val koyu = Color.parseColor("#212121")
            val gri = Color.parseColor("#9E9E9E")
            val mavi = Color.parseColor("#2196F3")
            
            // Verileri set et
            views.setTextViewText(R.id.tv_konum, sehir)
            views.setTextColor(R.id.tv_konum, gri)
            
            // Geri sayımı kısa format yap (sadece saat:dakika)
            val kisaGeriSayim = geriSayim.split(":").take(2).joinToString(":")
            WidgetUtils.applyCountdown(views, R.id.tv_geri_sayim, kisaGeriSayim)
            views.setTextColor(R.id.tv_geri_sayim, koyu)
            
            views.setTextViewText(R.id.tv_sonraki_vakit, sonrakiVakit)
            views.setTextColor(R.id.tv_sonraki_vakit, mavi)
            
            // Ecir barını güncelle
            views.setProgressBar(R.id.progress_ecir, 100, ilerleme, false)
            
            // Tıklama olayı
            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
