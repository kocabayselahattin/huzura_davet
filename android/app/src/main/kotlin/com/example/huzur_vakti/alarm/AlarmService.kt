package com.example.huzur_vakti.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
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
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
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
            else -> {
                // Alarm başlat
                val alarmId = intent?.getIntExtra(AlarmReceiver.EXTRA_ALARM_ID, 0) ?: 0
                currentVakitName = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_NAME) ?: "Vakit"
                currentVakitTime = intent?.getStringExtra(AlarmReceiver.EXTRA_VAKIT_TIME) ?: ""
                val soundFile = intent?.getStringExtra(AlarmReceiver.EXTRA_SOUND_FILE) ?: "ding_dong"
                val isEarly = intent?.getBooleanExtra(AlarmReceiver.EXTRA_IS_EARLY, false) ?: false
                val earlyMinutes = intent?.getIntExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0) ?: 0
                
                // Foreground service olarak başlat
                val notification = createAlarmNotification(currentVakitName, currentVakitTime, isEarly, earlyMinutes)
                startForeground(NOTIFICATION_ID, notification)
                
                // Alarm sesini çal
                playAlarmSound(soundFile)
                
                // Titreşim başlat
                startVibration()
                
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
        
        // Alarmı durdur butonu
        val stopIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Ertele butonu
        val snoozeIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_SNOOZE_ALARM
        }
        val snoozePendingIntent = PendingIntent.getService(
            this, 2, snoozeIntent,
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
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
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
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Kapat", stopPendingIntent)
            .addAction(android.R.drawable.ic_menu_recent_history, "5 dk Ertele", snoozePendingIntent)
            .build()
    }
    
    private fun playAlarmSound(soundFile: String) {
        try {
            stopAlarmSound() // Önceki sesi durdur
            
            mediaPlayer = MediaPlayer().apply {
                // Ses kaynağını ayarla
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setAudioAttributes(audioAttributes)
                
                // Raw klasöründen ses dosyasını bul
                val soundName = soundFile.replace(".mp3", "").lowercase()
                    .replace(" ", "_").replace("-", "_")
                
                val resId = resources.getIdentifier(soundName, "raw", packageName)
                
                if (resId != 0) {
                    val afd = resources.openRawResourceFd(resId)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } else {
                    // Varsayılan alarm sesi
                    val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    setDataSource(this@AlarmService, defaultUri)
                }
                
                isLooping = true
                prepare()
                start()
            }
            
            isPlaying = true
            Log.d(TAG, "🔊 Alarm sesi çalıyor: $soundFile")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Alarm sesi çalma hatası: ${e.message}")
            // Fallback - sistem alarm sesi
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(this@AlarmService, defaultUri)
                    isLooping = true
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
            
            vibrator?.cancel()
            vibrator = null
            
            Log.d(TAG, "🔇 Alarm sesi durduruldu")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ses durdurma hatası: ${e.message}")
        }
    }
    
    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            // Titreşim paterni: bekle, titret, bekle, titret...
            val pattern = longArrayOf(0, 500, 200, 500, 200, 500, 1000)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
    
    override fun onDestroy() {
        stopAlarmSound()
        instance = null
        super.onDestroy()
        Log.d(TAG, "🔔 AlarmService sonlandırıldı")
    }
}
