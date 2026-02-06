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

    private fun createDailyContentNotification(title: String, body: String, channelId: String): Notification {
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

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(mainPendingIntent)
            .setFullScreenIntent(mainPendingIntent, true)
            .setAutoCancel(false) // Tıklayınca kapanmasın, kullanıcı manuel kapat butonuna bassın
            .addAction(0, "Kapat", stopPendingIntent)
            .build()
    }

    private fun resolveSoundFile(vakitName: String, intentSound: String, isEarly: Boolean): String {
        val vakitKey = normalizeVakitName(vakitName)
        if (vakitKey.isEmpty()) return normalizeSoundName(intentSound)

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val earlyKey = "flutter.erken_bildirim_sesi_$vakitKey"
        val onTimeKey = "flutter.bildirim_sesi_$vakitKey"

        val primaryKey = if (isEarly) earlyKey else onTimeKey
        val fallbackKey = if (isEarly) onTimeKey else null

        var sound = prefs.getString(primaryKey, null)
        if (sound.isNullOrEmpty() && fallbackKey != null) {
            sound = prefs.getString(fallbackKey, null)
        }
        if (sound.isNullOrEmpty()) {
            sound = intentSound
        }

        val finalSound = normalizeSoundName(sound ?: "best")
        Log.d(TAG, "✅ Ses çözümlendi: $finalSound (Vakit: $vakitKey, Erken: $isEarly)")
        return finalSound
    }

    private fun normalizeSoundName(soundName: String): String {
        return soundName.lowercase().replace(".mp3", "").replace(" ", "_").replace("-", "_")
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

    override fun onDestroy() {
        stopAlarm()
        wakeLock?.release()
        instance = null
        super.onDestroy()
        Log.d(TAG, "🔔 AlarmService sonlandırıldı")
    }
}
