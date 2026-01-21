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
 * Circular Progress Widget - Dairesel ecir göstergesi ile modern tasarım
 * Merkezi dairesel progress bar ile vaktin ilerleme yüzdesini gösterir
 */
class CircularProgressWidget : AppWidgetProvider() {
    
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
            val thisWidget = android.content.ComponentName(context, CircularProgressWidget::class.java)
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
            
            // Renk ayarlarını al
            val arkaPlanKey = widgetData.getString("arkaplan_key", "teal") ?: "teal"
            val yaziRengiHex = widgetData.getString("yazi_rengi_hex", "FFFFFF") ?: "FFFFFF"
            val yaziRengi = WidgetUtils.parseColorSafe(yaziRengiHex, Color.WHITE)
            val yaziRengiSecondary = Color.argb(180, Color.red(yaziRengi), Color.green(yaziRengi), Color.blue(yaziRengi))
            
            val views = RemoteViews(context.packageName, R.layout.widget_circular_progress)
            
            // Arka plan ayarla
            val bgDrawable = when(arkaPlanKey) {
                "orange" -> R.drawable.widget_bg_orange
                "light" -> R.drawable.widget_bg_card_light
                "dark" -> R.drawable.widget_bg_card_dark
                "sunset" -> R.drawable.widget_bg_sunset
                "green" -> R.drawable.widget_bg_green
                "purple" -> R.drawable.widget_bg_purple
                "red" -> R.drawable.widget_bg_red
                "blue" -> R.drawable.widget_bg_blue
                "teal" -> R.drawable.widget_bg_teal
                "pink" -> R.drawable.widget_bg_pink
                "transparent" -> R.drawable.widget_bg_transparent
                "semi_black" -> R.drawable.widget_bg_semi_black
                "semi_white" -> R.drawable.widget_bg_semi_white
                else -> R.drawable.widget_bg_teal
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", bgDrawable)
            
            // Verileri set et
            views.setTextViewText(R.id.tv_sonraki_vakit, sonrakiVakit)
            views.setTextColor(R.id.tv_sonraki_vakit, yaziRengi)
            
            WidgetUtils.applyCountdown(views, R.id.tv_geri_sayim, geriSayim)
            views.setTextColor(R.id.tv_geri_sayim, yaziRengi)
            
            views.setTextViewText(R.id.tv_mevcut_vakit, mevcutVakit)
            views.setTextColor(R.id.tv_mevcut_vakit, yaziRengiSecondary)
            
            views.setTextViewText(R.id.tv_konum, konum)
            views.setTextColor(R.id.tv_konum, yaziRengiSecondary)
            
            views.setTextViewText(R.id.tv_hicri, hicriTarih)
            views.setTextColor(R.id.tv_hicri, yaziRengiSecondary)
            
            views.setTextViewText(R.id.tv_progress_percent, "%$ilerleme")
            views.setTextColor(R.id.tv_progress_percent, yaziRengi)
            
            // Dairesel progress bar
            views.setProgressBar(R.id.progress_circular, 100, ilerleme, false)
            
            // Alt ecir barı
            views.setProgressBar(R.id.progress_bottom_ecir, 100, ilerleme, false)
            
            // Tıklama olayı
            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
