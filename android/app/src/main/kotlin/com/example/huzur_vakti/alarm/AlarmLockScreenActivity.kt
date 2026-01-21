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
        
        // Kapat butonu
        findViewById<Button>(R.id.btn_dismiss)?.setOnClickListener {
            dismissAlarm()
        }
        
        // Ertele butonu
        findViewById<Button>(R.id.btn_snooze)?.setOnClickListener {
            snoozeAlarm()
        }
        
        // Ekrana dokununca talimat göster
        findViewById<TextView>(R.id.tv_hint)?.text = 
            "Ses veya kilit tuşuna basarak kapatabilirsiniz"
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_POWER,
            KeyEvent.KEYCODE_HEADSETHOOK -> {
                // Alarmı tamamen kapat ve activity'yi de kapat
                dismissAlarm()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Geri tuşu ile de alarmı kapat
        dismissAlarm()
    }
    
    /**
     * Alarmı tamamen kapat
     */
    private fun dismissAlarm() {
        AlarmService.stopAlarm(this)
        finish()
    }
    
    /**
     * Alarmı 5 dakika ertele
     */
    private fun snoozeAlarm() {
        val snoozeIntent = Intent(this, AlarmService::class.java)
        snoozeIntent.action = AlarmService.ACTION_SNOOZE_ALARM
        startService(snoozeIntent)
        finish()
    }
    
    override fun onDestroy() {
        super.onDestroy()
    }
}
