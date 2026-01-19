import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize([dynamic context]) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Bildirime tıklandı: ${response.payload}');
      },
    );
    
    // Android bildirim kanalını oluştur
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vakit_channel',
      'Vakit Bildirimleri',
      description: 'Namaz vakitleri için bildirimler',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('ding_dong'), // Varsayılan ses
    );
    
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      
      // Bildirim iznini kontrol et ve logla
      final hasPermission = await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Bildirim izni durumu: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('⚠️ Bildirim izni verilmemiş! Kullanıcıdan izin isteniyor...');
        final granted = await androidImplementation.requestNotificationsPermission() ?? false;
        debugPrint('📱 Bildirim izni sonucu: $granted');
      }
    }
  }

  static Future<void> showVakitNotification({
    required String title,
    required String body,
    String? soundAsset, // ör: 'Ding_Dong.mp3' veya 'ding_dong.mp3'
  }) async {
    try {
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
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        ticker: 'Vakit bildirimi',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );
      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
      debugPrint('✅ Bildirim gönderildi: $title - $body (ID: $notificationId)');
    } catch (e) {
      debugPrint('❌ Bildirim gönderilemedi: $e');
      rethrow;
    }
  }
}
