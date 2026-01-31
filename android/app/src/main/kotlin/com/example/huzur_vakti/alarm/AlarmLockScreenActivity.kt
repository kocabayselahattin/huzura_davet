package com.example.huzur_vakti.alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.example.huzur_vakti.MainActivity
import com.example.huzur_vakti.R
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.*

/**
 * Kilit ekranında görünen alarm activity'si
 * Ses/güç tuşlarına basınca alarm kapanır
 * Modern ve şık tasarım
 */
class AlarmLockScreenActivity : Activity() {
    
    private var vakitName = ""
    private var vakitTime = ""
    private var isEarly = false
    private var earlyMinutes = 0
    private var isSessizeAlEnabled = false  // Vakitlerde sessize al ayarı
    
    // Motivasyon sözleri
    private val motivasyonSozleri = listOf(
        "Namaz müminin miracıdır.",
        "Sabır ve namazla Allah'tan yardım isteyin.",
        "Namaz, kötülüklerden alıkoyar.",
        "Namazı dosdoğru kılın.",
        "Namaz dinin direğidir.",
        "Hayırlı ibadetler!",
        "Allah kabul etsin.",
        "Rahmet kapıları açık!",
        "Dualarınız kabul olsun."
    )
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Kilit ekranı üzerinde göster
        setupLockScreenFlags()
        
        // Intent'ten verileri al
        vakitName = intent.getStringExtra(AlarmReceiver.EXTRA_VAKIT_NAME) ?: "Vakit"
        vakitTime = intent.getStringExtra(AlarmReceiver.EXTRA_VAKIT_TIME) ?: ""
        isEarly = intent.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false)
        earlyMinutes = intent.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0)
        
        // Vakitlerde sessize al ayarı
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        isSessizeAlEnabled = prefs.getBoolean("flutter.sessize_al", false)
        
        // UI'ı oluştur
        setContentView(R.layout.activity_alarm_lock_screen)
        setupUI()
    }
    
    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        // Tam ekran
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )
    }
    
    private fun setupUI() {
        // Widget verilerinden konum ve tarih al
        val widgetData = HomeWidgetPlugin.getData(this)
        val konum = widgetData.getString("konum", "İstanbul") ?: "İstanbul"
        val hicriTarih = widgetData.getString("hicri_tarih", "") ?: ""
        
        // Miladi tarih
        val miladiTarih = SimpleDateFormat("dd MMMM yyyy", Locale("tr", "TR")).format(Date())
        
        // Konum
        findViewById<TextView>(R.id.tv_location)?.text = konum
        
        // Tarih (Miladi + Hicri)
        val tarihText = if (hicriTarih.isNotEmpty()) {
            "$miladiTarih • $hicriTarih"
        } else {
            miladiTarih
        }
        findViewById<TextView>(R.id.tv_date)?.text = tarihText
        
        // Başlık
        findViewById<TextView>(R.id.tv_alarm_title)?.text = if (isEarly) {
            "${vakitName.uppercase()} NAMAZI"
        } else {
            "${vakitName.uppercase()} NAMAZI"
        }
        
        // Alt yazı
        findViewById<TextView>(R.id.tv_alarm_subtitle)?.text = if (isEarly) {
            "⏰ $earlyMinutes dakika kaldı"
        } else {
            "✨ Hayırlı ibadetler ✨"
        }
        
        // Saat
        findViewById<TextView>(R.id.tv_alarm_time)?.text = vakitTime
        
        // Motivasyon sözü
        val randomSoz = motivasyonSozleri.random()
        findViewById<TextView>(R.id.tv_quote)?.text = randomSoz
        
        // Hilal ikonu - vakite göre değişsin
        val moonIcon = when (vakitName.lowercase()) {
            "imsak", "yatsı" -> "🌙"
            "güneş", "gunes" -> "🌅"
            "öğle", "ogle" -> "☀️"
            "ikindi" -> "🌤️"
            "akşam", "aksam" -> "🌆"
            else -> "☪"
        }
        findViewById<TextView>(R.id.tv_moon_icon)?.text = moonIcon
        
        // Butonları ayarla - sessize al durumuna ve erken bildirime göre
        val btnDismiss = findViewById<Button>(R.id.btn_dismiss)
        val btnStay = findViewById<Button>(R.id.btn_stay)
        val btnExit = findViewById<Button>(R.id.btn_exit)
        
        // ERKEN BİLDİRİMDE "Kal" ve "Çık" butonları GÖSTERME
        if (isEarly) {
            // Erken bildirim - sadece Kapat butonu (sessize al ayarı açık olsa bile)
            btnDismiss?.visibility = View.VISIBLE
            btnStay?.visibility = View.GONE
            btnExit?.visibility = View.GONE
            
            btnDismiss?.setOnClickListener {
                dismissAlarm()
            }
            
            findViewById<TextView>(R.id.tv_hint)?.text = 
                "Ses veya kilit tuşuna basarak kapatabilirsiniz"
        } else if (isSessizeAlEnabled) {
            // Vaktinde bildirim VE vakitlerde sessize al açık - Kal ve Çık butonlarını göster
            btnDismiss?.visibility = View.GONE
            btnStay?.visibility = View.VISIBLE
            btnExit?.visibility = View.VISIBLE
            
            // "Kal" butonu - sessize al ve kapat
            btnStay?.setOnClickListener {
                // Telefonu hemen sessize al
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val currentMode = audioManager.ringerMode
                prefs.edit().putInt("flutter.previous_ringer_mode", currentMode).apply()
                audioManager.ringerMode = android.media.AudioManager.RINGER_MODE_SILENT
                
                // AlarmService'e bildir
                dismissAlarmWithSilentMode(true)
            }
            
            // "Çık" butonu - normale dön ve kapat
            btnExit?.setOnClickListener {
                // Telefonu hemen normale döndür
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val previousMode = prefs.getInt("flutter.previous_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL)
                audioManager.ringerMode = previousMode
                
                // AlarmService'e bildir
                dismissAlarmWithSilentMode(false)
            }
            
            // Talimat metnini güncelle
            findViewById<TextView>(R.id.tv_hint)?.text = 
                "Kal: Telefonu sessize alır • Çık: Normal moda döner"
        } else {
            // Vaktinde bildirim - sadece Kapat butonu
            btnDismiss?.visibility = View.VISIBLE
            btnStay?.visibility = View.GONE
            btnExit?.visibility = View.GONE
            
            btnDismiss?.setOnClickListener {
                dismissAlarm()
            }
            
            findViewById<TextView>(R.id.tv_hint)?.text = 
                "Ses veya kilit tuşuna basarak kapatabilirsiniz"
        }
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_POWER,
            KeyEvent.KEYCODE_HEADSETHOOK -> {
                // Erken bildirimde veya sessize al kapalıysa sadece kapat
                if (isEarly || !isSessizeAlEnabled) {
                    dismissAlarm()
                } else {
                    // Vaktinde bildirim VE vakitlerde sessize al açıksa, tuşla susturunca sessize al
                    dismissAlarmWithSilentMode(true)
                }
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Geri tuşu ile de alarmı kapat
        if (isEarly || !isSessizeAlEnabled) {
            dismissAlarm()
        } else {
            dismissAlarmWithSilentMode(true)
        }
    }
    
    /**
     * Alarmı tamamen kapat
     */
    private fun dismissAlarm() {
        AlarmService.stopAlarm(this)
        finish()
    }
    
    /**
     * Alarmı kapat ve sessize al modunu ayarla
     * @param setSilent true ise telefonu sessize al, false ise normale döndür
     */
    private fun dismissAlarmWithSilentMode(setSilent: Boolean) {
        val intent = Intent(this, AlarmService::class.java).apply {
            action = if (setSilent) {
                AlarmService.ACTION_STAY_SILENT
            } else {
                AlarmService.ACTION_EXIT_SILENT
            }
        }
        startService(intent)
        finish()
    }
    
    override fun onDestroy() {
        super.onDestroy()
    }
}
