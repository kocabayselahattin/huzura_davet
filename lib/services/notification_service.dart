import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize([dynamic context]) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showVakitNotification({
    required String title,
    required String body,
    String? soundAsset, // ör: 'Ding_Dong.mp3' veya 'ding_dong.mp3'
  }) async {
    // Android raw resource formatına dönüştür: küçük harf, tire yerine alt çizgi, uzantı yok
    String? androidSound;
    if (soundAsset != null) {
      androidSound = soundAsset
          .replaceAll('.mp3', '')
          .replaceAll('.wav', '')
          .toLowerCase()
          .replaceAll('-', '_');
    }
    
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'vakit_channel',
      'Vakit Bildirimleri',
      channelDescription: 'Namaz vakitleri için bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      sound: androidSound != null
          ? RawResourceAndroidNotificationSound(androidSound)
          : null,
      playSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }
}
