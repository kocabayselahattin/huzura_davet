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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
 * 
 * ERKEN BİLDİRİM (vaktinden önce):
 * - Telefon sessizde mi kontrol et
 * - Sessizde ise: sadece titreşim
 * - Sessizde değilse: kullanıcının seçtiği erken bildirim sesini çal + titreşim
 * - Telefonu sessize ALMAZ
 * 
 * VAKTİNDE BİLDİRİM:
 * - Telefon sessizde mi kontrol et
 * - Sessizde ise: sadece titreşim
 * - Sessizde değilse: kullanıcının seçtiği alarm sesi + titreşim çal
 * - Kullanıcı tuşa basınca ses durur
 * - "Vakitlerde sessize al" açıksa:
 *   - Ses durdurulduktan sonra telefonu sessize al
 *   - Çık/Kal butonları göster
 * - "Vakitlerde sessize al" kapalıysa: Sessize almaz
 */
class AlarmService : Service() {
    
    companion object {
        private const val TAG = "AlarmService"
        const val NOTIFICATION_ID = 1001
        const val SILENT_MODE_NOTIFICATION_ID = 2001
        const val CHANNEL_ID = "alarm_channel"
        const val SILENT_MODE_CHANNEL_ID = "silent_mode_channel"
        const val ACTION_STOP_ALARM = "com.example.huzur_vakti.STOP_ALARM"
        const val ACTION_STAY_SILENT = "com.example.huzur_vakti.STAY_SILENT"  // Kal butonu
        const val ACTION_EXIT_SILENT = "com.example.huzur_vakti.EXIT_SILENT"  // Çık butonu
        
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
    
    private var vibrator: Vibrator? = null
    private var isPlaying = false
    private var currentVakitName = ""
    private var currentVakitTime = ""
    private var isSessizeAlEnabled = false      // Vakitlerde sessize al ayarı
    private var isCurrentAlarmEarly = false     // Mevcut alarm erken bildirim mi?
    private var wasPhoneSilentBefore = false    // Alarm başlamadan telefon sessiz miydi?
    private var screenOffReceiver: BroadcastReceiver? = null
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        setupScreenOffReceiver()
        Log.d(TAG, "🔔 AlarmService oluşturuldu")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📢 onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                handleStopAlarm()
                return START_NOT_STICKY
            }
            ACTION_STAY_SILENT -> {
                handleStaySilent()
                return START_NOT_STICKY
            }
            ACTION_EXIT_SILENT -> {
                handleExitSilent()
                return START_NOT_STICKY
            }
            else -> {
                handleAlarmStart(intent)
            }
        }
        
        return START_STICKY
    }
    
    /**
     * Alarm başlat
     */
    private fun handleAlarmStart(intent: Intent?) {
        val alarmId = intent?.getIntExtra(AlarmReceiver.EXTRA_ALARM_ID, 0) ?: 0
        currentVakitName = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_NAME) ?: "Vakit"
        currentVakitTime = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_TIME) ?: ""
        val soundFile = intent?.getStringExtra(AlarmReceiver.EXTRA_SOUND_FILE) ?: "best"
        isCurrentAlarmEarly = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false) ?: false
        val earlyMinutes = intent?.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0) ?: 0

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        isSessizeAlEnabled = prefs.getBoolean("flutter.sessize_al", false)

        if (!isCurrentAlarmEarly) {
            val vakitKey = normalizeVakitName(currentVakitName)
            if (vakitKey.isNotEmpty()) {
                val defaultVaktinde = (vakitKey == "ogle" || vakitKey == "ikindi" ||
                        vakitKey == "aksam" || vakitKey == "yatsi")
                val vaktindeBildirimAcik = prefs.getBoolean("flutter.vaktinde_$vakitKey", defaultVaktinde)

                Log.d(TAG, "🔔 Vaktinde bildirim kontrolü: vakitKey=$vakitKey, açık=$vaktindeBildirimAcik")

                if (!vaktindeBildirimAcik) {
                    Log.d(TAG, "⏭️ Vaktinde bildirim kapalı - alarm atlanıyor: $currentVakitName")
                    stopSelf()
                    return
                }
            }
        }

        Log.d(TAG, "📵 Vakitlerde sessize al: $isSessizeAlEnabled, Erken bildirim: $isCurrentAlarmEarly")
        Log.d(TAG, "🔊 Alarm ses dosyası: $soundFile")

        setAlarmActiveFlag(true)

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        wasPhoneSilentBefore = (ringerMode == AudioManager.RINGER_MODE_SILENT ||
                ringerMode == AudioManager.RINGER_MODE_VIBRATE)

        Log.d(TAG, "📱 Telefon modu: $ringerMode (NORMAL=2, VIBRATE=1, SILENT=0)")
        Log.d(TAG, "📱 Telefon sessiz mi: $wasPhoneSilentBefore")

        var soundUri: android.net.Uri? = null
        if (!wasPhoneSilentBefore) {
            val soundName = resolveSoundFile(soundFile)
            val resId = resources.getIdentifier(soundName, "raw", packageName)
            if (resId != 0) {
                soundUri = android.net.Uri.parse("android.resource://$packageName/$resId")
            }
        }

        createNotificationChannels(soundUri)

        val notification = createAlarmNotification(currentVakitName, currentVakitTime, isCurrentAlarmEarly, earlyMinutes, soundUri)
        startForeground(NOTIFICATION_ID, notification)

        // Telefonun sessizde olup olmamasından bağımsız olarak, bildirim kanalı titreşimi yönetecek.
        // Bu yüzden manuel titreşim kontrolü ve gecikmeli durdurma kaldırıldı.
        // Servis, bildirim gösterildikten kısa bir süre sonra kendini durdurabilir.
        handler.postDelayed({
            setAlarmActiveFlag(false)
            if (!isCurrentAlarmEarly && isSessizeAlEnabled) {
                showSilentModeNotification()
            }
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }, 5000) // 5 saniye sonra servisi durdur.

        // Ses ve titreşim bildirim tarafından yönetilecek
        isPlaying = true // Set playing true to handle stop actions

        startLockScreenActivity(currentVakitName, currentVakitTime, isCurrentAlarmEarly, earlyMinutes)
    }
    
    /**
     * Alarmı durdur (Kapat butonu veya tuş)
     */
    private fun handleStopAlarm() {
        Log.d(TAG, "🔇 Alarm durduruluyor...")
        
        stopVibration()
        setAlarmActiveFlag(false)
        handler.removeCallbacksAndMessages(null)
        
        // Telefon başlangıçta sessiz modda değilse VE vaktinde bildirimse VE sessize al açıksa
        if (!wasPhoneSilentBefore && !isCurrentAlarmEarly && isSessizeAlEnabled) {
            Log.d(TAG, "🔇 Vaktinde bildirim - telefon sessize alınıyor")
            setSilentMode(true)
            showSilentModeNotification()
        }
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     * "Kal" butonu - sessiz modda kal
     */
    private fun handleStaySilent() {
        Log.d(TAG, "🔇 'Kal' tıklandı - sessiz modda kalınıyor")
        
        stopVibration()
        setAlarmActiveFlag(false)
        handler.removeCallbacksAndMessages(null)
        
        // Zaten sessiz moddaysak veya değilsek, sessize al
        setSilentMode(true)
        
        // Sessiz mod bildirimi göster
        showSilentModeNotification()
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     * "Çık" butonu - sessiz moddan çık
     */
    private fun handleExitSilent() {
        Log.d(TAG, "🔊 'Çık' tıklandı - normal moda dönülüyor")
        
        stopVibration()
        setAlarmActiveFlag(false)
        handler.removeCallbacksAndMessages(null)
        
        // Telefonu normale döndür
        setSilentMode(false)
        
        // Sessiz mod bildirimini kaldır
        cancelSilentModeNotification()
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    private fun createNotificationChannels(soundUri: android.net.Uri?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Alarm kanalı
            val alarmChannel = NotificationChannel(
                CHANNEL_ID,
                "Vakit Alarmları",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Namaz vakti alarm bildirimleri"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(alarmChannel)

            // Sessiz mod kanalı
            val silentChannel = NotificationChannel(
                SILENT_MODE_CHANNEL_ID,
                "Sessiz Mod Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Vakitlerde sessize al bildirimleri"
                setShowBadge(true)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(silentChannel)
        }
    }
    
    private fun createAlarmNotification(vakitName: String, vakitTime: String, isEarly: Boolean, earlyMinutes: Int, soundUri: android.net.Uri?): Notification {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
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
            .setOngoing(false)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Kapat", stopPendingIntent)

        if (soundUri != null) {
            builder.setSound(soundUri)
        }

        if (!isEarly && isSessizeAlEnabled) {
            val stayIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_STAY_SILENT
            }
            val stayPendingIntent = PendingIntent.getService(
                this, 2, stayIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_lock_silent_mode, "Kal (Sessiz)", stayPendingIntent)

            val exitIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_EXIT_SILENT
            }
            val exitPendingIntent = PendingIntent.getService(
                this, 3, exitIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_lock_silent_mode_off, "Çık (Normal)", exitPendingIntent)
        }

        return builder.build()
    }

    /**
     * Ses dosyası adını çözümle
     * Öncelik sırası:
     * 1. SharedPreferences'taki kullanıcı tercihi (erken/vaktinde ayrımı yapılır)
     * 2. Intent'ten gelen ses (zamanlama sırasında doğru çözümlenmiş)
     * 3. SharedPreferences'taki vaktinde ses (erken alarm için fallback)
     * 4. Varsayılan ses ("best")
     */
    private fun resolveSoundFile(soundFile: String): String {
        val vakitKey = normalizeVakitName(currentVakitName)
        // Intent'ten gelen sesi normalize et - bu zaten zamanlama sırasında doğru çözümlenmiş
        val intentSound = normalizeSoundName(soundFile)
        val defaultSound = "best"

        if (vakitKey.isNotEmpty()) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val earlyKey = "flutter.erken_bildirim_sesi_$vakitKey"
            val onTimeKey = "flutter.bildirim_sesi_$vakitKey"
            val primaryKey = if (isCurrentAlarmEarly) earlyKey else onTimeKey
            val fallbackKey = if (isCurrentAlarmEarly) onTimeKey else earlyKey

            val primarySound = prefs.getString(primaryKey, null)
            val fallbackSound = prefs.getString(fallbackKey, null)
            Log.d(TAG, "🔊 SharedPreferences kontrol: $primaryKey -> '$primarySound', fallback: $fallbackKey -> '$fallbackSound'")
            Log.d(TAG, "🔊 Intent ses: '$intentSound'")

            val resolvedSound = when {
                // Kullanıcının seçtiği ses
                !primarySound.isNullOrEmpty() && primarySound != "custom" -> primarySound
                // Intent'ten gelen ses (zamanlama sırasında doğru çözümlenmiş)
                intentSound.isNotEmpty() -> intentSound
                // Vaktinde ses (erken alarm için fallback)
                !fallbackSound.isNullOrEmpty() && fallbackSound != "custom" -> fallbackSound
                else -> null
            }

            if (!resolvedSound.isNullOrEmpty()) {
                val normalizedSound = normalizeSoundName(resolvedSound)
                if (normalizedSound.isNotEmpty()) {
                    Log.d(TAG, "✅ Ses çözümlendi: '$resolvedSound' -> '$normalizedSound'")
                    return normalizedSound
                }
            }

            Log.d(TAG, "⚠️ Ses bulunamadı, varsayılan: '$defaultSound'")
            return defaultSound
        }

        // vakitKey bos ise intent sesini veya varsayılanı kullan
        if (intentSound.isNotEmpty()) {
            Log.d(TAG, "✅ vakitKey boş, intent sesi kullanılıyor: '$intentSound'")
            return intentSound
        }
        Log.d(TAG, "⚠️ vakitKey bos, varsayılan: '$defaultSound'")
        return defaultSound
    }

    private fun normalizeSoundName(soundName: String): String {
        var name = soundName.trim().lowercase()
        if (name.contains('/')) {
            name = name.substringAfterLast('/')
        }
        if (name.endsWith(".mp3")) {
            name = name.dropLast(4)
        }
        name = name.replace(" ", "_").replace("-", "_")
        return name
    }
    
    /**
     * Vakit adını normalize et (Türkçe karakterleri dönüştür)
     */
    private fun normalizeVakitName(vakitName: String): String {
        // Önce Türkçe büyük harfleri de dönüştür
        val normalized = vakitName.lowercase(java.util.Locale("tr", "TR"))
            .replace("ı", "i").replace("ö", "o").replace("ü", "u")
            .replace("ş", "s").replace("ğ", "g").replace("ç", "c")
            .replace("İ", "i").replace("i̇", "i") // Büyük İ ve combining dot
        
        Log.d(TAG, "🔄 normalizeVakitName: '$vakitName' -> '$normalized'")
        
        return when {
            normalized.contains("imsak") || normalized.contains("sahur") -> "imsak"
            normalized.contains("gunes") -> "gunes"
            normalized.contains("ogle") -> "ogle"
            normalized.contains("ikindi") -> "ikindi"
            normalized.contains("aksam") -> "aksam"
            normalized.contains("yatsi") -> "yatsi"
            else -> ""
        }
    }
    
    /**
     * Ses hatası durumunda fallback
     */
    private fun handleSoundError() {
        try {
            val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSound(defaultUri)
                .build()
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e2: Exception) {
            Log.e(TAG, "❌ Fallback ses de çalınamadı: ${e2.message}")
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
                putExtra("was_phone_silent", wasPhoneSilentBefore)
            }
            startActivity(intent)
            Log.d(TAG, "🖥️ Kilit ekranı activity başlatıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Kilit ekranı activity hatası: ${e.message}")
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
                        Log.d(TAG, "📴 Güç tuşu ile ekran kapatıldı")
                        handleStopAlarm()
                    }
                }
            }
            
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenOffReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenOffReceiver, filter)
            }
            Log.d(TAG, "📴 Screen off receiver kuruldu")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Screen off receiver hatası: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        stopVibration()
        handler.removeCallbacksAndMessages(null)
        
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
     * Alarm aktif flag'ini ayarla
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
     */
    private fun setSilentMode(silent: Boolean) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            if (silent) {
                // Önceki ringer mode'u kaydet
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
     * Sessize alındığını bildiren bildirim göster
     */
    private fun showSilentModeNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // "Normale Dön" butonu
            val normalModeIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_EXIT_SILENT
            }
            val normalModePendingIntent = PendingIntent.getService(
                this, 100, normalModeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Bildirimin kendisine tıklanınca da normale dönsün
            val contentIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_EXIT_SILENT
            }
            val contentPendingIntent = PendingIntent.getService(
                this, 101, contentIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, SILENT_MODE_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("🔇 Telefon Sessize Alındı")
                .setContentText("$currentVakitName vakti için telefon sessize alındı. Normale dönmek için tıklayın.")
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("$currentVakitName vakti için telefon sessize alındı.\n\nNamaz bittiğinde normale dönmek için aşağıdaki butona basın."))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(contentPendingIntent)
                .setAutoCancel(true)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_lock_silent_mode_off, "🔊 Normale Dön", normalModePendingIntent)
                .build()
            
            notificationManager.notify(SILENT_MODE_NOTIFICATION_ID, notification)
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
            notificationManager.cancel(SILENT_MODE_NOTIFICATION_ID)
            Log.d(TAG, "📢 Sessiz mod bildirimi kaldırıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Bildirim kaldırma hatası: ${e.message}")
        }
    }
}
