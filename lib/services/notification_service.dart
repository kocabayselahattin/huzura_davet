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
    String? soundAsset, // ör: 'ding_dong.mp3'
  }) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'vakit_channel',
      'Vakit Bildirimleri',
      channelDescription: 'Namaz vakitleri için bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      sound: soundAsset != null
          ? RawResourceAndroidNotificationSound(soundAsset.replaceAll('.mp3', '').replaceAll('.wav', ''))
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
