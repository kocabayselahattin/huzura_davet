package com.example.huzur_vakti.alarm

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log

/**
 * Sessize mod bildirimindeki "Kal" ve "Çık" butonlarını ve otomatik çıkışı dinler
 */
class SilentModeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "SilentModeReceiver"
        private const val AUTO_EXIT_ALARM_ID = 999888
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📢 Sessize mod aksiyonu alındı: ${intent.action}")
        
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        when (intent.action) {
            AlarmService.ACTION_EXIT_SILENT -> {
                // Sessize moddan çık - telefonu normale döndür
                cancelAutoExitAlarm(context)
                try {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    Log.d(TAG, "🔊 Telefon sessize moddan çıktı - normal moda döndü")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Normal moda dönme hatası: ${e.message}")
                }
                
                // Sessiz mod bildirimini kapat
                notificationManager.cancel(AlarmService.SILENT_MODE_NOTIFICATION_ID)
                Log.d(TAG, "🗑️ Sessize mod bildirimi kapatıldı")
            }
            
            AlarmService.ACTION_STAY_SILENT -> {
                // Sessize modda kal - otomatik çıkış alarmını iptal et ve bildirimi kapat
                cancelAutoExitAlarm(context)
                notificationManager.cancel(AlarmService.SILENT_MODE_NOTIFICATION_ID)
                Log.d(TAG, "📵 Sessize modda kalındı - otomatik çıkış iptal edildi - bildirim kapatıldı")
            }

            AlarmService.ACTION_AUTO_EXIT_SILENT -> {
                // Otomatik sessiz moddan çıkış - süre doldu
                Log.d(TAG, "⏰ Sessiz mod süresi doldu, otomatik çıkılıyor...")
                try {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    Log.d(TAG, "🔊 Otomatik: Telefon normal moda döndü")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Otomatik normal moda dönme hatası: ${e.message}")
                }
                
                // Sessiz mod bildirimini kapat
                notificationManager.cancel(AlarmService.SILENT_MODE_NOTIFICATION_ID)
                Log.d(TAG, "🗑️ Otomatik: Sessiz mod bildirimi kapatıldı")
            }
        }
    }

    /**
     * Otomatik sessiz moddan çıkış alarmını iptal et
     * Kullanıcı manuel olarak "Kal" veya "Çık" butonuna bastığında çağrılır
     */
    private fun cancelAutoExitAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, SilentModeReceiver::class.java).apply {
                action = AlarmService.ACTION_AUTO_EXIT_SILENT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, AUTO_EXIT_ALARM_ID, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "🚫 Otomatik çıkış alarmı iptal edildi")
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Otomatik çıkış alarm iptal hatası: ${e.message}")
        }
    }
}
