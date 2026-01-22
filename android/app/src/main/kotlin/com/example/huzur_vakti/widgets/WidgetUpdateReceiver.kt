package com.example.huzur_vakti.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import com.example.huzur_vakti.MainActivity

/**
 * Widget güncelleme receiver'ı - Telefon kilitli iken bile widget'ları günceller
 * WAKE_LOCK kullanarak ekran kapalıyken bile çalışır
 */
class WidgetUpdateReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "WidgetUpdateReceiver"
        private const val ACTION_UPDATE_WIDGETS = "com.example.huzur_vakti.UPDATE_WIDGETS"
        private const val UPDATE_INTERVAL = 30_000L // 30 saniye - pil optimizasyonu için
        
        /**
         * Periyodik widget güncellemesini başlat
         */
        fun scheduleWidgetUpdates(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                action = ACTION_UPDATE_WIDGETS
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Alarm'ı iptal et (varsa)
            alarmManager.cancel(pendingIntent)
            
            // Yeni alarm kur - RTC_WAKEUP kullanarak ekran kapalıyken bile çalışır
            val triggerTime = System.currentTimeMillis() + UPDATE_INTERVAL
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Android 6.0+ için setExactAndAllowWhileIdle kullan
                // Bu, Doze modunda bile widget'ın güncellenmesini sağlar
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "Widget updates scheduled for every 30 seconds (WAKE_LOCK enabled)")
        }
        
        /**
         * Widget güncellemelerini durdur
         */
        fun cancelWidgetUpdates(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                action = ACTION_UPDATE_WIDGETS
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                Log.d(TAG, "Widget updates cancelled")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received intent: ${intent.action}")
        
        when (intent.action) {
            ACTION_UPDATE_WIDGETS -> {
                // WAKE_LOCK al - ekran kapalıyken bile işlem yapabilmek için
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "HuzurVakti::WidgetUpdate"
                )
                
                try {
                    // Wake lock al (maksimum 30 saniye)
                    wakeLock.acquire(30_000L)
                    
                    Log.d(TAG, "Updating widgets while device may be sleeping")
                    
                    // Tüm widget'ları güncelle
                    updateAllWidgets(context)
                    
                } finally {
                    // Wake lock'u serbest bırak
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                    
                    // Wake lock serbest bırakıldıktan SONRA bir sonraki güncellemeyi planla
                    scheduleWidgetUpdates(context)
                }
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Cihaz yeniden başlatıldığında veya uygulama güncellendiğinde
                // widget güncellemelerini yeniden planla
                scheduleWidgetUpdates(context)
            }
            Intent.ACTION_USER_PRESENT -> {
                // Ekran kilidi açıldığında widget'ları hemen güncelle
                Log.d(TAG, "Screen unlocked, updating widgets immediately")
                updateAllWidgets(context)
            }
        }
    }
    
    private fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val updateIntent = Intent(ACTION_UPDATE_WIDGETS)
        
        // Tüm widget'ları güncelle - 8 widget
        val widgets = listOf<Class<out AppWidgetProvider>>(
            KlasikTuruncuWidget::class.java,
            MiniSunsetWidget::class.java,
            GlassmorphismWidget::class.java,
            NeonGlowWidget::class.java,
            CosmicWidget::class.java,
            TimelineWidget::class.java,
            ZenWidget::class.java,
            OrigamiWidget::class.java
        )
        
        widgets.forEach { widgetClass ->
            try {
                val component = ComponentName(context, widgetClass)
                val widgetIds = appWidgetManager.getAppWidgetIds(component)
                
                if (widgetIds.isNotEmpty()) {
                    val widgetIntent = Intent(context, widgetClass).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                    }
                    context.sendBroadcast(widgetIntent)
                    Log.d(TAG, "Updated ${widgetClass.simpleName}: ${widgetIds.size} instances")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget ${widgetClass.simpleName}", e)
            }
        }
    }
}
