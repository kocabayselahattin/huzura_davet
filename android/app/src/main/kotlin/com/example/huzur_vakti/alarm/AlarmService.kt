package com.example.huzur_vakti.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.session.MediaSession
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import com.example.huzur_vakti.MainActivity
import com.example.huzur_vakti.R

/**
 * Alarm çaldığında ses çalan ve bildirim gösteren Foreground Service
 * Kilit ekranında çalışır, ses tuşları/güç tuşu ile susturulabilir
 */
class AlarmService : Service() {
    
    companion object {
        private const val TAG = "AlarmService"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "alarm_channel"
        const val ACTION_STOP_ALARM = "com.example.huzur_vakti.STOP_ALARM"
        const val ACTION_SNOOZE_ALARM = "com.example.huzur_vakti.SNOOZE_ALARM"
        const val ACTION_STAY_SILENT = "com.example.huzur_vakti.STAY_SILENT"  // "Kal" butonu - sessize al ve kapat
        const val ACTION_EXIT_SILENT = "com.example.huzur_vakti.EXIT_SILENT"  // "Çık" butonu - normal moda dön
        
        // Singleton instance - alarm durumunu kontrol etmek için
        @Volatile
        private var instance: AlarmService? = null
        
        fun isAlarmPlaying(): Boolean = instance?.isPlaying == true
        
        fun stopAlarm(context: Context) {
            val intent = Intent(context, AlarmService::class.java).apply {
                action = ACTION_STOP_ALARM
            }
            context.startService(intent)
        }
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isPlaying = false
    private var currentVakitName = ""
    private var currentVakitTime = ""
    private var isSessizeAlEnabled = false  // Vakitlerde sessize al ayarı
    private var isCurrentAlarmEarly = false  // Mevcut alarm erken bildirim mi?
    private var mediaSession: MediaSession? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        setupMediaSession()
        setupScreenOffReceiver()
        Log.d(TAG, "🔔 AlarmService oluşturuldu")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📢 onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                stopAlarmSound()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE_ALARM -> {
                // 5 dakika sonra tekrar çal
                snoozeAlarm()
                stopAlarmSound()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_STAY_SILENT -> {
                // "Kal" butonu - telefonu sessize al ve kapat
                Log.d(TAG, "🔇 'Kal' butonu tıklandı - telefon sessize alınıyor")
                setSilentMode(true)
                showSilentModeNotification() // Bilgi bildirimi göster
                stopAlarmSound()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_EXIT_SILENT -> {
                // "Çık" butonu - normal moda dön ve kapat
                Log.d(TAG, "🔊 'Çık' butonu tıklandı - telefon normale dönüyor")
                setSilentMode(false)
                // Sessiz mod bildirimini kaldır
                cancelSilentModeNotification()
                stopAlarmSound()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Alarm başlat - default action (null veya bilinmeyen)
                // Boş action veya alarm action'ı gelebilir
                Log.d(TAG, "📢 Default/Alarm action: ${intent?.action ?: "null"}")
                
                val alarmId = intent?.getIntExtra(AlarmReceiver.EXTRA_ALARM_ID, 0) ?: 0
                currentVakitName = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_NAME) ?: "Vakit"
                currentVakitTime = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_TIME) ?: ""
                val soundFile = intent?.getStringExtra(AlarmReceiver.EXTRA_SOUND_FILE) ?: "ding_dong"
                val isEarly = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false) ?: false
                val earlyMinutes = intent?.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0) ?: 0
                
                // Erken bildirim bilgisini kaydet
                isCurrentAlarmEarly = isEarly
                
                // Vakitlerde sessize al ayarını kontrol et
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                isSessizeAlEnabled = prefs.getBoolean("flutter.sessize_al", false)
                Log.d(TAG, "📵 Vakitlerde sessize al ayarı: $isSessizeAlEnabled, Erken bildirim: $isEarly")
                
                // Alarm aktif flag'ini ayarla (DND beklesin diye)
                setAlarmActiveFlag(true)
                
                // Foreground service olarak başlat - sessize al ayarına göre bildirim oluştur
                val notification = createAlarmNotification(currentVakitName, currentVakitTime, isEarly, earlyMinutes)
                startForeground(NOTIFICATION_ID, notification)
                
                // Telefon sessiz modda mı kontrol et
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val isSilentMode = audioManager.ringerMode == AudioManager.RINGER_MODE_SILENT ||
                                   audioManager.ringerMode == AudioManager.RINGER_MODE_VIBRATE
                
                Log.d(TAG, "📱 Telefon modu: ${audioManager.ringerMode} (NORMAL=2, VIBRATE=1, SILENT=0), Sessiz mi: $isSilentMode")
                
                // Telefon sessiz modda DEĞİLSE ses çal
                if (!isSilentMode) {
                    Log.d(TAG, "🔊 Telefon normal modda - ses çalınacak: $soundFile")
                    playAlarmSound(soundFile)
                    // Normal modda standart titreşim paterni
                    startVibration(false)
                } else {
                    Log.d(TAG, "📵 Telefon sessiz/titreşim modunda - ses çalmayacak, sadece uzun titreşim")
                    // Sessiz modda sadece uzun titreşim (3 saniye)
                    startVibration(true)
                }
                
                // Kilit ekranı activity'sini başlat
                startLockScreenActivity(currentVakitName, currentVakitTime, isEarly, earlyMinutes)
            }
        }
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Vakit Alarmları",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Namaz vakti alarm bildirimleri"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createAlarmNotification(vakitName: String, vakitTime: String, isEarly: Boolean, earlyMinutes: Int): Notification {
        // Ana uygulamayı açacak intent
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Alarmı durdur butonu (varsayılan)
        val stopIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // "Kal" butonu - telefonu sessize al
        val stayIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_STAY_SILENT
        }
        val stayPendingIntent = PendingIntent.getService(
            this, 2, stayIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // "Çık" butonu - normal moda dön
        val exitIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_EXIT_SILENT
        }
        val exitPendingIntent = PendingIntent.getService(
            this, 3, exitIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val title = if (isEarly) {
            "$vakitName Vakti Yaklaşıyor"
        } else {
            "$vakitName Vakti Girdi"
        }
        
        val body = if (isEarly) {
            "$vakitName vaktine $earlyMinutes dakika kaldı"
        } else {
            "$vakitName vakti girdi. Hayırlı ibadetler!"
        }
        
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(mainPendingIntent)
            .setFullScreenIntent(mainPendingIntent, true)
            .setAutoCancel(false)
            .setOngoing(true)
        
        // Vakitlerde sessize al ayarı açıksa VE bu erken bildirim DEĞİLSE "Kal" ve "Çık" butonları göster
        if (isSessizeAlEnabled && !isEarly) {
            builder.addAction(android.R.drawable.ic_lock_silent_mode, "Kal (Sessize Al)", stayPendingIntent)
            builder.addAction(android.R.drawable.ic_lock_silent_mode_off, "Çık (Normal)", exitPendingIntent)
            Log.d(TAG, "📵 Bildirimde 'Kal' ve 'Çık' butonları eklendi (vaktinde bildirim)")
        } else {
            // Normal mod - sadece Kapat butonu
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Kapat", stopPendingIntent)
        }
        
        return builder.build()
    }
    
    private fun playAlarmSound(soundFile: String) {
        try {
            stopAlarmSound() // Önceki sesi durdur
            
            // Ses dosyası boş veya varsayılan ding_dong ise SharedPreferences'tan vakit bazlı sesi al
            var actualSoundFile = soundFile
            if (actualSoundFile.isEmpty() || actualSoundFile == "ding_dong" || actualSoundFile == "ding_dong.mp3") {
                val vakitName = currentVakitName.lowercase()
                    .replace("ı", "i").replace("ö", "o").replace("ü", "u")
                    .replace("ş", "s").replace("ğ", "g").replace("ç", "c")
                
                val vakitKey = when {
                    vakitName.contains("imsak") || vakitName.contains("sahur") -> "imsak"
                    vakitName.contains("gunes") || vakitName.contains("güneş") -> "gunes"
                    vakitName.contains("ogle") || vakitName.contains("öğle") -> "ogle"
                    vakitName.contains("ikindi") -> "ikindi"
                    vakitName.contains("aksam") || vakitName.contains("akşam") -> "aksam"
                    vakitName.contains("yatsi") || vakitName.contains("yatsı") -> "yatsi"
                    else -> ""
                }
                
                if (vakitKey.isNotEmpty()) {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val savedSound = prefs.getString("flutter.bildirim_sesi_$vakitKey", null)
                    if (!savedSound.isNullOrEmpty()) {
                        actualSoundFile = savedSound
                        Log.d(TAG, "🔊 SharedPreferences'tan ses alındı: $vakitKey -> $actualSoundFile")
                    }
                }
            }
            
            Log.d(TAG, "🔊 Alarm sesi başlatılıyor - Orijinal: $soundFile, Kullanılan: $actualSoundFile")
            
            mediaPlayer = MediaPlayer().apply {
                // Ses kaynağını ayarla - ZİL SESİ akışını kullan (telefon sessizde iken çalmaz)
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setAudioAttributes(audioAttributes)
                
                // Raw klasöründen ses dosyasını bul
                var soundName = actualSoundFile.replace(".mp3", "").lowercase()
                    .replace(" ", "_").replace("-", "_")
                
                // Özel eşlemeler (raw klasöründeki isimlerle uyumlu)
                if (soundName == "best_2015") soundName = "best"
                
                Log.d(TAG, "🔊 Ses dosyası aranıyor: $soundName (paket: $packageName)")
                
                val resId = resources.getIdentifier(soundName, "raw", packageName)
                Log.d(TAG, "🔊 Resource ID: $resId")
                
                if (resId != 0) {
                    Log.d(TAG, "✅ Ses dosyası bulundu: $soundName (ID: $resId)")
                    val afd = resources.openRawResourceFd(resId)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } else {
                    Log.w(TAG, "⚠️ Ses dosyası bulunamadı: $soundName - varsayılan alarm sesi kullanılacak")
                    // Varsayılan alarm sesi
                    val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    setDataSource(this@AlarmService, defaultUri)
                }
                
                // Ses dosyası bittiğinde durur (sonsuz döngü yok)
                isLooping = false
                
                // Ses bittiğinde servisi kapat
                setOnCompletionListener {
                    Log.d(TAG, "🔊 Alarm sesi tamamlandı")
                    this@AlarmService.stopVibration()
                    this@AlarmService.isPlaying = false
                    
                    // Vakitlerde sessize al ayarı açıksa telefonu sessize al
                    this@AlarmService.checkAndSetSilentMode()
                    
                    // Alarm aktif flag'ini kapat (DND aktif olabilir diye)
                    this@AlarmService.setAlarmActiveFlag(false)
                    
                    // Servisi kapat
                    this@AlarmService.stopForeground(STOP_FOREGROUND_REMOVE)
                    this@AlarmService.stopSelf()
                }
                
                prepare()
                start()
            }
            
            isPlaying = true
            Log.d(TAG, "🔊 Alarm sesi çalıyor: $actualSoundFile")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Alarm sesi çalma hatası: ${e.message}")
            // Fallback - sistem alarm sesi
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(this@AlarmService, defaultUri)
                    isLooping = false
                    setOnCompletionListener {
                        Log.d(TAG, "🔊 Fallback alarm sesi tamamlandı")
                        this@AlarmService.stopVibration()
                        this@AlarmService.isPlaying = false
                        
                        // Vakitlerde sessize al ayarı açıksa telefonu sessize al
                        this@AlarmService.checkAndSetSilentMode()
                    }
                    prepare()
                    start()
                }
                isPlaying = true
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Fallback ses de çalınamadı: ${e2.message}")
            }
        }
    }
    
    private fun stopAlarmSound() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            isPlaying = false
            
            stopVibration()
            
            // Alarm aktif flag'ini kapat
            setAlarmActiveFlag(false)
            
            // Alarm durdurulduğunda sessize al ayarını kontrol et
            checkAndSetSilentMode()
            
            Log.d(TAG, "🔇 Alarm sesi durduruldu")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ses durdurma hatası: ${e.message}")
        }
    }
    
    private fun stopVibration() {
        try {
            vibrator?.cancel()
            vibrator = null
            Log.d(TAG, "📳 Titreşim durduruldu")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Titreşim durdurma hatası: ${e.message}")
        }
    }
    
    /**
     * Titreşimi başlat
     * @param longVibration true ise sessiz mod için uzun titreşim (3 saniye tek seferde)
     */
    private fun startVibration(longVibration: Boolean = false) {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            if (longVibration) {
                // Sessiz modda: 3 saniye kesintisiz titreşim (tekrar yok)
                Log.d(TAG, "📳 Uzun titreşim başlatılıyor (3 saniye)")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(3000, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(3000)
                }
            } else {
                // Normal mod: Titreşim paterni - bekle, titret, bekle, titret... (sonsuz döngü: 0)
                val pattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // 0 = sonsuz döngü, patern tekrar eder
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                }
            }
            
            Log.d(TAG, "📳 Titreşim başlatıldı (uzun: $longVibration)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Titreşim hatası: ${e.message}")
        }
    }
    
    private fun startLockScreenActivity(vakitName: String, vakitTime: String, isEarly: Boolean, earlyMinutes: Int) {
        try {
            val intent = Intent(this, AlarmLockScreenActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(AlarmReceiver.EXTRA_VAKIT_NAME, vakitName)
                putExtra(AlarmReceiver.EXTRA_VAKIT_TIME, vakitTime)
                putExtra(AlarmReceiver.EXTRA_IS_EARLY, isEarly)
                putExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, earlyMinutes)
            }
            startActivity(intent)
            Log.d(TAG, "🖥️ Kilit ekranı activity başlatıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Kilit ekranı activity hatası: ${e.message}")
        }
    }
    
    private fun snoozeAlarm() {
        // 5 dakika sonra tekrar çal
        val triggerTime = System.currentTimeMillis() + (5 * 60 * 1000)
        AlarmReceiver.scheduleAlarm(
            context = this,
            alarmId = 100, // Snooze için özel ID
            prayerName = currentVakitName,
            triggerAtMillis = triggerTime,
            soundPath = "ding_dong",
            useVibration = true
        )
        Log.d(TAG, "⏰ Alarm 5 dakika ertelendi")
    }
    
    /**
     * MediaSession ile ses tuşlarını dinle
     * Ses tuşuna basınca alarm durur
     */
    private fun setupMediaSession() {
        try {
            mediaSession = MediaSession(this, "HuzurVaktiAlarm").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                        val keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                        }
                        
                        if (keyEvent?.action == KeyEvent.ACTION_DOWN) {
                            when (keyEvent.keyCode) {
                                KeyEvent.KEYCODE_VOLUME_UP,
                                KeyEvent.KEYCODE_VOLUME_DOWN,
                                KeyEvent.KEYCODE_HEADSETHOOK,
                                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                                    Log.d(TAG, "🎮 Ses tuşu ile alarm durduruldu")
                                    stopAlarmSound()
                                    stopForeground(STOP_FOREGROUND_REMOVE)
                                    stopSelf()
                                    return true
                                }
                            }
                        }
                        return super.onMediaButtonEvent(mediaButtonIntent)
                    }
                })
                isActive = true
            }
            Log.d(TAG, "🎧 MediaSession kuruldu - ses tuşları dinleniyor")
        } catch (e: Exception) {
            Log.e(TAG, "❌ MediaSession hatası: ${e.message}")
        }
    }
    
    /**
     * Ekran kapandığında (güç tuşu) alarmı durdur
     */
    private fun setupScreenOffReceiver() {
        try {
            screenOffReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action == Intent.ACTION_SCREEN_OFF) {
                        Log.d(TAG, "📴 Güç tuşu ile ekran kapatıldı - alarm durduruluyor")
                        stopAlarmSound()
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                }
            }
            
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenOffReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenOffReceiver, filter)
            }
            Log.d(TAG, "📴 Screen off receiver kuruldu - güç tuşu dinleniyor")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Screen off receiver hatası: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        stopAlarmSound()
        
        // MediaSession'ı temizle
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ MediaSession temizleme hatası: ${e.message}")
        }
        
        // Screen off receiver'ı temizle
        try {
            screenOffReceiver?.let {
                unregisterReceiver(it)
            }
            screenOffReceiver = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Screen off receiver temizleme hatası: ${e.message}")
        }
        
        instance = null
        super.onDestroy()
        Log.d(TAG, "🔔 AlarmService sonlandırıldı")
    }
    
    /**
     * Alarm aktif flag'ini ayarla (DND'nin beklemesi için)
     */
    private fun setAlarmActiveFlag(active: Boolean) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.alarm_active", active).apply()
            Log.d(TAG, "🚨 Alarm aktif flag: $active")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Alarm flag hatası: ${e.message}")
        }
    }
    
    /**
     * Telefonu sessize al veya normale döndür
     * @param silent true ise sessize al, false ise normale döndür
     */
    private fun setSilentMode(silent: Boolean) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            if (silent) {
                // Önceki ringer mode'u kaydet (çıkınca geri yüklemek için)
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val currentMode = audioManager.ringerMode
                prefs.edit().putInt("flutter.previous_ringer_mode", currentMode).apply()
                
                // Sessize al
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d(TAG, "🔇 Telefon sessize alındı (önceki mod: $currentMode)")
            } else {
                // Önceki moda geri dön
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val previousMode = prefs.getInt("flutter.previous_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
                
                audioManager.ringerMode = previousMode
                Log.d(TAG, "🔊 Telefon normale döndü (mod: $previousMode)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ses modu değiştirme hatası: ${e.message}")
        }
    }
    
    /**
     * Vakitlerde sessize al ayarı açıksa ve alarm durdurulduğunda telefonu sessize alır
     * Bu fonksiyon alarm susturulduğunda (güç/ses tuşu) çağrılır
     * NOT: SADECE VAKTİNDE BİLDİRİMLERDE ÇALIŞIR, ERKEN BİLDİRİMLERDE ÇALIŞMAZ
     */
    private fun checkAndSetSilentMode() {
        try {
            // Erken bildirimde sessize alma yapma
            if (isCurrentAlarmEarly) {
                Log.d(TAG, "ℹ️ Bu erken bildirim - sessize alma yapılmayacak")
                return
            }
            
            // Vakitlerde sessize al ayarı açık mı?
            if (!isSessizeAlEnabled) {
                Log.d(TAG, "ℹ️ Vakitlerde sessize al ayarı kapalı - otomatik sessize alma yapılmayacak")
                return
            }
            
            Log.d(TAG, "🔇 Vakitlerde sessize al aktif - telefon sessize alınıyor...")
            setSilentMode(true)
            
            // Kullanıcıya bilgi ver - bildirim göster
            showSilentModeNotification()
            
            Log.d(TAG, "✅ Telefon sessize alındı (alarm susturulduktan sonra)")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Telefonu sessize alma hatası: ${e.message}")
        }
    }
    
    /**
     * Sessize alındığını bildiren bildirim göster
     * Kullanıcı bu bildirimden normale dönebilir
     */
    private fun showSilentModeNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Bildirim kanalı oluştur (Android 8+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "silent_mode_channel",
                    "Sessiz Mod Bildirimleri",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Vakitlerde sessize al bildirimleri"
                    setShowBadge(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // "Normale Dön" butonu için intent
            val normalModeIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_EXIT_SILENT
            }
            val normalModePendingIntent = PendingIntent.getService(
                this, 100, normalModeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Bildirim oluştur
            val notification = NotificationCompat.Builder(this, "silent_mode_channel")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("🔇 Telefon Sessize Alındı")
                .setContentText("$currentVakitName vakti için telefon sessize alındı. Normale dönmek için tıklayın.")
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("$currentVakitName vakti için telefon sessize alındı.\n\nNamaz bittiğinde normale dönmek için aşağıdaki butona basın veya bu bildirimi kaydırarak kapatın."))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setOngoing(true) // Kullanıcı kaydırana kadar kalsın
                .addAction(android.R.drawable.ic_lock_silent_mode_off, "🔊 Normale Dön", normalModePendingIntent)
                .build()
            
            // Bildirimi göster
            notificationManager.notify(2001, notification)
            Log.d(TAG, "📢 Sessiz mod bildirimi gösterildi")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Sessiz mod bildirimi hatası: ${e.message}")
        }
    }
    
    /**
     * Sessiz mod bildirimini kaldır
     */
    private fun cancelSilentModeNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(2001)
            Log.d(TAG, "📢 Sessiz mod bildirimi kaldırıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Bildirim kaldırma hatası: ${e.message}")
        }
    }
}
