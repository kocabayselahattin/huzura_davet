package com.example.huzur_vakti.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

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
                val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Huzur Vakti"
                val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                val soundFile = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "ding_dong"
                
                Log.d(TAG, "🔔 Günlük içerik bildirimi gösteriliyor: $title")
                
                // Bildirimi göster
                showNotification(context, notificationId, title, body, soundFile)
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
        
        // Notification channel oluştur (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Ses resource'unu bul
            val soundResourceName = soundFile.replace(".mp3", "")
            val soundResId = context.resources.getIdentifier(
                soundResourceName,
                "raw",
                context.packageName
            )
            
            val soundUri = if (soundResId != 0) {
                Uri.parse("android.resource://${context.packageName}/$soundResId")
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            
            Log.d(TAG, "🔊 Ses ayarı: $soundFile -> $soundResourceName (resId: $soundResId)")
            
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Günlük İçerik",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Günün ayeti, hadisi ve duası bildirimleri"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel oluşturuldu")
        }
        
        // Bildirimi oluştur ve göster
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
        
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
}
