package com.example.huzur_vakti.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Vakit alarmlarını alan BroadcastReceiver
 * AlarmManager tarafından tetiklenir ve AlarmService'i başlatır
 */
class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        const val ACTION_PRAYER_ALARM = "com.example.huzur_vakti.PRAYER_ALARM"
        const val EXTRA_VAKIT_NAME = "vakit_name"
        const val EXTRA_VAKIT_TIME = "vakit_time"
        const val EXTRA_SOUND_FILE = "sound_file"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_IS_EARLY = "is_early"
        const val EXTRA_EARLY_MINUTES = "early_minutes"
        
        /**
         * Alarm zamanla
         */
        fun scheduleAlarm(
            context: Context,
            alarmId: Int,
            prayerName: String,
            triggerAtMillis: Long,
            soundPath: String?,
            useVibration: Boolean = true
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_PRAYER_ALARM
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_VAKIT_NAME, prayerName)
                putExtra(EXTRA_VAKIT_TIME, "")
                putExtra(EXTRA_SOUND_FILE, soundPath ?: "ding_dong")
                putExtra(EXTRA_IS_EARLY, false)
                putExtra(EXTRA_EARLY_MINUTES, 0)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setAlarmClock(
                            AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                            pendingIntent
                        )
                    } else {
                        // Fallback - inexact alarm
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
                
                Log.d(TAG, "✅ Alarm zamanlandı: $prayerName - ID: $alarmId")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Alarm zamanlama hatası: ${e.message}")
            }
        }
        
        /**
         * Belirli bir alarmı iptal et
         */
        fun cancelAlarm(context: Context, alarmId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_PRAYER_ALARM
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "🔕 Alarm iptal edildi: ID $alarmId")
            }
        }
        
        /**
         * Tüm alarmları iptal et
         */
        fun cancelAllAlarms(context: Context) {
            // 1-100 arası tüm olası alarm ID'lerini iptal et
            for (i in 1..100) {
                cancelAlarm(context, i)
            }
            Log.d(TAG, "🔕 Tüm alarmlar iptal edildi")
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📢 Alarm alındı: ${intent.action}")
        
        when (intent.action) {
            ACTION_PRAYER_ALARM -> {
                // Wake lock al
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "HuzurVakti::AlarmWakeLock"
                )
                wakeLock.acquire(60_000L) // 1 dakika
                
                try {
                    val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)
                    val vakitName = intent.getStringExtra(EXTRA_VAKIT_NAME) ?: "Vakit"
                    val vakitTime = intent.getStringExtra(EXTRA_VAKIT_TIME) ?: ""
                    val soundFile = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "ding_dong"
                    val isEarly = intent.getBooleanExtra(EXTRA_IS_EARLY, false)
                    val earlyMinutes = intent.getIntExtra(EXTRA_EARLY_MINUTES, 0)
                    
                    Log.d(TAG, "🔔 Alarm tetiklendi: $vakitName - $vakitTime")
                    
                    // AlarmService'i başlat
                    val serviceIntent = Intent(context, AlarmService::class.java).apply {
                        putExtra(EXTRA_ALARM_ID, alarmId)
                        putExtra(EXTRA_VAKIT_NAME, vakitName)
                        putExtra(EXTRA_VAKIT_TIME, vakitTime)
                        putExtra(EXTRA_SOUND_FILE, soundFile)
                        putExtra(EXTRA_IS_EARLY, isEarly)
                        putExtra(EXTRA_EARLY_MINUTES, earlyMinutes)
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    
                } finally {
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                }
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "📱 Cihaz yeniden başlatıldı, alarmlar yeniden zamanlanacak")
                // Flutter tarafından tetiklenecek
            }
        }
    }
}
