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
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import com.example.huzur_vakti.MainActivity
import com.example.huzur_vakti.R

class AlarmService : Service() {

    companion object {
        private const val TAG = "AlarmService"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID_ALARM = "huzur_vakti_alarm_channel" // Sesli alarmlar için
        const val CHANNEL_ID_SILENT = "huzur_vakti_silent_channel" // Titreşimli alarmlar için
        const val ACTION_STOP_ALARM = "com.example.huzur_vakti.STOP_ALARM"
        const val ACTION_STAY_SILENT = "com.example.huzur_vakti.STAY_SILENT"  // Kal butonu (compatibility)
        const val ACTION_EXIT_SILENT = "com.example.huzur_vakti.EXIT_SILENT"  // Çık butonu (compatibility)
        
        @Volatile
        private var instance: AlarmService? = null
        
        fun isAlarmPlaying(): Boolean = instance?.isPlaying ?: false
        
        fun stopAlarm(context: Context) {
            val intent = Intent(context, AlarmService::class.java).apply {
                action = ACTION_STOP_ALARM
            }
            context.startService(intent)
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    // isPlaying'i dışarıdan erişilebilir yapmak için
    private var isPlaying = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HuzurVakti::AlarmServiceWakeLock")
        wakeLock?.setReferenceCounted(false)
        Log.d(TAG, "🔔 AlarmService oluşturuldu")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        wakeLock?.acquire(3 * 60 * 1000L) // 3 dakika wakelock
        Log.d(TAG, "📢 onStartCommand: ${intent?.action}")

        if (intent?.action == ACTION_STOP_ALARM) {
            stopAlarm()
            return START_NOT_STICKY
        }

        handleAlarmStart(intent)
        return START_STICKY
    }

    private fun handleAlarmStart(intent: Intent?) {
        val vakitName = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_NAME) ?: "Vakit"
        val soundFile = intent?.getStringExtra(AlarmReceiver.EXTRA_SOUND_FILE) ?: "best"
        val isEarly = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false) ?: false
        val earlyMinutes = intent?.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0) ?: 0
        val contentBody = intent?.getStringExtra("content_body") // Günlük içerik için
        val isDailyContent = intent?.action == "DAILY_CONTENT_ALARM"

        Log.d(TAG, "🎶 Gelen ses dosyası: $soundFile, Erken: $isEarly, Günlük İçerik: $isDailyContent")

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        val isSilentOrVibrate = ringerMode == AudioManager.RINGER_MODE_SILENT || ringerMode == AudioManager.RINGER_MODE_VIBRATE

        Log.d(TAG, "📱 Telefon modu: $ringerMode (Sessiz/Titreşim: $isSilentOrVibrate)")

        val finalSound = if (isDailyContent) {
            normalizeSoundName(soundFile)
        } else {
            resolveSoundFile(vakitName, soundFile, isEarly)
        }
        
        createNotificationChannels()

        val channelId = if (isSilentOrVibrate) CHANNEL_ID_SILENT else CHANNEL_ID_ALARM
        val notification = if (isDailyContent) {
            createDailyContentNotification(vakitName, contentBody ?: "", channelId)
        } else {
            createAlarmNotification(vakitName, isEarly, earlyMinutes, channelId)
        }
        startForeground(NOTIFICATION_ID, notification)

        if (isSilentOrVibrate) {
            Log.d(TAG, "📳 Telefon sessizde, sadece titreşim.")
            startVibration()
        } else {
            Log.d(TAG, "🔊 Ses çalınıyor: $finalSound")
            playSound(finalSound)
            startVibration() // Sesle birlikte titreşim de olsun
        }
    }

    private fun playSound(soundName: String) {
        mediaPlayer?.release()
        val resId = resources.getIdentifier(soundName, "raw", packageName)
        if (resId == 0) {
            Log.e(TAG, "❌ Ses dosyası bulunamadı: $soundName")
            // Ses bulunamazsa, alarmı durdur ve servisi sonlandır
            stopAlarm()
            return
        }

        mediaPlayer = MediaPlayer().apply {
            setDataSource(applicationContext, android.net.Uri.parse("android.resource://$packageName/$resId"))
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = false // Sesin tekrar etmesini engelle
            prepareAsync()
            setOnPreparedListener {
                it.start()
                this@AlarmService.isPlaying = true
            }
            setOnCompletionListener {
                // Ses bittiğinde alarmı otomatik olarak durdur
                Log.d(TAG, "✅ Ses dosyası tamamlandı, alarm durduruluyor.")
                stopAlarm()
            }
            setOnErrorListener { _, _, _ ->
                Log.e(TAG, "❌ MediaPlayer hatası")
                this@AlarmService.isPlaying = false
                // Hata durumunda da alarmı durdur
                stopAlarm()
                true
            }
        }
    }

    private fun startVibration() {
        vibrator?.cancel()
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 500), 0))
    }

    private fun stopAlarm() {
        Log.d(TAG, "🔇 Alarm durduruluyor...")
        handler.removeCallbacksAndMessages(null)
        if (mediaPlayer?.isPlaying == true) {
            mediaPlayer?.stop()
        }
        mediaPlayer?.release()
        mediaPlayer = null
        isPlaying = false
        vibrator?.cancel()
        stopForeground(true)
        stopSelf()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Sesli alarmlar için kanal
            val alarmChannel = NotificationChannel(
                CHANNEL_ID_ALARM,
                "Vakit Alarmları (Sesli)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sesli namaz vakti alarmları"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null) // Sesi biz çalacağımız için null
                enableVibration(false) // Titreşimi biz yöneteceğiz
            }
            notificationManager.createNotificationChannel(alarmChannel)

            // Sessiz/Titreşimli alarmlar için kanal
            val silentChannel = NotificationChannel(
                CHANNEL_ID_SILENT,
                "Vakit Alarmları (Sessiz)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sessiz modda gösterilen titreşimli alarmlar"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(true) // Sadece titreşim için kanala güvenebiliriz
            }
            notificationManager.createNotificationChannel(silentChannel)
        }
    }

    private fun createAlarmNotification(vakitName: String, isEarly: Boolean, earlyMinutes: Int, channelId: String): Notification {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AlarmService::class.java).apply { action = ACTION_STOP_ALARM }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isEarly) "$vakitName Vakti Yaklaşıyor" else "$vakitName Vakti Girdi"
        val body = if (isEarly) "$vakitName vaktine $earlyMinutes dakika kaldı." else "Hayırlı ibadetler!"

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(mainPendingIntent)
            .setFullScreenIntent(mainPendingIntent, true)
            .setAutoCancel(false) // Tıklayınca kapanmasın, kullanıcı manuel kapat butonuna bassın
            .addAction(0, "Kapat", stopPendingIntent)
            .build()
    }
    
    /**
     * Alarm sesini çal
     */
    private fun playAlarmSound(soundFile: String) {
        try {
            stopAlarmSound() // Önceki sesi durdur
            
            // Ses dosyası adını belirle
            val actualSoundFile = resolveSoundFile(soundFile)
            
            Log.d(TAG, "🔊 Alarm sesi başlatılıyor: $actualSoundFile")
            
            // Raw klasöründen ses dosyasını bul - geliştirilmiş normalizasyon
            var soundName = actualSoundFile.replace(".mp3", "").lowercase()
                .replace(" ", "_").replace("-", "_")
                .replace(Regex("[^a-z0-9_]"), "_")
                .replace(Regex("_+"), "_")
                .trim('_')
            
            if (soundName.isEmpty()) soundName = "best"
            
            Log.d(TAG, "🔍 Ses dosyası aranıyor: '$soundName'")
            
            var resId = resources.getIdentifier(soundName, "raw", packageName)
            
            // Bulunamazsa best dene, sonra ding_dong
            if (resId == 0) {
                Log.w(TAG, "⚠️ Ses bulunamadı: $soundName - best deneniyor")
                resId = resources.getIdentifier("best", "raw", packageName)
            }
            
            if (resId == 0) {
                Log.w(TAG, "⚠️ best de bulunamadı - ding_dong deneniyor")
                resId = resources.getIdentifier("ding_dong", "raw", packageName)
            }
            
            if (resId != 0) {
                Log.d(TAG, "✅ Ses dosyası bulundu: $soundName (ID: $resId)")
                
                mediaPlayer = MediaPlayer()
                
                // ALARM stream kullan - daha yüksek ses seviyesi için
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                mediaPlayer?.setAudioAttributes(audioAttributes)
                
                val afd = resources.openRawResourceFd(resId)
                try {
                    mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    mediaPlayer?.prepare()
                } finally {
                    afd.close()
                }
            } else {
                // Varsayılan sistem bildirim sesi
                Log.w(TAG, "⚠️ Hiçbir ses dosyası bulunamadı - varsayılan bildirim sesi kullanılacak")
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer()
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                mediaPlayer?.setAudioAttributes(audioAttributes)
                mediaPlayer?.setDataSource(this@AlarmService, defaultUri)
                mediaPlayer?.prepare()
            }
            
            // Ses tek seferde çalacak (loop yok)
            mediaPlayer?.isLooping = false
            
            // Ses bittiğinde
            mediaPlayer?.setOnCompletionListener {
                Log.d(TAG, "🔊 Alarm sesi tamamlandı")
                stopVibration()
                isPlaying = false
                setAlarmActiveFlag(false)
                
                // Vaktinde bildirim VE sessize al açıksa VE telefon başta sessiz değilse telefonu sessize al
                if (!isCurrentAlarmEarly && isSessizeAlEnabled && !wasPhoneSilentBefore) {
                    Log.d(TAG, "🔇 Vaktinde bildirim sesi bitti - telefon sessize alınıyor")
                    setSilentMode(true)
                    showSilentModeNotification()
                }
                
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            
            mediaPlayer?.start()
            isPlaying = true
            Log.d(TAG, "🔊 Alarm sesi çalıyor: $actualSoundFile")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Alarm sesi çalma hatası: ${e.message}")
            e.printStackTrace()
            handleSoundError()
        }
    }
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AlarmService::class.java).apply { action = ACTION_STOP_ALARM }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
    
                /**
                 * Ses dosyası adını çözümle
                 * ÖNEMLİ: Ses zaten AlarmReceiver'da doğru çözülmüş ve normalize edilmiş olarak geliyor
                 * Bu metot sadece son bir güvenlik kontrolü yapıyor
                 */
                private fun resolveSoundFile(soundFile: String): String {
                    // Intent'ten gelen ses zaten doğru - sadece normalize et
                    val normalizedSound = normalizeSoundName(soundFile)
        
                    if (normalizedSound.isNotEmpty()) {
                        Log.d(TAG, "✅ Ses: '$soundFile' -> '$normalizedSound'")
                        return normalizedSound
                    }
        
                    Log.d(TAG, "⚠️ Ses boş, varsayılan: 'best'")
                    return "best"
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
                        .replace(Regex("[^a-z0-9_]"), "_")
                        .replace(Regex("_+"), "_")
                        .trim('_')
                    return if (name.isEmpty()) "best" else name
                }
            sound = intentSound
        }

        val finalSound = normalizeSoundName(sound ?: "best")
        Log.d(TAG, "✅ Ses çözümlendi: $finalSound (Vakit: $vakitKey, Erken: $isEarly)")
        return finalSound
    }

    private fun normalizeSoundName(soundName: String): String {
        return soundName.lowercase().replace(".mp3", "").replace(" ", "_").replace("-", "_")
>>>>>>> 490131a10a957f52d4660a1732924c566a04f965
    }

    private fun normalizeVakitName(vakitName: String): String {
        val normalized = vakitName.lowercase(java.util.Locale("tr", "TR"))
        return when {
            normalized.contains("imsak") -> "imsak"
            normalized.contains("gunes") -> "gunes"
            normalized.contains("ogle") -> "ogle"
            normalized.contains("ikindi") -> "ikindi"
            normalized.contains("aksam") -> "aksam"
            normalized.contains("yatsi") -> "yatsi"
            else -> ""
        }
    }
<<<<<<< HEAD
    
    /**
     * Ses hatası durumunda fallback
     */
    private fun handleSoundError() {
        try {
            val dingDongId = resources.getIdentifier("ding_dong", "raw", packageName)
            if (dingDongId != 0) {
                mediaPlayer = MediaPlayer.create(this@AlarmService, dingDongId)
                mediaPlayer?.let {
                    val audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    it.setAudioAttributes(audioAttributes)
                }
            } else {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer()
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                mediaPlayer?.setAudioAttributes(audioAttributes)
                mediaPlayer?.setDataSource(this@AlarmService, defaultUri)
                mediaPlayer?.prepare()
            }
            
            mediaPlayer?.apply {
                isLooping = false
                setOnCompletionListener {
                    stopVibration()
                    this@AlarmService.isPlaying = false
                    setAlarmActiveFlag(false)
                    
                    if (!isCurrentAlarmEarly && isSessizeAlEnabled && !wasPhoneSilentBefore) {
                        setSilentMode(true)
                        showSilentModeNotification()
                    }
                    
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
                start()
            }
            this@AlarmService.isPlaying = true
        } catch (e2: Exception) {
            Log.e(TAG, "❌ Fallback ses de çalınamadı: ${e2.message}")
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
            this.isPlaying = false
            Log.d(TAG, "🔇 Alarm sesi durduruldu")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ses durdurma hatası: ${e.message}")
        }
    }
    
    /**
     * Titreşimi başlat - tekrarlı pattern
     */
    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            // Titreşim paterni - bekle, titret, bekle, titret...
            val pattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 0 = sonsuz döngü
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            
            Log.d(TAG, "📳 Titreşim başlatıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Titreşim hatası: ${e.message}")
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
     * MediaSession ile ses tuşlarını dinle
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
                                    handleStopAlarm()
                                    return true
                                }
                            }
                        }
                        return super.onMediaButtonEvent(mediaButtonIntent)
                    }
                })
                isActive = true
            }
            Log.d(TAG, "🎧 MediaSession kuruldu")
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
    
=======

>>>>>>> 490131a10a957f52d4660a1732924c566a04f965
    override fun onDestroy() {
        stopAlarm()
        wakeLock?.release()
        instance = null
        super.onDestroy()
        Log.d(TAG, "🔔 AlarmService sonlandırıldı")
    }
}
