package com.example.huzur_vakti.alarm

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log

/**
 * Sessize mod bildirimindeki "Kal" ve "Çık" butonlarını dinler
 */
class SilentModeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "SilentModeReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📢 Sessize mod aksiyonu alındı: ${intent.action}")
        
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        when (intent.action) {
            AlarmService.ACTION_EXIT_SILENT -> {
                // Sessize moddan çık - telefonu normale döndür
                try {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    Log.d(TAG, "🔊 Telefon sessize moddan çıktı - normal moda döndü")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Normal moda dönme hatası: ${e.message}")
                }
                
                // Bildirimi kapat
                notificationManager.cancel(2001)
                Log.d(TAG, "🗑️ Sessize mod bildirimi kapatıldı")
            }
            
            AlarmService.ACTION_STAY_SILENT -> {
                // Sessize modda kal - sadece bildirimi kapat
                notificationManager.cancel(2001)
                Log.d(TAG, "📵 Sessize modda kalındı - bildirim kapatıldı")
            }
        }
    }
}
