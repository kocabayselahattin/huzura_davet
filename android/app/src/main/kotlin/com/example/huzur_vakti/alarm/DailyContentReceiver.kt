package com.example.huzur_vakti.alarm

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
import com.example.huzur_vakti.R

/**
 * Günlük içerik bildirimlerini alan BroadcastReceiver
 * AlarmManager tarafından tetiklenir ve bildirimi gösterir
 */
class DailyContentReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "DailyContentReceiver"
        private const val CHANNEL_ID = "daily_content_channel_v4"
        const val ACTION_DAILY_CONTENT = "com.example.huzur_vakti.DAILY_CONTENT"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_SOUND_FILE = "sound_file"
        
        /**
         * Günlük içerik bildirimi zamanla
         */
        fun scheduleDailyContent(
            context: Context,
            notificationId: Int,
            title: String,
            body: String,
            triggerAtMillis: Long,
            soundFile: String
        ): Boolean {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, DailyContentReceiver::class.java).apply {
                action = ACTION_DAILY_CONTENT
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_SOUND_FILE, soundFile)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val triggerTime = java.text.SimpleDateFormat("dd.MM.yyyy HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date(triggerAtMillis))
            Log.d(TAG, "📅 Günlük içerik zamanlanıyor: $title - $triggerTime (ID: $notificationId)")
            
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
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
                wakeLock.acquire(30_000L) // 30 saniye
                
                try {
                    val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
                    val title = intent.getStringExtra(EXTRA_TITLE) ?: "Huzur Vakti"
                    val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                    val soundFile = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "ding_dong"
                    
                    Log.d(TAG, "🔔 Günlük içerik bildirimi gösteriliyor: $title (ses: $soundFile)")
                    
                    // Bildirimi göster
                    showNotification(context, notificationId, title, body, soundFile)
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
        
        // ÖNEMLİ: Telefon sessiz modda mı kontrol et
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        val isPhoneSilent = (ringerMode == AudioManager.RINGER_MODE_SILENT || 
                            ringerMode == AudioManager.RINGER_MODE_VIBRATE)
        
        Log.d(TAG, "📱 Telefon modu: $ringerMode (NORMAL=2, VIBRATE=1, SILENT=0), Sessiz: $isPhoneSilent")
        
        // Notification channel oluştur (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // ÖNEMLİ: Eski kanalları SİL
            try {
                notificationManager.deleteNotificationChannel(CHANNEL_ID)
                notificationManager.deleteNotificationChannel("daily_content_channel")
                notificationManager.deleteNotificationChannel("daily_content_channel_v2")
                notificationManager.deleteNotificationChannel("daily_content_channel_v3")
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ Channel silinirken hata (normal olabilir): ${e.message}")
            }
            
            // Kanal sessiz oluşturulacak - ses MediaPlayer ile çalınacak
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Günlük İçerik",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Günün ayeti, hadisi ve duası bildirimleri"
                setSound(null, null) // Ses kanalda değil, MediaPlayer ile çalınacak
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel oluşturuldu (ses MediaPlayer ile çalınacak)")
        }
        
        // Ana uygulamayı açacak intent
        val mainIntent = Intent(context, com.example.huzur_vakti.MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context, notificationId, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Bildirimi oluştur - kullanıcı silene kadar kalacak
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(false) // Tıklayınca silinmesin
            .setOngoing(false)   // Kaydırılarak silinebilsin
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(mainPendingIntent)
            .setLargeIcon(android.graphics.BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher))
            .build()
        
        try {
            if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                notificationManager.notify(notificationId, notification)
                Log.d(TAG, "✅ Bildirim gösterildi: $title (ID: $notificationId)")
                
                // Ses çal - telefon sessiz modda değilse
                if (!isPhoneSilent) {
                    playSoundViaMediaPlayer(context, soundFile)
                } else {
                    Log.d(TAG, "🔇 Telefon sessiz modda - ses çalınmıyor, titreşim yapılıyor")
                    doVibration(context)
                }
            } else {
                Log.w(TAG, "⚠️ Bildirim izni yok!")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Bildirim gösterme hatası: ${e.message}")
        }
    }
    
    /**
     * MediaPlayer ile ses çal - sessiz mod kontrolü zaten yapılmış
     */
    private fun playSoundViaMediaPlayer(context: Context, soundFile: String) {
        try {
            var soundResourceName = soundFile.replace(".mp3", "").lowercase()
                .replace(" ", "_").replace("-", "_")
                .replace(Regex("[^a-z0-9_]"), "_")
            if (soundResourceName.isEmpty()) soundResourceName = "ding_dong"
            
            Log.d(TAG, "🔊 MediaPlayer ile ses çalınıyor: '$soundResourceName'")
            
            var resId = context.resources.getIdentifier(soundResourceName, "raw", context.packageName)
            
            // Bulunamazsa ding_dong dene
            if (resId == 0) {
                Log.w(TAG, "⚠️ Ses bulunamadı: $soundResourceName, ding_dong deneniyor")
                resId = context.resources.getIdentifier("ding_dong", "raw", context.packageName)
            }
            
            if (resId != 0) {
                val mediaPlayer = MediaPlayer()
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
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
}
