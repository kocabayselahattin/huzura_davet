package com.huzura.davet.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.huzura.davet.R

/**
 * Widget ana ekrana eklenirken acilan zemin ve saydamlik ekrani.
 *
 * Secim widget ornegine ozeldir: ayni widget'tan iki tane eklenirse birini
 * saydam, digerini opak yapabilirsiniz. Yazi rengi zemine gore otomatik secilir.
 */
class WidgetYapilandirmaActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var seciliZemin = VARSAYILAN_ZEMIN
    private var seciliSaydamlik = 100

    private lateinit var onizlemeKutusu: FrameLayout
    private lateinit var onizlemeBaslik: TextView
    private lateinit var onizlemeSayac: TextView
    private lateinit var zeminSeridi: LinearLayout
    private lateinit var saydamlikYazisi: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // Kullanici vazgecerse widget eklenmemeli; sonuc bastan iptal kabul edilir.
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_yapilandirma)

        onizlemeKutusu = findViewById(R.id.onizleme_kutusu)
        onizlemeBaslik = findViewById(R.id.onizleme_baslik)
        onizlemeSayac = findViewById(R.id.onizleme_sayac)
        zeminSeridi = findViewById(R.id.zemin_seridi)
        saydamlikYazisi = findViewById(R.id.saydamlik_yazisi)

        // Daha once yapilandirilmissa (yeniden duzenleme) mevcut secim yuklenir.
        WidgetGorunum.secilenZemin(this, appWidgetId)?.let { seciliZemin = it }
        seciliSaydamlik = WidgetGorunum.secilenSaydamlik(this, appWidgetId)

        zeminleriYerlestir()
        saydamlikKaydiriciyiKur()
        onizlemeyiTazele()

        findViewById<Button>(R.id.kaydet_dugmesi).setOnClickListener { kaydetVeKapat() }
    }

    private fun zeminleriYerlestir() {
        zeminSeridi.removeAllViews()
        for (anahtar in WidgetZeminleri.ANAHTARLAR) {
            val kutu = View(this).apply {
                setBackgroundResource(WidgetZeminleri.zemin(anahtar, 100))
                // Sabit ince kenarlık: beyaza/saydama yakın zeminler (semi_white,
                // transparent) ekran zemininde kaybolmasın diye her zaman görünür.
                foreground = getDrawable(R.drawable.widget_zemin_kenarlik)
                layoutParams = LinearLayout.LayoutParams(dp(52), dp(52)).apply {
                    marginEnd = dp(10)
                }
                contentDescription = anahtar
                setOnClickListener {
                    seciliZemin = anahtar
                    zeminSecimleriniIsaretle()
                    onizlemeyiTazele()
                }
            }
            val cerceve = FrameLayout(this).apply {
                setPadding(dp(3), dp(3), dp(3), dp(3))
                addView(kutu)
                tag = anahtar
            }
            zeminSeridi.addView(cerceve)
        }
        zeminSecimleriniIsaretle()
    }

    /** Secili zemini ince bir cerceveyle belirtir. */
    private fun zeminSecimleriniIsaretle() {
        for (i in 0 until zeminSeridi.childCount) {
            val cerceve = zeminSeridi.getChildAt(i) as? FrameLayout ?: continue
            cerceve.setBackgroundResource(
                if (cerceve.tag == seciliZemin) R.drawable.widget_yapilandirma_secili else 0
            )
        }
    }

    private fun saydamlikKaydiriciyiKur() {
        val kaydirici = findViewById<SeekBar>(R.id.saydamlik_kaydirici)
        val adimlar = WidgetZeminleri.SAYDAMLIK_ADIMLARI
        kaydirici.max = adimlar.size - 1
        // Adimlar %100'den %20'ye dogru sirali; kaydirici sagda opak olsun.
        kaydirici.progress = adimlar.size - 1 - adimlar.indexOf(
            adimlar.minByOrNull { kotlin.math.abs(it - seciliSaydamlik) } ?: 100
        )
        kaydirici.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar?, deger: Int, kullanicidan: Boolean) {
                seciliSaydamlik = adimlar[adimlar.size - 1 - deger]
                onizlemeyiTazele()
            }

            override fun onStartTrackingTouch(bar: SeekBar?) = Unit
            override fun onStopTrackingTouch(bar: SeekBar?) = Unit
        })
    }

    private fun onizlemeyiTazele() {
        onizlemeKutusu.setBackgroundResource(
            WidgetZeminleri.zemin(seciliZemin, seciliSaydamlik)
        )
        val yazi = if (WidgetZeminleri.acikZemin(seciliZemin)) {
            Color.parseColor("#212121")
        } else {
            Color.WHITE
        }
        onizlemeBaslik.setTextColor(Color.argb(200, Color.red(yazi), Color.green(yazi), Color.blue(yazi)))
        onizlemeSayac.setTextColor(yazi)
        saydamlikYazisi.text = getString(R.string.widget_yapilandirma_saydamlik_deger, seciliSaydamlik)
    }

    private fun kaydetVeKapat() {
        WidgetGorunum.kaydet(this, appWidgetId, seciliZemin, seciliSaydamlik)
        WidgetGorunum.oksuzKayitlariTemizle(this)

        // Widget'i hemen yeni gorunumle cizdir.
        val yonetici = AppWidgetManager.getInstance(this)
        val saglayici = yonetici?.getAppWidgetInfo(appWidgetId)?.provider
        if (saglayici != null) {
            sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    component = saglayici
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
                }
            )
        }

        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }

    private fun dp(deger: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, deger.toFloat(), resources.displayMetrics
    ).toInt()

    private companion object {
        const val VARSAYILAN_ZEMIN = "dark"
    }
}
