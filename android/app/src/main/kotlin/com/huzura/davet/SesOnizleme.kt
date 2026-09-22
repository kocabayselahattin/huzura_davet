package com.huzura.davet

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Uygulama içi ses ön dinlemesini res/raw altındaki dosyalardan çalar.
 *
 * Aynı sesler bildirim ve alarm tarafında zaten res/raw altında bulunuyor;
 * yalnızca ön dinleme için assets/sounds altında ikinci bir kopya tutmak
 * paketi ~47 MB büyütüyordu. Ön dinleme de bu kanaldan beslendiği için tek
 * kopya yetiyor.
 *
 * Bildirim ve alarm sesleri bu kanaldan geçmez; onlar AlarmService ve
 * DailyContentReceiver üzerinden çalınmaya devam eder.
 */
object SesOnizleme {
    private const val TAG = "SesOnizleme"
    private const val KANAL_ADI = "huzur_vakti/ses_onizleme"

    private var kanal: MethodChannel? = null
    private var oynatici: MediaPlayer? = null

    fun setup(flutterEngine: FlutterEngine, context: Context) {
        val uygulamaContext = context.applicationContext
        val yeniKanal =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL_ADI)
        kanal = yeniKanal

        yeniKanal.setMethodCallHandler { call, result ->
            when (call.method) {
                "cal" -> {
                    val sesId = call.argument<String>("sesId").orEmpty()
                    result.success(cal(uygulamaContext, sesId))
                }
                "durdur" -> {
                    durdur()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Ön dinlemeyi başlatır. Ses bulunamaz veya açılamazsa false döner. */
    private fun cal(context: Context, sesId: String): Boolean {
        durdur()

        // "system_default": telefonun varsayılan bildirim sesi (content://
        // URI); "/" içeren bir yol ise kullanıcının cihazdan seçtiği özel
        // dosya. İkisi de res/raw'da değildir, doğrudan URI ile çalınır.
        val sesUri: Uri = when {
            sesId == "system_default" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            sesId.contains('/') -> Uri.fromFile(java.io.File(sesId))
            else -> {
                val resId = kaynakId(context, sesId)
                if (resId == 0) {
                    Log.w(TAG, "⚠️ res/raw altında ses bulunamadı: $sesId")
                    return false
                }
                Uri.parse("android.resource://${context.packageName}/$resId")
            }
        }

        return try {
            oynatici = MediaPlayer().apply {
                // Ön dinleme medya akışından çalar; bildirimin kendisi değil,
                // sesin nasıl olduğunu duyurmak için var.
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(context, sesUri)
                setOnCompletionListener { bittiginiBildir() }
                setOnErrorListener { _, ne, ekstra ->
                    Log.e(TAG, "❌ Ön dinleme hatası: $ne / $ekstra")
                    bittiginiBildir()
                    true
                }
                // Yerel kaynak olduğu için hazırlık anlık; asenkron kuruluma gerek yok.
                prepare()
                start()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ön dinleme başlatılamadı ($sesId): ${e.message}")
            serbestBirak()
            false
        }
    }

    fun durdur() = serbestBirak()

    /**
     * Ses kendiliğinden bitince Flutter tarafı çal/durdur düğmesini eski
     * hâline alabilsin diye haber verir.
     */
    private fun bittiginiBildir() {
        serbestBirak()
        kanal?.invokeMethod("bitti", null)
    }

    private fun serbestBirak() {
        try {
            oynatici?.release()
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ MediaPlayer serbest bırakılamadı: ${e.message}")
        }
        oynatici = null
    }

    /**
     * res/raw altındaki karşılığı bulur. Flutter tarafındaki ses ID'leri
     * ("best", "ding_dong" ...) dosya adlarıyla birebir aynı; yine de
     * ".mp3" uzantısı ve büyük harf tolere edilir.
     */
    private fun kaynakId(context: Context, sesId: String): Int {
        val ad = sesId.trim().lowercase().removeSuffix(".mp3")
        if (ad.isEmpty()) return 0
        @Suppress("DiscouragedApi")
        return context.resources.getIdentifier(ad, "raw", context.packageName)
    }
}
