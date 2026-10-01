package com.huzura.davet.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color

/**
 * Widget'in zemin ve saydamlik ayarlarini cozer.
 *
 * Ayar sirasi: once widget ornegine ozel (widget eklenirken acilan
 * yapilandirma ekraninda secilen), yoksa widget tipine ozel (uygulama icindeki
 * Widget Ayarlari sayfasi), o da yoksa tasarimin varsayilani. Boylece daha once
 * eklenmis widget'lar hicbir sey degismeden calismaya devam eder.
 *
 * Ornege ozel ayar varken yazi rengi zemine gore otomatik secilir; koyu zeminde
 * acik, acik zeminde koyu yazi kullanilir.
 */
object WidgetGorunum {
    private const val AYAR_DOSYASI = "huzura_widget_gorunum"
    private const val ZEMIN_ONEKI = "zemin_"
    private const val SAYDAMLIK_ONEKI = "saydamlik_"

    private const val ACIK_ZEMIN_YAZISI = "#212121"
    private const val KOYU_ZEMIN_YAZISI = "#FFFFFF"

    /** Ikincil yazilarin (sehir, tarih) ana yaziya gore saydamligi. */
    private const val IKINCIL_ALFA = 180

    /**
     * Bir widget orneginin gorunumu.
     *
     * [ozelAyarVar] false ise kullanici bu ornek icin bir sey secmemistir;
     * widget kendi eski renk mantigini surdurur.
     */
    data class Gorunum(
        val zeminAnahtari: String,
        val saydamlik: Int,
        val zeminKaynagi: Int,
        val yaziRengi: Int,
        val ikincilYaziRengi: Int,
        val ozelAyarVar: Boolean
    )

    private fun ayarlar(context: Context): SharedPreferences =
        context.getSharedPreferences(AYAR_DOSYASI, Context.MODE_PRIVATE)

    fun kaydet(context: Context, appWidgetId: Int, zemin: String, saydamlik: Int) {
        ayarlar(context).edit()
            .putString(ZEMIN_ONEKI + appWidgetId, zemin)
            .putInt(SAYDAMLIK_ONEKI + appWidgetId, saydamlik)
            .apply()
    }

    fun secilenZemin(context: Context, appWidgetId: Int): String? =
        ayarlar(context).getString(ZEMIN_ONEKI + appWidgetId, null)

    fun secilenSaydamlik(context: Context, appWidgetId: Int): Int =
        ayarlar(context).getInt(SAYDAMLIK_ONEKI + appWidgetId, 100)

    /**
     * Ana ekrandan kaldirilmis widget'larin ayarlarini temizler.
     *
     * Saglayicilar onDeleted'i ayri ayri uygulamak yerine yapilandirma ekrani
     * her kayitta bir kez suzuyor; birikme olmuyor.
     */
    fun oksuzKayitlariTemizle(context: Context) {
        val yonetici = AppWidgetManager.getInstance(context) ?: return
        val yasayanlar = mutableSetOf<Int>()
        for (sinif in SAGLAYICILAR) {
            val bilesen = android.content.ComponentName(context, sinif)
            yonetici.getAppWidgetIds(bilesen)?.forEach { yasayanlar.add(it) }
        }

        val ayar = ayarlar(context)
        val duzenleyici = ayar.edit()
        for (anahtar in ayar.all.keys) {
            val kimlik = anahtar.substringAfterLast('_').toIntOrNull() ?: continue
            if (kimlik !in yasayanlar) duzenleyici.remove(anahtar)
        }
        duzenleyici.apply()
    }

    private val SAGLAYICILAR = listOf(
        KlasikTuruncuWidget::class.java,
        MiniSunsetWidget::class.java,
        GlassmorphismWidget::class.java,
        NeonGlowWidget::class.java,
        CosmicWidget::class.java,
        TimelineWidget::class.java,
        ZenWidget::class.java,
        OrigamiWidget::class.java
    )

    /**
     * Widget'in kullanacagi zemin ve yazi renklerini verir.
     *
     * [tipZeminAnahtari] ornegin "zen_arkaplan_key", [tipYaziAnahtari] ise
     * "zen_yazi_rengi_hex" gibi tasarima ozel tercih anahtarlaridir.
     */
    fun coz(
        context: Context,
        widgetData: SharedPreferences,
        appWidgetId: Int,
        tipZeminAnahtari: String,
        varsayilanZemin: String,
        tipYaziAnahtari: String,
        varsayilanYaziHex: String
    ): Gorunum {
        val ornekZemin = secilenZemin(context, appWidgetId)
        val zemin = ornekZemin
            ?: widgetData.getString(tipZeminAnahtari, null)
            ?: widgetData.getString("arkaplan_key", varsayilanZemin)
            ?: varsayilanZemin
        val saydamlik = if (ornekZemin != null) secilenSaydamlik(context, appWidgetId) else 100

        val yazi = if (ornekZemin != null) {
            Color.parseColor(
                if (WidgetZeminleri.acikZemin(zemin)) ACIK_ZEMIN_YAZISI else KOYU_ZEMIN_YAZISI
            )
        } else {
            val hex = widgetData.getString(tipYaziAnahtari, null)
                ?: widgetData.getString("yazi_rengi_hex", varsayilanYaziHex)
                ?: varsayilanYaziHex
            WidgetUtils.parseColorSafe(hex, Color.WHITE)
        }

        return Gorunum(
            zeminAnahtari = zemin,
            saydamlik = saydamlik,
            zeminKaynagi = WidgetZeminleri.zemin(zemin, saydamlik),
            yaziRengi = yazi,
            ikincilYaziRengi = Color.argb(
                IKINCIL_ALFA, Color.red(yazi), Color.green(yazi), Color.blue(yazi)
            ),
            ozelAyarVar = ornekZemin != null
        )
    }
}
