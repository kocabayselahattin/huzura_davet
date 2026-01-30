package com.example.huzur_vakti.dnd

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.huzur_vakti.R

class PrayerDndReceiver : BroadcastReceiver() {
  companion object {
    const val TAG = "PrayerDndReceiver"
    const val EXTRA_MODE = "mode"
    const val EXTRA_DURATION = "durationMinutes"
    const val EXTRA_LABEL = "label"

    const val MODE_ENABLE = "enable"        // Sessiz moda al
    const val MODE_DISABLE = "disable"      // Sessiz moddan çık
    const val MODE_EXIT_SILENT = "exit_silent"  // Kullanıcı çık dedi

    const val CHANNEL_ID = "prayer_dnd_channel"
    const val NOTIFICATION_ID = 8888
  }

  override fun onReceive(context: Context, intent: Intent) {
    val mode = intent.getStringExtra(EXTRA_MODE) ?: return
    val duration = intent.getIntExtra(EXTRA_DURATION, 30)
    val label = intent.getStringExtra(EXTRA_LABEL) ?: "Vakit"

    Log.d(TAG, "📵 DND Receiver: mode=$mode, label=$label, duration=$duration")

    val notificationManager =
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    when (mode) {
      MODE_ENABLE -> {
        if (!notificationManager.isNotificationPolicyAccessGranted) {
          Log.w(TAG, "⚠️ DND izni yok!")
          return
        }
        // Alarm çalıyorsa bekle (AlarmService aktif mi kontrol et)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmActive = prefs.getBoolean("flutter.alarm_active", false)
        if (alarmActive) {
          Log.d(TAG, "⏳ Alarm aktif, sessiz mod 60 saniye erteleniyor...")
          // Alarm aktifse 60 saniye sonra tekrar dene (uzun ses dosyaları için)
          android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!prefs.getBoolean("flutter.alarm_active", false)) {
              notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
              showSilentModeNotification(context, notificationManager, label, duration)
              Log.d(TAG, "📵 Ertelenmiş sessiz mod aktif: $label")
            }
          }, 60000) // 30000'den 60000'e çıkarıldı
          return
        }
        // Sessiz moda al
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        // Çık/Kal butonlu bildirim göster
        showSilentModeNotification(context, notificationManager, label, duration)
        Log.d(TAG, "📵 Sessiz moda alındı: $label, $duration dk")
      }
      MODE_DISABLE -> {
        if (!notificationManager.isNotificationPolicyAccessGranted) {
          return
        }
        // Sessiz moddan çık
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        // Bildirimi kaldır
        notificationManager.cancel(NOTIFICATION_ID)
        Log.d(TAG, "🔊 Sessiz moddan çıkıldı: $label")
      }
      MODE_EXIT_SILENT -> {
        if (!notificationManager.isNotificationPolicyAccessGranted) {
          return
        }
        // Kullanıcı "Çık" dedi - sessiz moddan hemen çık
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        notificationManager.cancel(NOTIFICATION_ID)
        Log.d(TAG, "🔊 Kullanıcı sessiz moddan çıktı")
      }
    }
  }

  private fun showSilentModeNotification(
    context: Context,
    notificationManager: NotificationManager,
    label: String,
    duration: Int,
  ) {
    // Bildirim kanalı oluştur
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Sessize Alma",
        NotificationManager.IMPORTANCE_HIGH,
      ).apply {
        description = "Namaz vakti sessiz mod bildirimleri"
        setShowBadge(true)
      }
      notificationManager.createNotificationChannel(channel)
    }

    // "Çık" butonu için PendingIntent
    val exitIntent = Intent(context, PrayerDndReceiver::class.java).apply {
      putExtra(EXTRA_MODE, MODE_EXIT_SILENT)
    }
    val exitPendingIntent = PendingIntent.getBroadcast(
      context,
      NOTIFICATION_ID + 1,
      exitIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    // "Kal" butonu için PendingIntent (sadece bildirimi kapatır)
    val stayIntent = Intent(context, PrayerDndReceiver::class.java).apply {
      action = "STAY_SILENT"
    }
    val stayPendingIntent = PendingIntent.getBroadcast(
      context,
      NOTIFICATION_ID + 2,
      stayIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentTitle("📵 Sessiz Moda Alındı")
      .setContentText("$label vakti • $duration dakika sessiz kalacak")
      .setStyle(NotificationCompat.BigTextStyle()
        .bigText("$label vakti için telefon sessiz moda alındı.\n$duration dakika sonra otomatik açılacak.\n\nSessiz moddan çıkmak için 'Çık', kalmak için 'Kal' butonuna basın."))
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_STATUS)
      .setOngoing(true)
      .setAutoCancel(false)
      .addAction(R.mipmap.ic_launcher, "🔊 Çık", exitPendingIntent)
      .addAction(R.mipmap.ic_launcher, "🔇 Kal", stayPendingIntent)
      .build()

    notificationManager.notify(NOTIFICATION_ID, notification)
  }
}
