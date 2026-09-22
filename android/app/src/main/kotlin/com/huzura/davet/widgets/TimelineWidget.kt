package com.huzura.davet.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import com.huzura.davet.R
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Timeline Widget - Dikey timeline görünümü ile tüm vakitleri gösteren tasarım
 * Her vakit için ecir barı ile ilerleme göstergesi
 */
class TimelineWidget : AppWidgetProvider() {
    
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
            intent.action == "com.huzura.davet.UPDATE_WIDGETS") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = android.content.ComponentName(context, TimelineWidget::class.java)
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
            val geriSayim = vakitBilgisi["geriSayim"] ?: "02:30:00"
            val ilerleme = vakitBilgisi["ilerleme"]?.toIntOrNull() ?: 50
            
            // Vakit isimlerini native hesaplamadan al, çeviriyi SharedPreferences'tan oku
            val sonrakiVakit = WidgetUtils.getTranslatedVakitAdi(widgetData, vakitBilgisi["sonrakiVakit"] ?: "Ogle")
            val mevcutVakit = WidgetUtils.getTranslatedVakitAdi(widgetData, vakitBilgisi["mevcutVakit"] ?: "Gunes")
            
            val konum = widgetData.getString("konum", "İstanbul") ?: "İstanbul"
            // Hicri tarihi native hesapla (Flutter kapalıyken de güncel kalır)
            val hicriTarih = WidgetUtils.getHicriTarih(context)
            // Miladi tarihi native hesapla (Flutter kapalıyken de güncel kalır)
            val miladiTarih = WidgetUtils.getMiladiTarih(context)
            
            // Önce widget'a özel ayarları kontrol et, yoksa varsayılanı kullan
            val gorunum = WidgetGorunum.coz(
                context, widgetData, appWidgetId,
                "timeline_arkaplan_key", "dark",
                "timeline_yazi_rengi_hex", "FFFFFF"
            )
            val arkaPlanKey = gorunum.zeminAnahtari
            val yaziRengi = gorunum.yaziRengi
            val yaziRengiSecondary = Color.argb(180, Color.red(yaziRengi), Color.green(yaziRengi), Color.blue(yaziRengi))
            
            val views = RemoteViews(context.packageName, R.layout.widget_timeline)
            
            views.setInt(R.id.widget_root, "setBackgroundResource", gorunum.zeminKaynagi)
            
            // Başlık bilgileri
            views.setTextViewText(R.id.tv_konum, konum)
            views.setTextColor(R.id.tv_konum, yaziRengi)
            views.setTextViewText(R.id.tv_hicri, hicriTarih)
            views.setTextColor(R.id.tv_hicri, yaziRengiSecondary)
            
            // Miladi tarih
            views.setTextViewText(R.id.tv_miladi, miladiTarih)
            views.setTextColor(R.id.tv_miladi, yaziRengiSecondary)
            
            // Ana geri sayım
            views.setTextViewText(R.id.tv_sonraki_vakit, "$sonrakiVakit'e")
            views.setTextColor(R.id.tv_sonraki_vakit, yaziRengi)
            WidgetUtils.applyCountdown(views, R.id.tv_geri_sayim, geriSayim)
            views.setTextColor(R.id.tv_geri_sayim, yaziRengi)
            
            // Vakit saatlerini güncelle (mevcut vakti vurgula)
            val imsakColor = if (mevcutVakit == "İmsak") yaziRengi else yaziRengiSecondary
            val gunesColor = if (mevcutVakit == "Güneş") yaziRengi else yaziRengiSecondary
            val ogleColor = if (mevcutVakit == "Öğle") yaziRengi else yaziRengiSecondary
            val ikindiColor = if (mevcutVakit == "İkindi") yaziRengi else yaziRengiSecondary
            val aksamColor = if (mevcutVakit == "Akşam") yaziRengi else yaziRengiSecondary
            val yatsiColor = if (mevcutVakit == "Yatsı") yaziRengi else yaziRengiSecondary
            
            views.setTextViewText(R.id.tv_imsak, imsak)
            views.setTextColor(R.id.tv_imsak, imsakColor)
            views.setTextViewText(R.id.tv_gunes, gunes)
            views.setTextColor(R.id.tv_gunes, gunesColor)
            views.setTextViewText(R.id.tv_ogle, ogle)
            views.setTextColor(R.id.tv_ogle, ogleColor)
            views.setTextViewText(R.id.tv_ikindi, ikindi)
            views.setTextColor(R.id.tv_ikindi, ikindiColor)
            views.setTextViewText(R.id.tv_aksam, aksam)
            views.setTextColor(R.id.tv_aksam, aksamColor)
            views.setTextViewText(R.id.tv_yatsi, yatsi)
            views.setTextColor(R.id.tv_yatsi, yatsiColor)
            
            // Label renkleri
            views.setTextColor(R.id.tv_imsak_label, imsakColor)
            views.setTextColor(R.id.tv_gunes_label, gunesColor)
            views.setTextColor(R.id.tv_ogle_label, ogleColor)
            views.setTextColor(R.id.tv_ikindi_label, ikindiColor)
            views.setTextColor(R.id.tv_aksam_label, aksamColor)
            views.setTextColor(R.id.tv_yatsi_label, yatsiColor)
            
            // Ana ecir barını güncelle
            views.setProgressBar(R.id.progress_main_ecir, 100, ilerleme, false)
            
            // Tıklama olayı
            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
