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
         * @param isEarly true ise erken bildirim (vaktinden önce)
         * @param earlyMinutes erken bildirim için kaç dakika önce
         */
        fun scheduleAlarm(
            context: Context,
            alarmId: Int,
            prayerName: String,
            triggerAtMillis: Long,
            soundPath: String?,
            isEarly: Boolean = false,
            earlyMinutes: Int = 0
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_PRAYER_ALARM
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_VAKIT_NAME, prayerName)
                putExtra(EXTRA_VAKIT_TIME, "") // Bu alan artık kullanılmıyor, AlarmService'de çözülecek
                putExtra(EXTRA_SOUND_FILE, soundPath ?: "best") // Null ise varsayılan
                putExtra(EXTRA_IS_EARLY, isEarly)
                putExtra(EXTRA_EARLY_MINUTES, earlyMinutes)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerTimeStr = java.text.SimpleDateFormat("dd.MM.yyyy HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date(triggerAtMillis))
            Log.d(TAG, "🕐 Alarm zamanlanıyor: ID=$alarmId, Vakit=$prayerName, Zaman=$triggerTimeStr, Ses=$soundPath, Erken=$isEarly")

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                        pendingIntent
                    )
                    Log.d(TAG, "✅ setAlarmClock ile zamanlandı (SDK >= S)")
                } else {
                    // Fallback for older SDKs or when exact alarm permission is not granted
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ setExactAndAllowWhileIdle ile zamanlandı (Fallback)")
                }
                saveAlarmId(context, alarmId)
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Alarm zamanlama SecurityException: ${e.message}")
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

            // Kayıtlı ID'yi sil
            removeAlarmId(context, alarmId)
        }

        /**
         * Tüm alarmları iptal et
         */
        fun cancelAllAlarms(context: Context) {
            // SharedPreferences'dan kayıtlı alarm ID'lerini al
            val prefs = context.getSharedPreferences("alarm_ids", Context.MODE_PRIVATE)
            val alarmIds = prefs.getStringSet("active_alarms", emptySet()) ?: emptySet()

            for (idStr in alarmIds) {
                val id = idStr.toIntOrNull() ?: continue
                cancelAlarm(context, id)
            }

            // Listeyi temizle
            prefs.edit().remove("active_alarms").apply()

            Log.d(TAG, "🔕 Tüm alarmlar iptal edildi (${alarmIds.size} adet)")
        }

        /**
         * Alarm ID'sini kaydet
         */
        private fun saveAlarmId(context: Context, alarmId: Int) {
            val prefs = context.getSharedPreferences("alarm_ids", Context.MODE_PRIVATE)
            val alarmIds = prefs.getStringSet("active_alarms", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            alarmIds.add(alarmId.toString())
            prefs.edit().putStringSet("active_alarms", alarmIds).apply()
        }

        /**
         * Alarm ID'sini sil
         */
        private fun removeAlarmId(context: Context, alarmId: Int) {
            val prefs = context.getSharedPreferences("alarm_ids", Context.MODE_PRIVATE)
            val alarmIds = prefs.getStringSet("active_alarms", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            alarmIds.remove(alarmId.toString())
            prefs.edit().putStringSet("active_alarms", alarmIds).apply()
        }

        /**
         * Özel gün/gece bildirimi için alarm zamanla
         * Bu bildirimler uygulama kapalı olsa bile çalır
         */
        fun scheduleOzelGunAlarm(
            context: Context,
            alarmId: Int,
            title: String,
            body: String,
            triggerAtMillis: Long
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, OzelGunReceiver::class.java).apply {
                action = "com.example.huzur_vakti.OZEL_GUN_ALARM"
                putExtra("alarm_id", alarmId)
                putExtra("title", title)
                putExtra("body", body)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerTime = java.text.SimpleDateFormat("dd.MM.yyyy HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date(triggerAtMillis))
            Log.d(TAG, "🕌 Özel gün alarmı zamanlanıyor: $title - $triggerTime (ID: $alarmId)")

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val canScheduleExact = alarmManager.canScheduleExactAlarms()
                    if (canScheduleExact) {
                        alarmManager.setAlarmClock(
                            AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                            pendingIntent
                        )
                        Log.d(TAG, "✅ Özel gün alarmı setAlarmClock ile zamanlandı")
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                        Log.w(TAG, "⚠️ Özel gün: Exact alarm izni yok, setAndAllowWhileIdle kullanıldı")
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent),
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Özel gün alarmı setAlarmClock ile zamanlandı (M+)")
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Özel gün alarmı setExact ile zamanlandı")
                }

                // Alarm ID'sini kaydet
                saveAlarmId(context, alarmId)

            } catch (e: Exception) {
                Log.e(TAG, "❌ Özel gün alarmı zamanlama hatası: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📢 Alarm alındı: ${intent.action}")
<<<<<<< HEAD
        
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
                    val intentSound = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "best"
                    val isEarly = intent.getBooleanExtra(EXTRA_IS_EARLY, false)
                    val earlyMinutes = intent.getIntExtra(EXTRA_EARLY_MINUTES, 0)
                    
                    Log.d(TAG, "🔔 [ALARM RECEIVER] Alarm parametreleri:")
                    Log.d(TAG, "   - Vakit: $vakitName")
                    Log.d(TAG, "   - Ses (INTENT'ten): '$intentSound'")
                    Log.d(TAG, "   - Erken: $isEarly ($earlyMinutes dk)")
                    
                    // ÖNEMLİ: Ses zamanlama sırasında Flutter'da doğru seçilip normalize edildi
                    // Intent'ten gelen sesi DOĞRUDAN kullan - tekrar SharedPreferences'tan okuma yapma
                    // Sadece son bir normalizasyon yap (güvenlik için)
                    var soundFile = intentSound.lowercase()
                        .replace(".mp3", "")
                        .replace(" ", "_")
                        .replace("-", "_")
                        .replace(Regex("[^a-z0-9_]"), "_")
                        .replace(Regex("_+"), "_")
                        .trim('_')
                    
                    if (soundFile.isEmpty()) soundFile = "best"
                    
                    Log.d(TAG, "✅ [ALARM RECEIVER] Final ses: '$intentSound' -> '$soundFile'")
                    
                    Log.d(TAG, "🔔 [ALARM RECEIVER] AlarmService başlatılıyor:")
                    Log.d(TAG, "   - Vakit: $vakitName - $vakitTime")
                    Log.d(TAG, "   - Ses (FINAL): '$soundFile'")
                    
                    // AlarmService'i başlat - ACTION_PRAYER_ALARM set etmeli!
                    val serviceIntent = Intent(context, AlarmService::class.java).apply {
                        action = ACTION_PRAYER_ALARM // ÖNEMLİ: Action set etmeliyiz!
        
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
                                            val intentSound = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "best"
                                            val isEarly = intent.getBooleanExtra(EXTRA_IS_EARLY, false)
                                            val earlyMinutes = intent.getIntExtra(EXTRA_EARLY_MINUTES, 0)
                    
                                            Log.d(TAG, "🔔 [ALARM RECEIVER] Alarm parametreleri:")
                                            Log.d(TAG, "   - Vakit: $vakitName")
                                            Log.d(TAG, "   - Ses (INTENT'ten): '$intentSound'")
                                            Log.d(TAG, "   - Erken: $isEarly ($earlyMinutes dk)")
                    
                                            // ÖNEMLİ: Ses zamanlama sırasında Flutter'da doğru seçilip normalize edildi
                                            // Intent'ten gelen sesi DOĞRUDAN kullan - tekrar SharedPreferences'tan okuma yapma
                                            // Sadece son bir normalizasyon yap (güvenlik için)
                                            var soundFile = intentSound.lowercase()
                                                .replace(".mp3", "")
                                                .replace(" ", "_")
                                                .replace("-", "_")
                                                .replace(Regex("[^a-z0-9_]"), "_")
                                                .replace(Regex("_+"), "_")
                                                .trim('_')
                    
                                            if (soundFile.isEmpty()) soundFile = "best"
                    
                                            Log.d(TAG, "✅ [ALARM RECEIVER] Final ses: '$intentSound' -> '$soundFile'")
                    
                                            Log.d(TAG, "🔔 [ALARM RECEIVER] AlarmService başlatılıyor:")
                                            Log.d(TAG, "   - Vakit: $vakitName - $vakitTime")
                                            Log.d(TAG, "   - Ses (FINAL): '$soundFile'")
                    
                                            // AlarmService'i başlat - ACTION_PRAYER_ALARM set etmeli!
                                            val serviceIntent = Intent(context, AlarmService::class.java).apply {
                                                action = ACTION_PRAYER_ALARM // ÖNEMLİ: Action set etmeliyiz!
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
                                }
                    context.startService(serviceIntent)
