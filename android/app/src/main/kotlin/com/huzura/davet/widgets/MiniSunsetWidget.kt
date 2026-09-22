package com.huzura.davet.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.huzura.davet.R
import es.antonborri.home_widget.HomeWidgetPlugin

class MiniSunsetWidget : AppWidgetProvider() {
    
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
            val thisWidget = android.content.ComponentName(context, MiniSunsetWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }
    
    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            // Tüm vakit saatlerini al
            val imsak = widgetData.getString("imsak_saati", "05:30") ?: "05:30"
            val gunes = widgetData.getString("gunes_saati", "07:00") ?: "07:00"
            val ogle = widgetData.getString("ogle_saati", "12:30") ?: "12:30"
            val ikindi = widgetData.getString("ikindi_saati", "15:30") ?: "15:30"
            val aksam = widgetData.getString("aksam_saati", "18:00") ?: "18:00"
            val yatsi = widgetData.getString("yatsi_saati", "19:30") ?: "19:30"
            
            // Geri sayımı Android tarafında hesapla (uygulama kapalıyken de çalışır)
            val vakitBilgisi = WidgetUtils.hesaplaVakitBilgisi(imsak, gunes, ogle, ikindi, aksam, yatsi)
            val geriSayim = vakitBilgisi["geriSayim"] ?: "02:30:00"
            val mevcutSaat = vakitBilgisi["mevcutSaat"] ?: "05:30"
            val sonrakiSaat = vakitBilgisi["sonrakiSaat"] ?: "06:30"
            val ilerleme = vakitBilgisi["ilerleme"]?.toIntOrNull() ?: 0
            
            // Vakit isimlerini native hesaplamadan al, çeviriyi SharedPreferences'tan oku
            val sonrakiVakit = WidgetUtils.getTranslatedVakitAdi(widgetData, vakitBilgisi["sonrakiVakit"] ?: "Ogle")
            val mevcutVakit = WidgetUtils.getTranslatedVakitAdi(widgetData, vakitBilgisi["mevcutVakit"] ?: "Imsak")
            
            // Diğer bilgiler
            // Miladi tarihi native hesapla (Flutter kapalıyken de güncel kalır)
            val miladiTarih = WidgetUtils.getMiladiTarih(context)
            // Hicri tarihi native hesapla (Flutter kapalıyken de güncel kalır)
            val hicriTarih = WidgetUtils.getHicriTarih(context)
            val konum = widgetData.getString("konum", "İstanbul") ?: "İstanbul"

            
            // Önce widget'a özel ayarları kontrol et, yoksa varsayılanı kullan
            val gorunum = WidgetGorunum.coz(
                context, widgetData, appWidgetId,
                "mini_arkaplan_key", "sunset",
                "mini_yazi_rengi_hex", "664422"
            )
            val arkaPlanKey = gorunum.zeminAnahtari
            val yaziRengi = gorunum.yaziRengi
            val yaziRengiSecondary = Color.argb(180, Color.red(yaziRengi), Color.green(yaziRengi), Color.blue(yaziRengi))
            
            val views = RemoteViews(context.packageName, R.layout.widget_mini_sunset)


            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val compactMode = minHeight < 120

            views.setViewPadding(R.id.widget_root, 3, 3, 3, if (compactMode) 3 else 4)

            if (minWidth < 280 || compactMode) {
                views.setTextViewTextSize(R.id.tv_sonraki_label, TypedValue.COMPLEX_UNIT_SP, 9f)
                views.setTextViewTextSize(R.id.tv_countdown, TypedValue.COMPLEX_UNIT_SP, if (compactMode) 11f else 12f)
                views.setTextViewTextSize(R.id.tv_mevcut_vakit, TypedValue.COMPLEX_UNIT_SP, 10f)
                views.setTextViewTextSize(R.id.tv_sonraki_vakit, TypedValue.COMPLEX_UNIT_SP, 10f)

                views.setViewVisibility(R.id.tv_mevcut_vakit, if (compactMode) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.tv_sonraki_vakit, if (compactMode) View.GONE else View.VISIBLE)
            } else {
                views.setTextViewTextSize(R.id.tv_sonraki_label, TypedValue.COMPLEX_UNIT_SP, 12f)
                views.setTextViewTextSize(R.id.tv_countdown, TypedValue.COMPLEX_UNIT_SP, 15f)
                views.setTextViewTextSize(R.id.tv_mevcut_vakit, TypedValue.COMPLEX_UNIT_SP, 11f)
                views.setTextViewTextSize(R.id.tv_sonraki_vakit, TypedValue.COMPLEX_UNIT_SP, 11f)

                views.setViewVisibility(R.id.tv_mevcut_vakit, View.VISIBLE)
                views.setViewVisibility(R.id.tv_sonraki_vakit, View.VISIBLE)
            }
            
            views.setInt(R.id.widget_root, "setBackgroundResource", gorunum.zeminKaynagi)
            
            // Konum ve tarih
            val sehir = konum.split("/").firstOrNull()?.trim() ?: konum
            views.setTextViewText(R.id.tv_location, "$sehir, ${konum.split("/").getOrNull(1)?.trim() ?: ""}".trim().trimEnd(','))
            views.setTextViewText(R.id.tv_date, "$hicriTarih • $miladiTarih")
            views.setTextColor(R.id.tv_location, yaziRengi)
            views.setTextColor(R.id.tv_date, yaziRengiSecondary)

            // Geri sayım ve başlık
            WidgetUtils.applyCountdown(views, R.id.tv_countdown, geriSayim)
            views.setTextColor(R.id.tv_countdown, yaziRengi)
            views.setTextViewText(R.id.tv_sonraki_label, "$sonrakiVakit Vaktine Kalan")
            views.setTextColor(R.id.tv_sonraki_label, yaziRengiSecondary)

            // İlerleme ve ECİR - widget yazı rengiyle aynı renk kullan
            views.setProgressBar(R.id.progress_vakit, 100, ilerleme, false)
            views.setTextViewText(R.id.tv_ecir_percent, "$ilerleme%")
            views.setTextColor(R.id.tv_ecir_label, yaziRengi)
            views.setTextColor(R.id.tv_ecir_percent, yaziRengi)

            // Alt bilgi
            views.setTextViewText(R.id.tv_mevcut_vakit, "$mevcutVakit ($mevcutSaat)")
            views.setTextViewText(R.id.tv_sonraki_vakit, "$sonrakiVakit ($sonrakiSaat)")
            views.setTextColor(R.id.tv_mevcut_vakit, yaziRengi)
            views.setTextColor(R.id.tv_sonraki_vakit, yaziRengi)

            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
