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
        val soundId = intent?.getStringExtra(AlarmReceiver.EXTRA_SOUND_FILE) ?: "best"
        val isEarly = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false) ?: false
        val earlyMinutes = intent?.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0) ?: 0
        val contentBody = intent?.getStringExtra("content_body") // Günlük içerik için
        val isDailyContent = intent?.action == "DAILY_CONTENT_ALARM"

        Log.d(TAG, "🎶 Gelen ses ID'si: $soundId, Erken: $isEarly, Günlük İçerik: $isDailyContent")

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        val isSilentOrVibrate = ringerMode == AudioManager.RINGER_MODE_SILENT || ringerMode == AudioManager.RINGER_MODE_VIBRATE

        Log.d(TAG, "📱 Telefon modu: $ringerMode (Sessiz/Titreşim: $isSilentOrVibrate)")
        
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
            Log.d(TAG, "🔊 Ses çalınıyor: $soundId")
            playSound(soundId)
            startVibration() // Sesle birlikte titreşim de olsun
        }
    }

    /**
     * Ses ID'sinden Android resource ID'sine dönüşüm
     * Flutter tarafından gelen ID'ler ("best", "aksam_ezani" vs.) direkt mapping ile eşleşiyor
     */
    private fun getSoundResourceId(soundId: String): Int {
        return when(soundId.lowercase().trim()) {
            "aksam_ezani" -> R.raw.aksam_ezani
            "aksam_ezani_segah" -> R.raw.aksam_ezani_segah
            "ayasofya_ezan_sesi" -> R.raw.ayasofya_ezan_sesi
            "best" -> R.raw.best
            "corner" -> R.raw.corner
            "ding_dong" -> R.raw.ding_dong
            "esselatu_hayrun_minen_nevm1" -> R.raw.esselatu_hayrun_minen_nevm1
            "esselatu_hayrun_minen_nevm2" -> R.raw.esselatu_hayrun_minen_nevm2
            "ikindi_ezani_hicaz" -> R.raw.ikindi_ezani_hicaz
            "melodi" -> R.raw.melodi
            "mescid_i_nebi_sabah_ezani" -> R.raw.mescid_i_nebi_sabah_ezani
            "ney_uyan" -> R.raw.ney_uyan
            "ogle_ezani_rast" -> R.raw.ogle_ezani_rast
            "sabah_ezani_saba" -> R.raw.sabah_ezani_saba
            "snaps" -> R.raw.snaps
            "sweet_favour" -> R.raw.sweet_favour
            "violet" -> R.raw.violet
            "yatsi_ezani_ussak" -> R.raw.yatsi_ezani_ussak
            else -> {
                Log.w(TAG, "⚠️ Bilinmeyen ses ID'si: $soundId, varsayılan 'best' kullanılıyor")
                R.raw.best
            }
        }
    }

    private fun playSound(soundId: String) {
        mediaPlayer?.release()
        val resId = getSoundResourceId(soundId)
        Log.d(TAG, "🎵 Ses çalınıyor - ID: $soundId, Resource ID: $resId")

        mediaPlayer = MediaPlayer().apply {
            setDataSource(applicationContext, android.net.Uri.parse("android.resource://$packageName/$resId"))
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = false
            prepareAsync()
            setOnPreparedListener {
                it.start()
                this@AlarmService.isPlaying = true
            }
            setOnCompletionListener {
                Log.d(TAG, "✅ Ses dosyası tamamlandı, alarm durduruluyor.")
                stopAlarm()
            }
            setOnErrorListener { _, _, _ ->
                Log.e(TAG, "❌ MediaPlayer hatası")
                this@AlarmService.isPlaying = false
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
            .setContentIntent(mainPendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(R.drawable.ic_launcher_foreground, "Kapat", stopPendingIntent)
            .build()
    }

    /**
     * DEPRECATED: Artık kullanılmıyor, geriye dönük uyumluluk için bırakılmış
     * Ses ID'si direkt Flutter'dan geliyor ve getSoundResourceId() ile map ediliyor
     */

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
