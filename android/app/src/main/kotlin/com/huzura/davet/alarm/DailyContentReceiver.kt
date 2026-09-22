package com.huzura.davet.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.huzura.davet.BildirimIkonu
import com.huzura.davet.R

/**
 * Günlük içerik bildirimlerini alan BroadcastReceiver
 * AlarmManager tarafından tetiklenir ve bildirimi gösterir
 */
class DailyContentReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "DailyContentReceiver"
        private const val CHANNEL_ID = "daily_content_channel_v4"
        const val ACTION_DAILY_CONTENT = "com.huzura.davet.DAILY_CONTENT"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_SOUND_FILE = "sound_file"
        // "verse" | "hadith" | "prayer" | "tahajjud" — bildirime tıklanınca
        // Flutter tarafında hangi içeriğin açılacağını belirtir.
        const val EXTRA_CONTENT_TYPE = "content_type"

        /**
         * Günlük içerik bildirimi zamanla
         */
        fun scheduleDailyContent(
            context: Context,
            notificationId: Int,
            title: String,
            body: String,
            triggerAtMillis: Long,
            soundFile: String,
            // true ise (teheccüd) vakit/erken alarmlarıyla aynı setAlarmClock
            // kullanılır - Doze'dan tamamen muaf, en güvenilir alarm türü
            // (bkz. AlarmReceiver.kt). Diğer günlük içerikler (ayet/hadis/dua)
            // bilgilendirme amaçlı olduğundan varsayılan false ile daha az
            // öncelikli setExactAndAllowWhileIdle kullanmaya devam eder.
            useAlarmClock: Boolean = false,
            contentType: String = ""
        ): Boolean {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, DailyContentReceiver::class.java).apply {
                action = ACTION_DAILY_CONTENT
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_SOUND_FILE, soundFile)
                putExtra(EXTRA_CONTENT_TYPE, contentType)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerTime = java.text.SimpleDateFormat("dd.MM.yyyy HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date(triggerAtMillis))
            Log.d(TAG, "📅 Günlük içerik zamanlanıyor: $title - $triggerTime (ID: $notificationId, alarmClock: $useAlarmClock)")

            return try {
                if (useAlarmClock && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Günlük içerik setAlarmClock ile zamanlandı")
                    true
                } else if (useAlarmClock && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Günlük içerik setAlarmClock ile zamanlandı (M+)")
                    true
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val canScheduleExact = alarmManager.canScheduleExactAlarms()
                    if (canScheduleExact) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ Günlük içerik setExactAndAllowWhileIdle ile zamanlandı")
                        true
                    } else {
                        Log.w(TAG, "⚠️ Exact alarm izni yok!")
                        false
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Günlük içerik setExactAndAllowWhileIdle ile zamanlandı (M+)")
                    true
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Günlük içerik setExact ile zamanlandı")
                    true
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Günlük içerik zamanlama hatası: ${e.message}")
                false
            }
        }
        
        /**
         * Günlük içerik bildirimini iptal et
         */
        fun cancelDailyContent(context: Context, notificationId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, DailyContentReceiver::class.java).apply {
                action = ACTION_DAILY_CONTENT
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            
            Log.d(TAG, "🚫 Günlük içerik bildirimi iptal edildi (ID: $notificationId)")
        }
        
        /**
         * Tüm günlük içerik bildirimlerini iptal et
         */
        fun cancelAllDailyContent(context: Context) {
            // 7 gün * 3 bildirim türü (ayet, hadis, dua)
            for (day in 0..6) {
                cancelDailyContent(context, 1000 + day * 10) // Ayet
                cancelDailyContent(context, 1001 + day * 10) // Hadis
                cancelDailyContent(context, 1002 + day * 10) // Dua
            }
            Log.d(TAG, "🚫 Tüm günlük içerik bildirimleri iptal edildi")
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📢 Günlük içerik alarmı alındı: ${intent.action}")
        
        when (intent.action) {
            ACTION_DAILY_CONTENT -> {
                // Wake lock al
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "HuzurVakti::DailyContentWakeLock"
                )
                wakeLock.acquire(60_000L) // 60 saniye
                
                try {
                    val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
                    val title = intent.getStringExtra(EXTRA_TITLE) ?: "Huzura Davet"
                    val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                    val soundId = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "ding_dong"
                    val contentType = intent.getStringExtra(EXTRA_CONTENT_TYPE) ?: ""

                    Log.d(TAG, "🔔 Günlük içerik için AlarmService başlatılıyor: $title (ses ID: $soundId)")

                    // AlarmService'i başlat - böylece alarm sesi doğru çalar
                    val serviceIntent = Intent(context, AlarmService::class.java).apply {
                        action = "DAILY_CONTENT_ALARM"
                        putExtra(AlarmReceiver.EXTRA_ALARM_ID, notificationId)
                        putExtra(AlarmReceiver.EXTRA_VAKIT_NAME, title)
                        putExtra(AlarmReceiver.EXTRA_VAKIT_TIME, "")
                        putExtra(AlarmReceiver.EXTRA_SOUND_FILE, soundId)
                        putExtra(AlarmReceiver.EXTRA_IS_EARLY, false)
                        putExtra(AlarmReceiver.EXTRA_EARLY_MINUTES, 0)
                        putExtra("content_body", body) // Günlük içerik için body ekstra
                        putExtra("content_type", contentType)
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    
                    Log.d(TAG, "✅ AlarmService başlatıldı")
                } finally {
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                }
            }
        }
    }
    
    private fun showNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        soundFile: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        val isPhoneSilent = (ringerMode == AudioManager.RINGER_MODE_SILENT ||
                ringerMode == AudioManager.RINGER_MODE_VIBRATE)

        Log.d(TAG, "📱 Telefon modu: $ringerMode (NORMAL=2, VIBRATE=1, SILENT=0), Sessiz: $isPhoneSilent")

        var soundUri: Uri? = null
        if (!isPhoneSilent) {
            var soundResourceName = soundFile.replace(".mp3", "").lowercase()
                .replace(" ", "_").replace("-", "_")
                .replace(Regex("[^a-z0-9_]"), "_")
            if (soundResourceName.isEmpty()) soundResourceName = "ding_dong"

            var resId = context.resources.getIdentifier(soundResourceName, "raw", context.packageName)
            if (resId == 0) {
                resId = context.resources.getIdentifier("ding_dong", "raw", context.packageName)
            }

            if (resId != 0) {
                soundUri = Uri.parse("android.resource://${context.packageName}/$resId")
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                notificationManager.deleteNotificationChannel("daily_content_channel")
                notificationManager.deleteNotificationChannel("daily_content_channel_v2")
                notificationManager.deleteNotificationChannel("daily_content_channel_v3")
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ Channel silinirken hata (normal olabilir): ${e.message}")
            }

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Günlük İçerik",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Günün ayeti, hadisi ve duası bildirimleri"
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val mainIntent = Intent(context, com.huzura.davet.MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context, notificationId, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(false)
            .setOngoing(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(mainPendingIntent)
            .setLargeIcon(BildirimIkonu.buyukIkon(context))

        if (soundUri != null) {
            builder.setSound(soundUri)
        } else if (isPhoneSilent) {
            builder.setVibrate(longArrayOf(0, 300, 200, 300, 200, 300))
        }

        val notification = builder.build()

        try {
            if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                notificationManager.notify(notificationId, notification)
                Log.d(TAG, "✅ Bildirim gösterildi: $title (ID: $notificationId)")
            } else {
                Log.w(TAG, "⚠️ Bildirim izni yok!")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Bildirim gösterme hatası: ${e.message}")
        }
    }
// ...existing code...
    
    /**
     * MediaPlayer ile ses çal - sessiz mod kontrolü zaten yapılmış
     */
    private fun playSoundViaMediaPlayer(context: Context, soundFile: String) {
        try {
            // Ses dosyasını normalize et (zaten normalize edilmiş olmalı ama yine de kontrol)
            var soundResourceName = soundFile.replace(".mp3", "").lowercase()
                .replace(" ", "_").replace("-", "_")
                .replace(Regex("[^a-z0-9_]"), "_")
                .replace(Regex("_+"), "_")
                .trim('_')
            if (soundResourceName.isEmpty()) soundResourceName = "ding_dong"
            
            Log.d(TAG, "🔊 MediaPlayer ile ses çalınıyor: '$soundResourceName'")
            
            var resId = context.resources.getIdentifier(soundResourceName, "raw", context.packageName)
            
            // Bulunamazsa best dene, sonra ding_dong
            if (resId == 0) {
                Log.w(TAG, "⚠️ Ses bulunamadı: $soundResourceName, best deneniyor")
                resId = context.resources.getIdentifier("best", "raw", context.packageName)
            }
            
            if (resId == 0) {
                Log.w(TAG, "⚠️ best de bulunamadı, ding_dong deneniyor")
                resId = context.resources.getIdentifier("ding_dong", "raw", context.packageName)
            }
            
            if (resId != 0) {
                val mediaPlayer = MediaPlayer()
                // ALARM stream kullan - telefon ses seviyesinden bağımsız daha yüksek ses
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                mediaPlayer.setAudioAttributes(audioAttributes)
                
                val afd = context.resources.openRawResourceFd(resId)
                try {
                    mediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    mediaPlayer.prepare()
                } finally {
                    afd.close()
                }
                
                mediaPlayer.isLooping = false
                mediaPlayer.setOnCompletionListener {
                    it.release()
                    Log.d(TAG, "🔊 Ses çalma tamamlandı")
                }
                mediaPlayer.start()
                Log.d(TAG, "✅ Ses çalındı: $soundResourceName")
            } else {
                Log.w(TAG, "⚠️ Hiçbir ses dosyası bulunamadı")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ses çalma hatası: ${e.message}")
        }
    }
    
    /**
     * Titreşim yap
     */
    private fun doVibration(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            val pattern = longArrayOf(0, 300, 200, 300, 200, 300)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
            Log.d(TAG, "📳 Titreşim yapıldı")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Titreşim hatası: ${e.message}")
        }
    }
// ...existing code...
// ...existing code...
}
