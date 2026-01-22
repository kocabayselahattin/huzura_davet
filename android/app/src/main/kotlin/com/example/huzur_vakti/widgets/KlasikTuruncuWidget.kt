package com.example.huzur_vakti.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import com.example.huzur_vakti.R
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.*

class KlasikTuruncuWidget : AppWidgetProvider() {
    
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
            val thisWidget = android.content.ComponentName(context, KlasikTuruncuWidget::class.java)
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
            
            // Vakit saatlerini al
            val imsak = widgetData.getString("imsak_saati", "05:30") ?: "05:30"
            val gunes = widgetData.getString("gunes_saati", "07:00") ?: "07:00"
            val ogle = widgetData.getString("ogle_saati", "12:30") ?: "12:30"
            val ikindi = widgetData.getString("ikindi_saati", "15:30") ?: "15:30"
            val aksam = widgetData.getString("aksam_saati", "18:00") ?: "18:00"
            val yatsi = widgetData.getString("yatsi_saati", "19:30") ?: "19:30"
            
            // Geri sayımı Android tarafında hesapla (uygulama kapalıyken de çalışır)
            val vakitBilgisi = WidgetUtils.hesaplaVakitBilgisi(imsak, gunes, ogle, ikindi, aksam, yatsi)
            val geriSayim = vakitBilgisi["geriSayim"] ?: "02:30:00"
            
            // Flutter'dan gelen çevirilmiş vakit isimlerini kullan
            val sonrakiVakit = widgetData.getString("sonraki_vakit", null) ?: vakitBilgisi["sonrakiVakit"] ?: "Öğle"
            val mevcutVakit = widgetData.getString("mevcut_vakit", null) ?: vakitBilgisi["mevcutVakit"] ?: "İmsak"
            
            val hicriTarih = widgetData.getString("hicri_tarih", "1 Muharrem 1447") ?: "1 Muharrem 1447"
            val konum = widgetData.getString("konum", "İSTANBUL") ?: "İSTANBUL"

            
            // Renk ayarlarını al
            val arkaPlanKey = widgetData.getString("arkaplan_key", "orange") ?: "orange"
            val yaziRengiHex = widgetData.getString("yazi_rengi_hex", "FFFFFF") ?: "FFFFFF"
            val yaziRengi = WidgetUtils.parseColorSafe(yaziRengiHex, Color.WHITE)
            val yaziRengiSecondary = Color.argb(180, Color.red(yaziRengi), Color.green(yaziRengi), Color.blue(yaziRengi))
            
            val views = RemoteViews(context.packageName, R.layout.widget_klasik_turuncu)


            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            if (minWidth < 260 || minHeight < 120) {
                views.setTextViewTextSize(R.id.tv_countdown, TypedValue.COMPLEX_UNIT_SP, 28f)
                views.setTextViewTextSize(R.id.tv_sonraki_vakit_adi, TypedValue.COMPLEX_UNIT_SP, 9f)
                views.setTextViewTextSize(R.id.tv_hicri_tarih, TypedValue.COMPLEX_UNIT_SP, 9f)
                views.setTextViewTextSize(R.id.tv_konum, TypedValue.COMPLEX_UNIT_SP, 9f)
            } else {
                views.setTextViewTextSize(R.id.tv_countdown, TypedValue.COMPLEX_UNIT_SP, 36f)
                views.setTextViewTextSize(R.id.tv_sonraki_vakit_adi, TypedValue.COMPLEX_UNIT_SP, 10f)
                views.setTextViewTextSize(R.id.tv_hicri_tarih, TypedValue.COMPLEX_UNIT_SP, 11f)
                views.setTextViewTextSize(R.id.tv_konum, TypedValue.COMPLEX_UNIT_SP, 10f)
            }
            
            // Arka plan ayarla
            val bgDrawable = when(arkaPlanKey) {
                "orange" -> R.drawable.widget_bg_orange
                "light" -> R.drawable.widget_bg_light
                "dark" -> R.drawable.widget_bg_dark_mosque
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
                else -> R.drawable.widget_bg_orange
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", bgDrawable)
            
            // Vakit saatlerini ayarla (renk ile)
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
            
            // Geri sayım ve bilgiler (renk ile)
            WidgetUtils.applyCountdown(views, R.id.tv_countdown, geriSayim)
            views.setTextColor(R.id.tv_countdown, yaziRengi)
            views.setTextViewText(R.id.tv_sonraki_vakit_adi, "$sonrakiVakit Vaktine Kalan Süre")
            views.setTextColor(R.id.tv_sonraki_vakit_adi, yaziRengiSecondary)
            views.setTextViewText(R.id.tv_hicri_tarih, hicriTarih)
            views.setTextColor(R.id.tv_hicri_tarih, yaziRengiSecondary)
            views.setTextViewText(R.id.tv_konum, konum.uppercase())
            views.setTextColor(R.id.tv_konum, yaziRengi)

            views.setOnClickPendingIntent(R.id.widget_root, WidgetUtils.createLaunchPendingIntent(context))
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
